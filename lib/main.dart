import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:sambandha/screens/login_screen.dart';
import 'package:sambandha/screens/signup_page.dart';
import 'package:sambandha/screens/first_name_screen.dart';
import 'package:sambandha/screens/gender_screen.dart';
import 'package:sambandha/screens/birthday_screen.dart';
import 'package:sambandha/screens/interest_screen.dart';
import 'package:sambandha/screens/hobbies_screen.dart';
import 'package:sambandha/screens/distance_preference_screen.dart';
import 'package:sambandha/screens/relationship_target_screen.dart';
import 'package:sambandha/screens/homepage.dart';         // ✅ Home screen
import 'package:sambandha/screens/match_screen.dart';     // ✅ Match screen

import 'firebase_options.dart';
import 'model/profile_setup_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAMBANDHA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),

      // 👇 Start app directly at login screen
      initialRoute: '/login',

      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());

          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());

          case '/first-name':
            final data = settings.arguments as ProfileSetupData?;
            return MaterialPageRoute(
              builder: (_) => FirstNameScreen(data: data ?? ProfileSetupData()),
            );

          case '/gender':
            return MaterialPageRoute(
              builder: (_) =>
                  GenderScreen(data: settings.arguments as ProfileSetupData),
            );

          case '/birthday':
            return MaterialPageRoute(
              builder: (_) =>
                  BirthdayScreen(data: settings.arguments as ProfileSetupData),
            );

          case '/interest':
            return MaterialPageRoute(
              builder: (_) =>
                  InterestScreen(data: settings.arguments as ProfileSetupData),
            );

          case '/hobbies':
            return MaterialPageRoute(
              builder: (_) =>
                  HobbiesScreen(data: settings.arguments as ProfileSetupData),
            );

          case '/distance-preference':
            return MaterialPageRoute(
              builder: (_) => DistancePreferenceScreen(
                data: settings.arguments as ProfileSetupData,
              ),
            );

          case '/relationship-target':
            return MaterialPageRoute(
              builder: (_) => RelationshipTargetScreen(
                data: settings.arguments as ProfileSetupData,
              ),
            );

          case '/home':
            return MaterialPageRoute(
              builder: (_) => const Homepage(),
            );

          case '/matches':
            return MaterialPageRoute(
              builder: (_) => MatchScreen(),
            );

          default:
            // fallback to login
            return MaterialPageRoute(builder: (_) => const LoginPage());
        }
      },
    );
  }
}
