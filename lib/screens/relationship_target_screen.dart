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
      // Prepare location data
      GeoPoint? locationGeoPoint = widget.data.currentLocation;

      // Debug logging to verify the data
      print('RelationshipTargetScreen - Final save data:');
      print('Name: ${widget.data.firstName}');
      print('About Me: "${widget.data.aboutMe}"'); // Use quotes to see empty strings
      print('Gender: ${widget.data.gender}');
      print('Birth Date: ${widget.data.birthDate}');
      print('Interest: ${widget.data.interest}');
      print('Hobbies: ${widget.data.hobbies}');
      print('Target Relation: $_selectedTarget');
      print('Distance Preference: ${widget.data.distancePreference}');

      await _firebaseService.saveUserInterests(
        name: widget.data.firstName ?? 'Unknown',
        birthdate: widget.data.birthDate ?? DateTime(2000, 1, 1),
        hobbies: widget.data.hobbies ?? [],
        interests: widget.data.interest != null ? [widget.data.interest!] : [],
        gender: widget.data.gender != null ? [widget.data.gender!] : [],
        targetRelation: _selectedTarget!,
        location: locationGeoPoint,
        distancePreference: widget.data.distancePreference,
        aboutMe: widget.data.aboutMe, // ADD THIS LINE - This was missing!
      );

      print('Profile saved successfully to database!');

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

  Widget _buildTargetOption(String label, String emoji) {
    final isSelected = _selectedTarget == label;
    final isDisabled = _isSaving;

    return GestureDetector(
      onTap: isDisabled ? null : () => _selectTarget(label),
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (isSelected) const Icon(Icons.check, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  size: 24,
                  color: Colors.black,
                ),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),

              const SizedBox(height: 32),

              const Text(
                "What are you\nlooking for?",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Select what type of relationship you\'re seeking',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: _relationshipTargets
                        .map(
                          (target) => _buildTargetOption(
                            target['label']!,
                            target['emoji']!,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              NextButton(
                label: _isSaving ? 'SAVING...' : 'COMPLETE',
                onPressed: _isSaving ? () {} : () => _continueToNext(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
