import 'package:flutter/material.dart';
import '../model/profile_setup_data.dart';
import '../widgets/next_button.dart';
import 'distance_preference_screen.dart';

class HobbiesScreen extends StatefulWidget {
  const HobbiesScreen({super.key, required this.data});

  final ProfileSetupData data;

  @override
  State<HobbiesScreen> createState() => _HobbiesScreenState();
}

class _HobbiesScreenState extends State<HobbiesScreen> {
  final Set<String> _selectedHobbies = {};
  final int _minRequiredHobbies = 5;

  // List of available hobbies with their emojis
  final List<Map<String, String>> _hobbies = [
    {'label': 'cooking', 'emoji': '🍳'},
    {'label': 'travelling', 'emoji': '🌍'},
    {'label': 'singing', 'emoji': '🎤'},
    {'label': 'dancing', 'emoji': '💃'},
    {'label': 'reading', 'emoji': '📚'},
    {'label': 'games', 'emoji': '🎮'},
    {'label': 'art', 'emoji': '✏️'},
    {'label': 'yoga', 'emoji': '🧘'},
    {'label': 'netflix', 'emoji': '👀'},
    {'label': 'trekking', 'emoji': '🥾'},
    {'label': 'photography', 'emoji': '📸'},
    {'label': 'meditation', 'emoji': '🧘'},
    {'label': 'journaling', 'emoji': '✍️'},
    {'label': 'pottery', 'emoji': '🏺'},
    {'label': 'social work', 'emoji': '😊'},
    {'label': 'gym', 'emoji': '💪'},
    {'label': 'sports', 'emoji': '⚽'},
    {'label': 'bookworm', 'emoji': '📖'},
  ];

  void _continueToNext() {
    if (_selectedHobbies.length < _minRequiredHobbies) {
      _showError('Please select at least $_minRequiredHobbies hobbies');
      return;
    }

    // Save hobbies to profile data
    widget.data.hobbies = _selectedHobbies.toList();

    // Navigate to the next screen or complete setup
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DistancePreferenceScreen(data: widget.data),
      ),
    );
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

  void _toggleHobby(String hobby) {
    setState(() {
      if (_selectedHobbies.contains(hobby)) {
        _selectedHobbies.remove(hobby);
      } else {
        _selectedHobbies.add(hobby);
      }
    });
  }

  Widget _buildHobbyPill(
    String label,
    String emoji,
    double screenWidth,
    double screenHeight,
  ) {
    final isSelected = _selectedHobbies.contains(label);

    return GestureDetector(
      onTap: () => _toggleHobby(label),
      child: Container(
        height: screenHeight * 0.06,
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        margin: EdgeInsets.only(
          right: screenWidth * 0.03,
          bottom: screenHeight * 0.015,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(screenHeight * 0.03),
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: screenWidth * 0.015),
            Text(emoji, style: TextStyle(fontSize: screenWidth * 0.04)),
          ],
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
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      size: screenWidth * 0.06,
                      color: Colors.black,
                    ),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // Main title
                  Text(
                    "Let's explore your\ninterests !",
                    style: TextStyle(
                      fontSize: screenWidth * 0.08,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.01),

                  // Subtitle section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select your hobbies',
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'at least five',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey.shade600,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // Hobbies selection area
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        children: _hobbies
                            .map(
                              (hobby) => _buildHobbyPill(
                                hobby['label']!,
                                hobby['emoji']!,
                                screenWidth,
                                screenHeight,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // Next button
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.07,
                    child: NextButton(
                      label: 'NEXT',
                      onPressed: _continueToNext,
                    ),
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
