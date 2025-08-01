import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sambandha/screens/profilepage.dart';
import '../services/firebase_user_service.dart';
import '../model/profile_setup_data.dart';
import '../widgets/next_button.dart';

class RelationshipTargetScreen extends StatefulWidget {
  const RelationshipTargetScreen({super.key, required this.data});

  final ProfileSetupData data;

  @override
  State<RelationshipTargetScreen> createState() =>
      _RelationshipTargetScreenState();
}

class _RelationshipTargetScreenState extends State<RelationshipTargetScreen> {
  String? _selectedTarget;
  bool _isSaving = false;
  final FirebaseUserService _firebaseService = FirebaseUserService();

  final List<Map<String, String>> _relationshipTargets = [
    {'label': 'Long-term relationship', 'emoji': '💕'},
    {'label': 'Short-term relationship', 'emoji': '💖'},
    {'label': 'Friendship', 'emoji': '👫'},
    {'label': 'Casual dating', 'emoji': '😊'},
    {'label': 'Marriage', 'emoji': '💍'},
    {'label': 'Not sure yet', 'emoji': '🤔'},
  ];

  Future _continueToNext() async {
    if (_isSaving) return;

    if (_selectedTarget == null) {
      _showError('Please select what you\'re looking for');
      return;
    }

    setState(() => _isSaving = true);

    try {
      GeoPoint? locationGeoPoint = widget.data.currentLocation;

      await _firebaseService.saveUserInterests(
        name: widget.data.firstName ?? 'Unknown',
        birthdate: widget.data.birthDate ?? DateTime(2000, 1, 1),
        hobbies: widget.data.hobbies ?? [],
        interests: widget.data.interest != null ? [widget.data.interest!] : [],
        gender: widget.data.gender != null ? [widget.data.gender!] : [],
        targetRelation: _selectedTarget!,
        location: locationGeoPoint,
        distancePreference: widget.data.distancePreference,
        aboutMe: widget.data.aboutMe,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    } catch (e) {
      _showError('Failed to save profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _selectTarget(String target) {
    if (_isSaving) return;
    setState(() => _selectedTarget = target);
  }

  Widget _buildTargetOption(
    String label,
    String emoji,
    double screenWidth,
    double screenHeight,
  ) {
    final isSelected = _selectedTarget == label;
    final isDisabled = _isSaving;

    return GestureDetector(
      onTap: isDisabled ? null : () => _selectTarget(label),
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.022,
          ),
          margin: EdgeInsets.only(bottom: screenHeight * 0.018),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(screenHeight * 0.025),
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: screenWidth * 0.07)),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check,
                  color: Colors.white,
                  size: screenWidth * 0.06,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenHeight * 0.03,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      size: screenWidth * 0.06,
                      color: Colors.black,
                    ),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  Text(
                    "What are you\nlooking for?",
                    style: TextStyle(
                      fontSize: screenWidth * 0.08,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'Select what type of relationship you\'re seeking',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: Colors.grey.shade600,
                      height: 1.4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: _relationshipTargets
                            .map(
                              (target) => _buildTargetOption(
                                target['label']!,
                                target['emoji']!,
                                screenWidth,
                                screenHeight,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  NextButton(
                    label: _isSaving ? 'SAVING...' : 'COMPLETE',
                    onPressed: _isSaving ? () {} : () => _continueToNext(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
