import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
// Import your homepage - adjust the path as needed
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
        if (userData.containsKey('profilePicture') && userData['profilePicture'] != null) {
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
        PermissionStatus externalStorageStatus = await Permission.manageExternalStorage.request();
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
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
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
      MaterialPageRoute(builder: (context) => const BlankPage()),
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
  Future<void> _removeProfilePicture() async {
    if (currentUser == null) return;
    
    try {
      setState(() => _isUploading = true);
      
      // Remove from user_interests collection
      await FirebaseFirestore.instance
          .collection(USER_INTERESTS_COLLECTION)
          .doc(currentUser!.uid)
          .update({
        'profilePicture': FieldValue.delete(),
        'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _imageFile = null;
        _base64Image = null;
      });
      
      _showSuccessSnackbar('Profile picture removed successfully!');
      
    } catch (e) {
      _showErrorSnackbar('Error removing profile picture: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }
  
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
        backgroundColor: Colors.green,
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
      return const Icon(Icons.person, size: 100, color: Colors.grey);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Profile Picture'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Add a home icon to navigate to homepage
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: _navigateToHomepage,
            tooltip: 'Go to Homepage',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Profile picture display
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _getImageWidget(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Instructions
                  Text(
                    'Choose your profile picture',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Text(
                    'This will be stored securely in your account',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Pick Image Button
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _showImageSourceDialog,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Pick Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      
                      // Remove Image Button
                      if (_base64Image != null)
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _removeProfilePicture,
                          icon: const Icon(Icons.delete),
                          label: const Text('Remove'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Upload Button
                  if (_base64Image != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : () async {
                          // Ensure user profile exists before uploading
                          await _ensureUserProfileExists();
                          await _uploadProfilePicture();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isUploading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Uploading...'),
                                ],
                              )
                            : const Text(
                                'Save Profile Picture',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Skip Button
                  TextButton(
                    onPressed: _isUploading ? null : () async {
                      // Ensure user profile exists even when skipping
                      await _ensureUserProfileExists();
                      _navigateToHomepage();
                    },
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
    );
  }
}