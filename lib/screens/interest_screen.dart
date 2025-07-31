import 'package:flutter/material.dart';
import '../model/profile_setup_data.dart';
import '../widgets/next_button.dart';
import 'hobbies_screen.dart';

class InterestScreen extends StatefulWidget {
  const InterestScreen({super.key, required this.data});

  final ProfileSetupData data;

  @override
  State<InterestScreen> createState() => _InterestScreenState();
}

class _InterestScreenState extends State<InterestScreen> {
  String? _interest;

  void _continueToHobbies() {
    if (_interest == null) {
      _error('Pick at least one');
      return;
    }

    // Save the interest selection
    widget.data.interest = _interest;

    // Navigate to the hobbies screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HobbiesScreen(data: widget.data)),
    );
  }

  void _error(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _pill(String label) {
    final sel = _interest == label;
    return GestureDetector(
      onTap: () => setState(() => _interest = label),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: sel ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: sel ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BackButton(),
            const SizedBox(height: 32),
            const Text(
              'Who are you\ninterested in seeing?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _pill('Female'),
            _pill('Male'),
            const Spacer(),
            NextButton(label: 'NEXT', onPressed: _continueToHobbies),
          ],
        ),
      ),
    );
  }
}
