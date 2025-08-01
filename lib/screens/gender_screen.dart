import 'package:flutter/material.dart';
import '../../model/profile_setup_data.dart';
import '../widgets/next_button.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key, required this.data});
  final ProfileSetupData data;

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? _selected;

  void _goNext() {
    if (_selected == null) {
      _error('Please pick a gender');
      return;
    }
    widget.data.gender = _selected;
    Navigator.pushNamed(context, '/birthday', arguments: widget.data);
  }

  void _error(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _pill(
    String label,
    String emoji,
    double screenWidth,
    double screenHeight,
  ) {
    final isSel = _selected == label;
    return GestureDetector(
      onTap: () => setState(() => _selected = label),
      child: Container(
        height: screenHeight * 0.065,
        alignment: Alignment.center,
        margin: EdgeInsets.only(bottom: screenHeight * 0.02),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(screenHeight * 0.032),
          color: isSel ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Text(
          '$label $emoji',
          style: TextStyle(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.w500,
            color: isSel ? Colors.white : Colors.black,
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
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenHeight * 0.03,
              ),
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
                        'Specify your gender',
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.04),
                      _pill('Male', '👨', screenWidth, screenHeight),
                      _pill('Female', '👩', screenWidth, screenHeight),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(top: screenHeight * 0.04),
                        child: SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
                          child: NextButton(label: 'NEXT', onPressed: _goNext),
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
