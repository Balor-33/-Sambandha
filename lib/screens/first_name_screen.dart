import 'package:flutter/material.dart';
import '../model/profile_setup_data.dart';
import 'gender_screen.dart'; // Make sure this import exists

class FirstNameScreen extends StatefulWidget {
  final ProfileSetupData data;

  const FirstNameScreen({super.key, required this.data});

  @override
  State<FirstNameScreen> createState() => _FirstNameScreenState();
}

class _FirstNameScreenState extends State<FirstNameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutMeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _aboutMeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, size: 28),
              ),
              const SizedBox(height: 32),
              
              // Name Section
              const Text(
                "What's your first name?",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: "Enter your name",
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "This is how it will appear in your profile, and you will not be able to change it later.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                "Use your real name",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 32),
              
              // About Me Section
              const Text(
                "Tell me about yourself",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aboutMeController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: "Write a brief description about yourself...",
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
                    const SizedBox(height: 8),
                    const Text(
                      "This will help others get to know you better",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Bottom button section - stays at bottom
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Validate inputs
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your name'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Update the profile data
                    final updatedData = widget.data;
                    updatedData.firstName = _nameController.text.trim();
                    updatedData.aboutMe = _aboutMeController.text.trim();

                    // Debug logging
                    print('FirstNameScreen - Data being passed:');
                    print('Name: "${updatedData.firstName}"');
                    print('About Me: "${updatedData.aboutMe}"');
                    print('About Me length: ${updatedData.aboutMe?.length ?? 0}');
                    print('Full data: ${updatedData.toString()}');

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenderScreen(data: updatedData),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "NEXT",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}