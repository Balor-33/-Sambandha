import 'package:flutter/material.dart';
import '../../model/profile_setup_data.dart';
import '../widgets/next_button.dart';
import 'package:intl/intl.dart';

class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({super.key, required this.data});
  final ProfileSetupData data;

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  DateTime? _date;
  final _format = DateFormat('dd/MM/yyyy');

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _goNext() {
    if (_date == null) {
      _error('Please choose your birth date');
      return;
    }
    widget.data.birthDate = _date;
    Navigator.pushNamed(context, '/interest', arguments: widget.data);
  }

  void _error(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
            const Text('Your b-day?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pick,
              child: AbsorbPointer(
                child: TextField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: _date == null ? '' : _format.format(_date!),
                  ),
                  style:
                      const TextStyle(fontSize: 28, letterSpacing: 2.0, height: 1),
                  decoration: InputDecoration(
                    hintText: '05/05/2004',
                    border: const UnderlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your profile shows your age, not your birth date',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Spacer(),
            NextButton(label: 'NEXT', onPressed: _goNext),
          ],
        ),
      ),
    );
  }
}
