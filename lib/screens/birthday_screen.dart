import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/profile_setup_data.dart';
import '../widgets/next_button.dart';

class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({super.key, required this.data});
  final ProfileSetupData data;

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  DateTime? _date;
  int? _age; // Store the calculated age
  final _format = DateFormat('dd/MM/yyyy');

  // Function to calculate age from birthdate
  int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    // Check if birthday hasn't occurred this year yet
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  // Function to check if user is 18 or older
  bool isEligibleAge(DateTime birthDate) {
    int age = calculateAge(birthDate);
    return age >= 18;
  }

  // Function to get minimum allowed birth date (18 years ago)
  DateTime getMinimumBirthDate() {
    DateTime currentDate = DateTime.now();
    return DateTime(currentDate.year - 18, currentDate.month, currentDate.day);
  }

  Future<void> _pick() async {
    final minDate = getMinimumBirthDate();

    final picked = await showDatePicker(
      context: context,
      initialDate: minDate, // Start at minimum eligible date
      firstDate: DateTime(1900),
      lastDate: minDate, // Don't allow dates newer than 18 years ago
    );

    if (picked != null) {
      setState(() {
        _date = picked;
        _age = calculateAge(picked); // Store age in variable
      });
    }
  }

  void _goNext() {
    if (_date == null) {
      _error('Please choose your birth date');
      return;
    }

    // Validate age before proceeding (using stored age)
    if (_age == null || _age! < 18) {
      _error('You must be 18 or older to proceed');
      return;
    }

    widget.data.birthDate = _date;
    Navigator.pushNamed(context, '/interest', arguments: widget.data);
  }

  void _error(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.04),
                  Text(
                    'When is your birthday?',
                    style: TextStyle(
                      fontSize: screenWidth * 0.07,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  GestureDetector(
                    onTap: _pick,
                    child: AbsorbPointer(
                      child: TextField(
                        readOnly: true,
                        controller: TextEditingController(
                          text: _date == null ? '' : _format.format(_date!),
                        ),
                        style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 2.0,
                          height: 1,
                        ),
                        decoration: InputDecoration(
                          hintText: 'MM/DD/YYYY',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.04,
                            vertical: screenHeight * 0.02,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  // Show age if date is selected
                  if (_date != null && _age != null) ...[
                    Text(
                      'Age: $_age years',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Show warning if under 18 (though date picker should prevent this)
                    if (_age! < 18)
                      const Text(
                        'Must be 18 or older',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                  SizedBox(
                    height: screenHeight * 0.10,
                  ), // <-- Use this instead of Spacer
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.07,
                    child: NextButton(label: 'NEXT', onPressed: _goNext),
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
