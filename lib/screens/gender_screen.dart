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

  Widget _pill(String label, String emoji) {
    final isSel = _selected == label;
    return GestureDetector(
      onTap: () => setState(() => _selected = label),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: isSel ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Text(
          '$label $emoji',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isSel ? Colors.white : Colors.black,
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
              'Specify your gender',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _pill('Male', '👨'),
            _pill('Female', '👩'),
            const Spacer(),
            NextButton(label: 'NEXT', onPressed: _goNext),
          ],
        ),
      ),
    );
  }
}
