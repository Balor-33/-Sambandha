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

  Widget _pill(String label, double screenWidth, double screenHeight) {
    final sel = _interest == label;
    return GestureDetector(
      onTap: () => setState(() => _interest = label),
      child: Container(
        height: screenHeight * 0.065,
        alignment: Alignment.center,
        margin: EdgeInsets.only(bottom: screenHeight * 0.02),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(screenHeight * 0.032),
          color: sel ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.w500,
            color: sel ? Colors.white : Colors.black,
            overflow: TextOverflow.ellipsis,
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
          body: SafeArea(
            minimum: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.06,
              vertical: screenHeight * 0.03,
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      screenHeight -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BackButton(),
                      SizedBox(height: screenHeight * 0.04),
                      Text(
                        'Who are you\ninterested in seeing?',
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.04),
                      _pill('Female', screenWidth, screenHeight),
                      _pill('Male', screenWidth, screenHeight),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * 0.07,
                        child: NextButton(
                          label: 'NEXT',
                          onPressed: _continueToHobbies,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
