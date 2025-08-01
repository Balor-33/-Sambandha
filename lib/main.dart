import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sambandha/screens/interest_screen.dart';
import 'firebase_options.dart';
import 'model/profile_setup_data.dart';
import 'screens/login_screen.dart'; // Add this import
import 'screens/signup_page.dart';
import 'screens/first_name_screen.dart';
import 'screens/gender_screen.dart';
import 'screens/birthday_screen.dart';
import 'screens/hobbies_screen.dart';
import 'screens/distance_preference_screen.dart';
import 'screens/relationship_target_screen.dart';

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
        // 🔤 Global Inter font applied here
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),

      // 👉 FIRST screen you see - changed to welcome
      initialRoute: '/welcome',

      // 👉 Dynamic routing so we can pass / read arguments safely
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/welcome':
            return MaterialPageRoute(builder: (_) => const WelcomePage());

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

          // Add a home route for after login/signup completion
          case '/home':
            // Replace this with your actual home/main app screen
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Welcome to SAMBANDHA!')),
              ),
            );

          default:
            // Fallback → show welcome page so app never crashes on a bad route
            return MaterialPageRoute(builder: (_) => const WelcomePage());
        }
      },
    );
  }
}
