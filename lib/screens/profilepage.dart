import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'homepage.dart';

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
  static const String USER_INTERESTS_COLLECTION = 'user_interests';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadExistingProfilePicture();
  }

  Future<void> _loadExistingProfilePicture() async {
    if (currentUser == null) return;

    try {
      setState(() => _isLoading = true);
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
      _showErrorSnackbar('Error loading profile picture');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      return await Permission.camera.request().isGranted;
    } else {
      return await Permission.photos.request().isGranted ||
          await Permission.storage.request().isGranted;
    }
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (!await _requestPermissions(source)) return;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
        await _convertToBase64();
      }
    } catch (e) {
      _showErrorSnackbar('Error picking image');
    }
  }

  Future<void> _convertToBase64() async {
    if (_imageFile == null) return;

    try {
      Uint8List imageBytes = await _imageFile!.readAsBytes();
      setState(() => _base64Image = base64Encode(imageBytes));
    } catch (e) {
      _showErrorSnackbar('Error converting image');
    }
  }

  void _navigateToHomepage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Homepage()),
    );
  }

  Future<void> _uploadProfilePicture() async {
    if (_base64Image == null || currentUser == null) return;

    try {
      setState(() => _isUploading = true);
      await FirebaseFirestore.instance
          .collection(USER_INTERESTS_COLLECTION)
          .doc(currentUser!.uid)
          .set({
            'profilePicture': _base64Image,
            'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _showSuccessSnackbar('Profile picture uploaded successfully!');
      _navigateToHomepage();
    } catch (e) {
      _showErrorSnackbar('Error uploading profile picture');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _ensureUserProfileExists() async {
    if (currentUser == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection(USER_INTERESTS_COLLECTION)
          .doc(currentUser!.uid);

      if (!(await docRef.get()).exists) {
        await docRef.set({
          'userId': currentUser!.uid,
          'email': currentUser!.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error creating profile');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE94057),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _getImageWidget() {
    if (_base64Image != null) {
      try {
        return Image.memory(
          base64Decode(_base64Image!),
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
                    const Text(
                      '"Every face tells a story, let yours begin with the love you deserve."',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Center(
                      child: Stack(
                        children: [
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
