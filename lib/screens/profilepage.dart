import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'homepage.dart'; // Make sure this path is correct for your project

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _imageFile;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isUploading = false;

  // Collection reference - now using user_interests as primary collection
  static const String USER_INTERESTS_COLLECTION = 'user_interests';

  // Get current user
  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadExistingProfilePicture();
  }

  // Load existing profile picture from Firebase (now from user_interests collection)
  Future<void> _loadExistingProfilePicture() async {
    if (currentUser == null) return;

    try {
      setState(() => _isLoading = true);

      // Load from user_interests collection
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection(USER_INTERESTS_COLLECTION)
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        if (userData.containsKey('profilePicture') &&
            userData['profilePicture'] != null) {
          setState(() {
            _base64Image = userData['profilePicture'];
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error loading profile picture: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Request permissions based on Android version and source
  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      // For camera, we need camera permission
      PermissionStatus cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        _showErrorSnackbar('Camera permission is required to take photos.');
        return false;
      }
      return true;
    } else {
      // For gallery, try different permissions based on Android version
      try {
        // Try photos permission first (Android 13+)
        PermissionStatus photosStatus = await Permission.photos.request();
        if (photosStatus == PermissionStatus.granted) {
          return true;
        }

        // If photos permission is not available, try storage permission
        PermissionStatus storageStatus = await Permission.storage.request();
        if (storageStatus == PermissionStatus.granted) {
          return true;
        }

        // Try external storage permission as fallback
        PermissionStatus externalStorageStatus = await Permission
            .manageExternalStorage
            .request();
        if (externalStorageStatus == PermissionStatus.granted) {
          return true;
        }

        _showErrorSnackbar('Storage permission is required to access photos.');
        return false;
      } catch (e) {
        print('Permission error: $e');
        // If permission handling fails, try to proceed anyway
        // Sometimes the image picker works without explicit permissions
        return true;
      }
    }
  }

  // Show image source selection dialog
  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFE94057)),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFFE94057),
                ),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request permissions based on source
      bool hasPermission = await _requestPermissions(source);
      if (!hasPermission) {
        return;
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false, // Add this to avoid permission issues
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        // Convert to base64
        await _convertToBase64();
      } else {
        print('No image selected');
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  // Convert image to base64 string
  Future<void> _convertToBase64() async {
    if (_imageFile == null) return;

    try {
      Uint8List imageBytes = await _imageFile!.readAsBytes();
      String base64String = base64Encode(imageBytes);

      setState(() {
        _base64Image = base64String;
      });
    } catch (e) {
      _showErrorSnackbar('Error converting image: $e');
    }
  }

  // Navigate to homepage
  void _navigateToHomepage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Homepage()),
    );
  }

  // Upload profile picture to Firebase (now saves to user_interests collection)
  Future<void> _uploadProfilePicture() async {
    if (_base64Image == null || currentUser == null) return;

    try {
      setState(() => _isUploading = true);

      // Save to user_interests collection with comprehensive user data
      await FirebaseFirestore.instance
          .collection(USER_INTERESTS_COLLECTION)
          .doc(currentUser!.uid)
          .set({
            'profilePicture': _base64Image,
            'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
            'email': currentUser!.email,
            'uid': currentUser!.uid,
            'userId': currentUser!.uid, // Add userId for consistency
            'updatedAt': FieldValue.serverTimestamp(),
            // If this is the first time, add createdAt as well
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _showSuccessSnackbar('Profile picture uploaded successfully!');

      // Navigate to homepage after successful upload
      _navigateToHomepage();
    } catch (e) {
      _showErrorSnackbar('Error uploading profile picture: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // Remove profile picture (now from user_interests collection)

  // Create basic user profile if it doesn't exist
  Future<void> _ensureUserProfileExists() async {
    if (currentUser == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection(USER_INTERESTS_COLLECTION)
          .doc(currentUser!.uid);

      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        // Create basic profile with default values
        await docRef.set({
          'userId': currentUser!.uid,
          'email': currentUser!.email,
          'uid': currentUser!.uid,
          'name': currentUser!.displayName ?? '',
          'gender': <String>[],
          'interests': <String>[],
          'hobbies': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error ensuring user profile exists: $e');
    }
  }

  // Show error snackbar
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Show success snackbar
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE94057),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Get image widget from base64 string
  Widget _getImageWidget() {
    if (_base64Image != null) {
      try {
        Uint8List imageBytes = base64Decode(_base64Image!);
        return Image.memory(
          imageBytes,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return const Icon(Icons.error, size: 100, color: Colors.red);
      }
    } else if (_imageFile != null) {
      return Image.file(
        _imageFile!,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        width: 200,
        height: 200,
        decoration: const BoxDecoration(
          color: Color(0xFFE8E8E8),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 80, color: Color(0xFFBDBDBD)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE94057)),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Add your profile\npicture',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    const Text(
                      '"Every face tells a story, let yours begin with the love you deserve."',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Profile picture section
                    Center(
                      child: Stack(
                        children: [
                          // Profile picture container
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE8E8E8),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(child: _getImageWidget()),
                          ),

                          // Add button
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploading
                                  ? null
                                  : _showImageSourceDialog,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE94057),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Settings text
                    const Center(
                      child: Text(
                        'You can always change it\nlater from the Settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Finish button
                    Container(
                      width: double.infinity,
                      height: 56,
                      margin: const EdgeInsets.only(bottom: 40),
                      child: ElevatedButton(
                        onPressed: _isUploading
                            ? null
                            : () async {
                                if (_base64Image != null) {
                                  await _ensureUserProfileExists();
                                  await _uploadProfilePicture();
                                } else {
                                  await _ensureUserProfileExists();
                                  _navigateToHomepage();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94057),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'FINISH',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
