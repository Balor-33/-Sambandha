import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sambandha/services/firebase_user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage>
    with TickerProviderStateMixin {
  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutMeController = TextEditingController();

  // Focus nodes
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

  // Firebase service
  final FirebaseUserService _userService = FirebaseUserService();

  // Parallax scroll values
  double _scrollOffset = 0.0;
  final double _headerHeight = 400.0; // Increased for better wallpaper view
  final double _minHeaderHeight = 100.0; // Smaller when collapsed

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Enhanced color palette - more aesthetic
  static const Color primaryColor = Color(0xFF6366F1); // Beautiful blue
  static const Color secondaryColor = Color(0xFFEC4899); // Beautiful pink
  static const Color accentColor = Color(0xFF8B5CF6); // Purple accent
  static const Color gradientStart = Color(0xFF667eea); // Blue gradient start
  static const Color gradientEnd = Color(0xFFf093fb); // Pink gradient end

  // Keep these existing ones unchanged
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  static const Color glassColor = Color(0xFFFFFFFF);

  // Hobbies list with better colors
  final List<Map<String, dynamic>> _availableHobbies = [
    {'name': 'Reading', 'icon': Icons.book, 'color': const Color(0xFF6C63FF)},
    {
      'name': 'Traveling',
      'icon': Icons.flight,
      'color': const Color(0xFF4ECDC4),
    },
    {
      'name': 'Photography',
      'icon': Icons.camera_alt,
      'color': const Color(0xFFFF6B9D),
    },
    {
      'name': 'Cooking',
      'icon': Icons.restaurant,
      'color': const Color(0xFFFF8A80),
    },
    {
      'name': 'Music',
      'icon': Icons.music_note,
      'color': const Color(0xFF81C784),
    },
    {
      'name': 'Sports',
      'icon': Icons.sports_soccer,
      'color': const Color(0xFF64B5F6),
    },
    {'name': 'Gaming', 'icon': Icons.games, 'color': const Color(0xFFBA68C8)},
    {'name': 'Art', 'icon': Icons.palette, 'color': const Color(0xFFFFB74D)},
    {
      'name': 'Dancing',
      'icon': Icons.music_video,
      'color': const Color(0xFFF06292),
    },
    {'name': 'Writing', 'icon': Icons.edit, 'color': const Color(0xFF90A4AE)},
    {'name': 'Movies', 'icon': Icons.movie, 'color': const Color(0xFFFFD54F)},
    {
      'name': 'Fitness',
      'icon': Icons.fitness_center,
      'color': const Color(0xFF4DD0E1),
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserProfile();
    _setupScrollListener();
    _nameFocus.addListener(() => setState(() {}));
    _aboutMeFocus.addListener(() => setState(() {}));
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
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

      // Start animations
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _slideController.forward();
    } catch (e) {
      _showErrorSnackbar('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Logout function - properly placed as a separate method
  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    }
  }

  // Enhanced image source selection dialog
  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 20,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  glassColor.withOpacity(0.95),
                  glassColor.withOpacity(0.85),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_a_photo,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Change Profile Picture',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to update your photo',
                  style: TextStyle(fontSize: 16, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        gradient: LinearGradient(
                          colors: [
                            secondaryColor,
                            secondaryColor.withOpacity(0.8),
                          ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _base64Image = null;
        });
        await _convertToBase64();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  glassColor.withOpacity(0.95),
                  glassColor.withOpacity(0.85),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.8)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Your Hobbies',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose activities you enjoy',
                  style: TextStyle(fontSize: 16, color: textSecondary),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 2.2,
                            ),
                        itemCount: _availableHobbies.length,
                        itemBuilder: (context, index) {
                          final hobby = _availableHobbies[index];
                          final isSelected = tempSelectedHobbies.contains(
                            hobby['name'],
                          );

                          return Material(
                            color: Colors.transparent,
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
                                  horizontal: 16,
                                  vertical: 12,
                                ),
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
                                  color: isSelected
                                      ? null
                                      : glassColor.withOpacity(0.3),
                                  border: Border.all(
                                    color: isSelected
                                        ? hobby['color']
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: hobby['color'].withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
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
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
          if (_base64Image != null)
            'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
        },
      );

      _showSuccessSnackbar('Profile updated successfully!');
      await Future.delayed(const Duration(milliseconds: 1000));
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackbar('Error updating profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Get parallax profile image widget
  Widget _getParallaxImageWidget() {
    final parallaxOffset = _scrollOffset * 0.5;

    if (_imageFile != null) {
      return Transform.translate(
        offset: Offset(0, -parallaxOffset),
        child: Image.file(
          _imageFile!,
          width: double.infinity,
          height: _headerHeight + 100,
          fit: BoxFit.cover,
        ),
      );
    } else if (_base64Image != null) {
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
              gradientStart.withOpacity(0.9),
              gradientEnd.withOpacity(0.95),
              primaryColor.withOpacity(0.8),
              secondaryColor.withOpacity(0.7),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
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
            fontSize: 18,
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
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
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
              hintStyle: TextStyle(color: textSecondary.withOpacity(0.7)),
              prefixIcon: prefixIcon != null
                  ? Container(
                      margin: const EdgeInsets.all(12),
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.1),
                            secondaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(prefixIcon, color: primaryColor, size: 22),
                    )
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
                  : glassColor.withOpacity(0.8),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: glassColor.withOpacity(0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (iconColor ?? primaryColor).withOpacity(0.2),
                          (iconColor ?? primaryColor).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      value.isNotEmpty ? value : placeholder,
                      style: TextStyle(
                        fontSize: 16,
                        color: value.isNotEmpty
                            ? textPrimary
                            : textSecondary.withOpacity(0.7),
                        fontWeight: value.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: primaryColor,
                      size: 16,
                    ),
                  ),
                ],
              ),
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
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF5252),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
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
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate header height based on scroll - more dramatic effect
    double _ = (_headerHeight - _scrollOffset * 1.2).clamp(
      _minHeaderHeight,
      _headerHeight,
    );
    double opacity = (1.0 - (_scrollOffset / (_headerHeight * 0.7))).clamp(
      0.0,
      1.0,
    );
    bool isCollapsed = _scrollOffset > (_headerHeight * 0.3);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      // Custom SliverAppBar for collapsing effect
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Loading your profile...',
                    style: TextStyle(
                      fontSize: 20,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Custom App Bar that collapses
                SliverAppBar(
                  expandedHeight: _headerHeight,
                  floating: false,
                  pinned: true,
                  snap: false,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        isCollapsed ? 0.95 : 0.85,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  centerTitle: true,
                  title: AnimatedOpacity(
                    opacity: isCollapsed ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Update Profile',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: GestureDetector(
                      onTap: () {
                        print("Header tapped!");
                        HapticFeedback.selectionClick();
                        _showImageSourceDialog();
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Parallax Background
                          _getParallaxImageWidget(),

                          // Enhanced Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.4),
                                  Colors.black.withOpacity(0.2),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.1),
                                ],
                                stops: const [0.0, 0.3, 0.7, 1.0],
                              ),
                            ),
                          ),

                          // Content overlay for placeholder
                          if (_base64Image == null && _imageFile == null)
                            Center(
                              child: AnimatedOpacity(
                                opacity: opacity,
                                duration: const Duration(milliseconds: 300),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Text(
                                        'Tap to Add Profile Photo',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Main Content
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(40),
                            topRight: Radius.circular(40),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header indicator
                              Center(
                                child: Container(
                                  width: 50,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Title with enhanced styling
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryColor, secondaryColor],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Text(
                                      'Profile Information',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.only(left: 22),
                                child: Text(
                                  'Tell us more about yourself and make your profile shine ✨',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Name Field
                              _buildTextField(
                                controller: _nameController,
                                focusNode: _nameFocus,
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                prefixIcon: Icons.person_outline,
                              ),

                              const SizedBox(height: 28),

                              // About Me Field
                              _buildTextField(
                                controller: _aboutMeController,
                                focusNode: _aboutMeFocus,
                                label: 'About Me',
                                hint:
                                    'Tell us about yourself, your interests, goals...',
                                maxLines: 4,
                                prefixIcon: Icons.info_outline,
                              ),

                              const SizedBox(height: 28),

                              // Birth Date Field
                              _buildSelectionField(
                                label: 'Date of Birth',
                                value: _selectedBirthDate != null
                                    ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                                    : '',
                                placeholder: 'Select your birth date',
                                onTap: _selectBirthDate,
                                icon: Icons.calendar_today,
                                iconColor: accentColor,
                              ),

                              const SizedBox(height: 28),

                              // Hobbies Field
                              _buildSelectionField(
                                label: 'Hobbies & Interests',
                                value: _selectedHobbies.isNotEmpty
                                    ? _selectedHobbies.length == 1
                                          ? _selectedHobbies.first
                                          : '${_selectedHobbies.length} hobbies selected'
                                    : '',
                                placeholder:
                                    'Select your hobbies and interests',
                                onTap: _showHobbiesDialog,
                                icon: Icons.favorite_outline,
                                iconColor: secondaryColor,
                              ),

                              const SizedBox(height: 28),

                              // Selected Hobbies Preview
                              if (_selectedHobbies.isNotEmpty) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your Interests',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Main Container - Simple and consistent with other fields
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: glassColor.withOpacity(0.8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.08,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Simple header with icon
                                          Row(
                                            children: [
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      secondaryColor
                                                          .withOpacity(0.2),
                                                      secondaryColor
                                                          .withOpacity(0.1),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                                child: const Icon(
                                                  Icons.favorite_outline,
                                                  color: secondaryColor,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 20),
                                              Expanded(
                                                child: Text(
                                                  '${_selectedHobbies.length} interests selected',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),

                                          // Organized hobbies grid - properly arranged and eye-pleasing
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              // Calculate optimal number of columns based on screen width
                                              int crossAxisCount =
                                                  constraints.maxWidth > 400
                                                  ? 3
                                                  : 2;
                                              double childAspectRatio =
                                                  constraints.maxWidth > 400
                                                  ? 2.8
                                                  : 2.5;

                                              return GridView.builder(
                                                shrinkWrap: true,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount:
                                                          crossAxisCount,
                                                      crossAxisSpacing: 12,
                                                      mainAxisSpacing: 12,
                                                      childAspectRatio:
                                                          childAspectRatio,
                                                    ),
                                                itemCount:
                                                    _selectedHobbies.length,
                                                itemBuilder: (context, index) {
                                                  final hobby =
                                                      _selectedHobbies[index];
                                                  final hobbyData =
                                                      _availableHobbies
                                                          .firstWhere(
                                                            (h) =>
                                                                h['name'] ==
                                                                hobby,
                                                            orElse: () => {
                                                              'name': hobby,
                                                              'icon': Icons
                                                                  .favorite,
                                                              'color':
                                                                  secondaryColor,
                                                            },
                                                          );

                                                  return GestureDetector(
                                                    onLongPress: () {
                                                      HapticFeedback.mediumImpact();
                                                      _showDeleteHobbyDialog(
                                                        hobby,
                                                      );
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            const Color(
                                                              0xFFF8FAFC,
                                                            ), // Very light gray-blue
                                                            const Color(
                                                              0xFFF1F5F9,
                                                            ), // Slightly darker light gray
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              hobbyData['color']
                                                                  .withOpacity(
                                                                    0.15,
                                                                  ),
                                                          width: 1.5,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.06,
                                                                ),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 22,
                                                            height: 22,
                                                            decoration: BoxDecoration(
                                                              color: hobbyData['color']
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            child: Icon(
                                                              hobbyData['icon'],
                                                              size: 12,
                                                              color: hobbyData['color']
                                                                  .withOpacity(
                                                                    0.8,
                                                                  ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Flexible(
                                                            child: Text(
                                                              hobby,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: hobbyData['color']
                                                                    .withOpacity(
                                                                      0.9,
                                                                    ),
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              maxLines: 1,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                              ],

                              const SizedBox(height: 20),

                              // Enhanced Save Button
                              Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isSaving
                                        ? Colors.grey.shade300
                                        : primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.grey.shade600),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              'Saving...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: 22,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // **LOGOUT BUTTON**
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: OutlinedButton(
                                  onPressed: _logout,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.logout,
                                        color: Colors.redAccent,
                                        size: 22,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Logout',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Add this method to handle hobby deletion
  void _showDeleteHobbyDialog(String hobby) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 20,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFBFF), // Very light pink-white
                  Color(0xFFF8F6FF), // Very light purple-white
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE879F9).withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF6B9D), // Slightly more red-pink for warning
                        Color(0xFF8B5DFF), // Purple-Blue
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B9D).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Remove Interest',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 16, color: textSecondary),
                    children: [
                      const TextSpan(text: 'Are you sure you want to remove '),
                      TextSpan(
                        text: '"$hobby"',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      const TextSpan(text: ' from your interests?'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: const Color(0xFFE879F9).withOpacity(0.3),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(
                                0xFFFF6B9D,
                              ), // Slightly more red-pink for delete action
                              Color(0xFF8B5DFF), // Purple-Blue
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B9D).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedHobbies.remove(hobby);
                            });
                            Navigator.pop(context);
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: Colors.white24,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        '"$hobby" removed from your interests',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFFE879F9),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                margin: const EdgeInsets.all(20),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Remove',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
}
