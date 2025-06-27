import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> _relationshipGoals = [
    {
      'id': 'long_term_partner',
      'emoji': '👀',
      'title': 'Long-term\npartner',
    },
    {
      'id': 'long_term_open',
      'emoji': '😍',
      'title': 'Long-term,\nopen to short',
    },
    {
      'id': 'short_term_open',
      'emoji': '🙏',
      'title': 'Short-term,\nopen to long',
    },
    {
      'id': 'short_term_fun',
      'emoji': '🤪',
      'title': 'Short-term\nfun',
    },
    {
      'id': 'new_friends',
      'emoji': '👋',
      'title': 'New Friends',
    },
    {
      'id': 'still_figuring',
      'emoji': '🤔',
      'title': 'Still figuring\nit out',
    },
  ];

  void _continueToNext() {
    if (_selectedTarget != null) {
      // Save relationship goal to profile data as String
      widget.data.relationshipTarget = _selectedTarget;

      // For now, just show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected: $_selectedTarget')),
      );
    }
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
                icon: const Icon(Icons.arrow_back_ios,
                    size: 24, color: Colors.black),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),

              const SizedBox(height: 60),

              // Main title
              const Text(
                "What are you\nlooking for?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 16),

              // Description text
              Text(
                'All good if it changes. There\'s something for everyone',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              // Goals grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _relationshipGoals.length,
                  itemBuilder: (context, index) {
                    final goal = _relationshipGoals[index];
                    final isSelected = _selectedTarget == goal['id'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTarget = goal['id'];
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.red.shade400
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Emoji
                            Text(
                              goal['emoji'],
                              style: const TextStyle(fontSize: 32),
                            ),

                            const SizedBox(height: 8),

                            // Title
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                goal['title'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Next button
              NextButton(
                label: 'NEXT',
                onPressed: _continueToNext,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
