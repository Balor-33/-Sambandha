import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Sambandha/screens/interest_screen.dart';
import 'firebase_options.dart';
import 'model/profile_setup_data.dart';
import 'screens/login_screen.dart';
import 'screens/signup_page.dart';
import 'screens/first_name_screen.dart';
import 'screens/gender_screen.dart';
import 'screens/birthday_screen.dart';
import 'screens/hobbies_screen.dart';
import 'screens/distance_preference_screen.dart';
import 'screens/relationship_target_screen.dart';
import 'services/notification_service.dart';
import 'screens/homepage.dart';
// Import your chat and matches screens
// import 'screens/chat_screen.dart';
// import 'screens/matches_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Set up notification navigation callback
    NotificationService.setNavigationCallback(_handleNotificationTap);
  }

  void _handleNotificationTap(String route, Map<String, dynamic>? arguments) {
    // Handle notification tap navigation
    print('Navigating to: $route with arguments: $arguments');

    if (navigatorKey.currentState != null) {
      switch (route) {
        case '/matches':
          // Navigate to matches screen
          navigatorKey.currentState!.pushNamed(
            '/matches',
            arguments: arguments,
          );
          break;
        case '/chat':
          // Navigate to specific chat
          navigatorKey.currentState!.pushNamed('/chat', arguments: arguments);
          break;
        default:
          print('Unknown notification route: $route');
          // Navigate to home as fallback
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SAMBANDHA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 🔤 Global Inter font applied here
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),

      // 👉 Use AuthWrapper to check login state
      home: const AuthWrapper(),

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

          case '/home':
            return MaterialPageRoute(builder: (_) => const Homepage());

          default:
            // Fallback → show welcome page so app never crashes on a bad route
            return MaterialPageRoute(builder: (_) => const WelcomePage());
        }
      },
    );
  }
}

// NEW: Auth wrapper to check if user is logged in
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          print('User is logged in: ${snapshot.data!.email}');
          return const Homepage(); // Replace with your actual homepage widget
        }

        // If user is not logged in
        print('User is not logged in');
        return const WelcomePage(); // Your welcome/login screen
      },
    );
  }
}
