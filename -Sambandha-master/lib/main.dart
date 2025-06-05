import 'package:flutter/material.dart';
import 'login_page.dart';
import 'firstname.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dating App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(onLoginSuccess: () {}),
        '/first-name': (context) => const FirstNameScreen(),
        // Add additional routes here like '/gender': (context) => GenderScreen()
      },
    );
  }
}
