import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sambandha/services/firebase_user_service.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> 
    with TickerProviderStateMixin {
  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutMeController = TextEditingController();
  
  // Focus nodes for better interaction
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _aboutMeFocus = FocusNode();
  
  // Scroll controller for parallax effect
  final ScrollController _scrollController = ScrollController();
  
  // Image handling
  File? _imageFile;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();
  
  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;
  
  // User data
  Map<String, dynamic>? _userData;
  DateTime? _selectedBirthDate;
  List<String> _selectedHobbies = [];
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  // Firebase service
  final FirebaseUserService _userService = FirebaseUserService();
  
  // Parallax scroll values
  double _scrollOffset = 0.0;
  double _headerHeight = 320.0;
  double _minHeaderHeight = 120.0;
  
  // Enhanced color palette - more aesthetic
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF4ECDC4);
  static const Color accentColor = Color(0xFFFF6B9D);
  static const Color gradientStart = Color(0xFF667eea);
  static const Color gradientEnd = Color(0xFF764ba2);
  static const Color cardColor = Color(0xFFF8F9FF);
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  
  // Enhanced hobbies list with better colors
  final List<Map<String, dynamic>> _availableHobbies = [
    {'name': 'Reading', 'icon': Icons.book, 'color': const Color(0xFF6C63FF)},
    {'name': 'Traveling', 'icon': Icons.flight, 'color': const Color(0xFF4ECDC4)},
    {'name': 'Photography', 'icon': Icons.camera_alt, 'color': const Color(0xFFFF6B9D)},
    {'name': 'Cooking', 'icon': Icons.restaurant, 'color': const Color(0xFFFF8A80)},
    {'name': 'Music', 'icon': Icons.music_note, 'color': const Color(0xFF81C784)},
    {'name': 'Sports', 'icon': Icons.sports_soccer, 'color': const Color(0xFF64B5F6)},
    {'name': 'Gaming', 'icon': Icons.games, 'color': const Color(0xFFBA68C8)},
    {'name': 'Art', 'icon': Icons.palette, 'color': const Color(0xFFFFB74D)},
    {'name': 'Dancing', 'icon': Icons.music_video, 'color': const Color(0xFFF06292)},
    {'name': 'Writing', 'icon': Icons.edit, 'color': const Color(0xFF90A4AE)},
    {'name': 'Movies', 'icon': Icons.movie, 'color': const Color(0xFFFFD54F)},
    {'name': 'Fitness', 'icon': Icons.fitness_center, 'color': const Color(0xFF4DD0E1)},
    {'name': 'Nature', 'icon': Icons.nature, 'color': const Color(0xFFA5D6A7)},
    {'name': 'Technology', 'icon': Icons.computer, 'color': const Color(0xFF9575CD)},
    {'name': 'Fashion', 'icon': Icons.checkroom, 'color': const Color(0xFFEF5350)}
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserProfile();
    _setupScrollListener();
    
    // Add focus listeners for better UX
    _nameFocus.addListener(() => setState(() {}));
    _aboutMeFocus.addListener(() => setState(() {}));
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutMeController.dispose();
    _nameFocus.dispose();
    _aboutMeFocus.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // Load existing user profile data
  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);
      
      _userData = await _userService.getUserInterests();
      
      if (_userData != null) {
        _nameController.text = _userData!['name'] ?? '';
        _aboutMeController.text = _userData!['aboutMe'] ?? '';
        
        if (_userData!['profilePicture'] != null) {
          _base64Image = _userData!['profilePicture'];
        }
        
        if (_userData!['birthdate'] != null) {
          _selectedBirthDate = (_userData!['birthdate'] as Timestamp).toDate();
        }
        
        if (_userData!['hobbies'] != null) {
          _selectedHobbies = List<String>.from(_userData!['hobbies']);
        }
      }
      
      // Start animations with staggered effect
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _slideController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _scaleController.forward();
    } catch (e) {
      _showErrorSnackbar('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Request permissions for image selection
  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      PermissionStatus cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        _showErrorSnackbar('Camera permission is required to take photos.');
        return false;
      }
      return true;
    } else {
      try {
        PermissionStatus photosStatus = await Permission.photos.request();
        if (photosStatus == PermissionStatus.granted) {
          return true;
        }

        PermissionStatus storageStatus = await Permission.storage.request();
        if (storageStatus == PermissionStatus.granted) {
          return true;
        }

        _showErrorSnackbar('Storage permission is required to access photos.');
        return false;
      } catch (e) {
        return true;
      }
    }
  }

  // Enhanced image source selection dialog
  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 16,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, cardColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryColor, secondaryColor],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_a_photo,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choose Photo Source',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select how you want to add your photo',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        gradient: const LinearGradient(
                          colors: [primaryColor, Color(0xFF8B7BF7)],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        gradient: const LinearGradient(
                          colors: [secondaryColor, Color(0xFF4FD1C7)],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      bool hasPermission = await _requestPermissions(source);
      if (!hasPermission) return;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
        requestFullMetadata: false,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        await _convertToBase64();
        
        // Add a small success feedback
        HapticFeedback.lightImpact();
        _showSuccessSnackbar('Photo updated successfully!');
      }
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  // Convert image to base64
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

  // Enhanced date picker
  Future<void> _selectBirthDate() async {
    HapticFeedback.selectionClick();
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textPrimary,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
      HapticFeedback.lightImpact();
    }
  }

  // Enhanced hobbies selection dialog
  Future<void> _showHobbiesDialog() async {
    HapticFeedback.selectionClick();
    List<String> tempSelectedHobbies = List.from(_selectedHobbies);
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, cardColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [accentColor, Color(0xFFFF8FA3)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Select Your Hobbies',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose activities you enjoy',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: _availableHobbies.length,
                        itemBuilder: (context, index) {
                          final hobby = _availableHobbies[index];
                          final isSelected = tempSelectedHobbies.contains(hobby['name']);
                          
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setDialogState(() {
                                  if (isSelected) {
                                    tempSelectedHobbies.remove(hobby['name']);
                                  } else {
                                    tempSelectedHobbies.add(hobby['name']);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            hobby['color'],
                                            hobby['color'].withOpacity(0.8),
                                          ],
                                        )
                                      : null,
                                  color: isSelected ? null : Colors.grey.shade100,
                                  border: Border.all(
                                    color: isSelected
                                        ? hobby['color']
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: hobby['color'].withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      hobby['icon'],
                                      size: 18,
                                      color: isSelected
                                          ? Colors.white
                                          : hobby['color'],
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        hobby['name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [primaryColor, secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedHobbies = tempSelectedHobbies;
                            });
                            Navigator.pop(context);
                            HapticFeedback.lightImpact();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Save profile updates
  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackbar('Please enter your name');
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      setState(() => _isSaving = true);

      await _userService.updateUserInterests(
        name: _nameController.text.trim(),
        birthdate: _selectedBirthDate,
        hobbies: _selectedHobbies,
        additionalFields: {
          'aboutMe': _aboutMeController.text.trim(),
          if (_base64Image != null) 'profilePicture': _base64Image,
          if (_base64Image != null) 'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
        },
      );

      _showSuccessSnackbar('Profile updated successfully!');
      await Future.delayed(const Duration(milliseconds: 800));
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackbar('Error updating profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Get profile image widget with parallax effect
  Widget _getParallaxImageWidget() {
    final parallaxOffset = _scrollOffset * 0.5;
    
    if (_base64Image != null) {
      try {
        Uint8List imageBytes = base64Decode(_base64Image!);
        return Transform.translate(
          offset: Offset(0, -parallaxOffset),
          child: Image.memory(
            imageBytes,
            width: double.infinity,
            height: _headerHeight + 100,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        return _buildParallaxPlaceholder(parallaxOffset);
      }
    } else if (_imageFile != null) {
      return Transform.translate(
        offset: Offset(0, -parallaxOffset),
        child: Image.file(
          _imageFile!,
          width: double.infinity,
          height: _headerHeight + 100,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return _buildParallaxPlaceholder(parallaxOffset);
    }
  }

  Widget _buildParallaxPlaceholder(double parallaxOffset) {
    return Transform.translate(
      offset: Offset(0, -parallaxOffset),
      child: Container(
        width: double.infinity,
        height: _headerHeight + 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientStart.withOpacity(0.8),
              gradientEnd.withOpacity(0.9),
              primaryColor.withOpacity(0.7),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced text field widget
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    int maxLines = 1,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: focusNode.hasFocus
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 16, color: textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: textSecondary),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: primaryColor)
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              filled: true,
              fillColor: focusNode.hasFocus
                  ? primaryColor.withOpacity(0.05)
                  : cardColor,
            ),
          ),
        ),
      ],
    );
  }

  // Enhanced selection field widget
  Widget _buildSelectionField({
    required String label,
    required String value,
    required String placeholder,
    required VoidCallback onTap,
    required IconData icon,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [iconColor ?? primaryColor, (iconColor ?? primaryColor).withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    value.isNotEmpty ? value : placeholder,
                    style: TextStyle(
                      fontSize: 16,
                      color: value.isNotEmpty ? textPrimary : textSecondary,
                      fontWeight: value.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: primaryColor,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Show error snackbar
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF5252),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Show success snackbar
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate header height based on scroll
    double currentHeaderHeight = (_headerHeight - _scrollOffset).clamp(_minHeaderHeight, _headerHeight);
    double opacity = (1.0 - (_scrollOffset / _headerHeight)).clamp(0.0, 1.0);
    
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: _scrollOffset > 50
                ? LinearGradient(
                    colors: [Colors.white.withOpacity(0.95), Colors.white],
                  )
                : null,
            boxShadow: _scrollOffset > 50
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: AnimatedOpacity(
              opacity: _scrollOffset > 100 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Text(
                'Update Profile',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            centerTitle: true,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Loading your profile...',
                    style: TextStyle(
                      fontSize: 18,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Parallax Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: currentHeaderHeight,
                    child: Stack(
                      children: [
                        // Background Image with Parallax
                        ClipRect(
                          child: Container(
                            height: currentHeaderHeight,
                            child: _getParallaxImageWidget(),
                          ),
                        ),
                        // Gradient Overlay
                        Container(
                          height: currentHeaderHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Camera Button
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: AnimatedOpacity(
                            opacity: opacity,
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Profile Info Overlay
                        if (_base64Image == null && _imageFile == null)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: opacity,
                              duration: const Duration(milliseconds: 200),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Text(
                                        'Add Profile Photo',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Main Content
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(height: _headerHeight - 40),
                        ),
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(32),
                                topRight: Radius.circular(32),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header indicator
                                  Center(
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Title
                                  const Text(
                                    'Profile Information',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tell us more about yourself',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Name Field
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: _buildTextField(
                                      controller: _nameController,
                                      focusNode: _nameFocus,
                                      label: 'Full Name',
                                      hint: 'Enter your full name',
                                      prefixIcon: Icons.person_outline,
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  // About Me Field
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: _buildTextField(
                                      controller: _aboutMeController,
                                      focusNode: _aboutMeFocus,
                                      label: 'About Me',
                                      hint: 'Tell us about yourself, your interests, goals...',
                                      maxLines: 4,
                                      prefixIcon: Icons.info_outline,
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  // Birth Date Field
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: _buildSelectionField(
                                      label: 'Date of Birth',
                                      value: _selectedBirthDate != null
                                          ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                                          : '',
                                      placeholder: 'Select your birth date',
                                      onTap: _selectBirthDate,
                                      icon: Icons.calendar_today,
                                      iconColor: accentColor,
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  // Hobbies Field
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: _buildSelectionField(
                                      label: 'Hobbies & Interests',
                                      value: _selectedHobbies.isNotEmpty
                                          ? _selectedHobbies.length == 1
                                              ? _selectedHobbies.first
                                              : '${_selectedHobbies.length} hobbies selected'
                                          : '',
                                      placeholder: 'Select your hobbies and interests',
                                      onTap: _showHobbiesDialog,
                                      icon: Icons.favorite_outline,
                                      iconColor: secondaryColor,
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  // Selected Hobbies Preview
                                  if (_selectedHobbies.isNotEmpty) ...[
                                    ScaleTransition(
                                      scale: _scaleAnimation,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Selected Hobbies',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.05),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: _selectedHobbies.map((hobby) {
                                                final hobbyData = _availableHobbies.firstWhere(
                                                  (h) => h['name'] == hobby,
                                                  orElse: () => {
                                                    'name': hobby,
                                                    'icon': Icons.favorite,
                                                    'color': primaryColor
                                                  },
                                                );
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        hobbyData['color'],
                                                        hobbyData['color'].withOpacity(0.8),
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(24),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: hobbyData['color'].withOpacity(0.3),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        hobbyData['icon'],
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        hobby,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                  ],

                                  const SizedBox(height: 20),

                                  // Save Button
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: Container(
                                      width: double.infinity,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [gradientStart, gradientEnd],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(0.4),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isSaving ? null : _saveProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: _isSaving
                                            ? Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  const Text(
                                                    'SAVING PROFILE...',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white24,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.save,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    'SAVE CHANGES',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 50),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} ok