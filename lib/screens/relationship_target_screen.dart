import 'package:flutter/material.dart';
import '../model/profile_setup_data.dart';
import '../widgets/next_button.dart';
import 'blank_page.dart'; // ✅ corrected

class RelationshipTargetScreen extends StatefulWidget {
  const RelationshipTargetScreen({super.key, required this.data});

  final ProfileSetupData data;

  @override
  State<RelationshipTargetScreen> createState() =>
      _RelationshipTargetScreenState();
}

class _RelationshipTargetScreenState extends State<RelationshipTargetScreen> {
  String? _selectedTarget;

  final List<Map<String, String>> _relationshipTargets = [
    {'label': 'Long-term relationship', 'emoji': '💕'},
    {'label': 'Short-term relationship', 'emoji': '💖'},
    {'label': 'Friendship', 'emoji': '👫'},
    {'label': 'Casual dating', 'emoji': '😊'},
    {'label': 'Marriage', 'emoji': '💍'},
    {'label': 'Not sure yet', 'emoji': '🤔'},
  ];

  void _continueToNext() {
    if (_selectedTarget == null) {
      _showError('Please select what you\'re looking for');
      return;
    }

    widget.data.relationshipTarget = _selectedTarget;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BlankPage()),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile setup complete!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
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

  void _selectTarget(String target) {
    setState(() {
      _selectedTarget = target;
    });
  }

  Widget _buildTargetOption(String label, String emoji) {
    final isSelected = _selectedTarget == label;

    return GestureDetector(
      onTap: () => _selectTarget(label),
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
          ],
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
              // Back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  size: 24,
                  color: Colors.black,
                ),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),

              const SizedBox(height: 32),

              // Main title
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

              // Subtitle
              Text(
                'Select what type of relationship you\'re seeking',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              // Relationship targets
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

              // Next button
              NextButton(label: 'COMPLETE', onPressed: _continueToNext),
            ],
          ),
        ),
      ),
    );
  }
}
