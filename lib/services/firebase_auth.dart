import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if email exists
  Future<List<String>> checkEmailExists(String email) async {
    return await _auth.fetchSignInMethodsForEmail(email);
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Store FCM token after successful user creation
    if (userCredential.user != null) {
      await _storeFCMToken(userCredential.user!.uid);
    }

    return userCredential;
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Store FCM token after successful sign-in
    if (userCredential.user != null) {
      await _storeFCMToken(userCredential.user!.uid);
    }

    return userCredential;
  }

  // Store FCM token for the user
  Future<void> _storeFCMToken(String userId) async {
    try {
      final fcmToken = await NotificationService.getCurrentFCMToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('user_interests')
            .doc(userId)
            .update({
              'fcmToken': fcmToken,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
        print('FCM token stored for user: $userId');
      }
    } catch (e) {
      // Create document if it doesn't exist
      try {
        final fcmToken = await NotificationService.getCurrentFCMToken();
        if (fcmToken != null) {
          await FirebaseFirestore.instance
              .collection('user_interests')
              .doc(userId)
              .set({
                'fcmToken': fcmToken,
                'lastTokenUpdate': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          print('FCM token created for user: $userId');
        }
      } catch (e2) {
        print('Error storing FCM token: $e2');
      }
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Reload user (for checking email verification)
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
