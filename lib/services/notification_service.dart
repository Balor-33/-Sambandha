import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');

  // Show local notification for background messages
  if (message.notification != null) {
    await NotificationService._showLocalNotificationFromRemote(message);
  }
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Navigation callback
  static Function(String route, Map<String, dynamic>? arguments)?
  onNotificationTap;

  // Initialize notification service
  static Future<void> initialize() async {
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Configure Firebase messaging
    await _configureFCM();

    // Get and store FCM token
    await _getAndStoreFCMToken();
  }

  static Future<void> _requestPermissions() async {
    // Request notification permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('Notification permission status: ${settings.authorizationStatus}');

    // For iOS, also request local notification permissions
    if (Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  static Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel matchChannel = AndroidNotificationChannel(
      'sambandha_match_channel',
      'Match Notifications',
      description: 'Notifications for new matches',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel messageChannel =
        AndroidNotificationChannel(
          'sambandha_message_channel',
          'Message Notifications',
          description: 'Notifications for new messages',
          importance: Importance.high,
          playSound: true,
        );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(matchChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(messageChannel);
  }

  static Future<void> _configureFCM() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // Get and store FCM token
  static Future<void> _getAndStoreFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _storeFCMToken(token);
        print('FCM Token: $token');
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_storeFCMToken);
  }

  // Store FCM token in Firestore
  static Future<void> _storeFCMToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('user_interests').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token stored for user: $userId');
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  // Get FCM token for a specific user
  static Future<String?> getUserFCMToken(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('user_interests')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()?['fcmToken'] as String?;
      }
    } catch (e) {
      print('Error getting user FCM token: $e');
    }
    return null;
  }

  // Send match notification - NOW SENDS REAL FCM NOTIFICATION
  static Future<void> sendMatchNotification({
    required String targetUserId,
    required String matchedUserName,
    required String matchedUserId,
    String? matchedUserProfilePic,
  }) async {
    try {
      final targetFCMToken = await getUserFCMToken(targetUserId);
      if (targetFCMToken == null) {
        print('No FCM token found for user: $targetUserId');
        // Still show local notification as fallback
        await _showLocalMatchNotification(matchedUserName);
        return;
      }

      // Send actual FCM push notification
      await _sendFCMNotification(
        targetFCMToken: targetFCMToken,
        title: "It's a Match! 💕",
        body: 'You and $matchedUserName liked each other!',
        data: {
          'type': 'match',
          'matchedUserId': matchedUserId,
          'matchedUserName': matchedUserName,
        },
      );

      print('✅ Match notification sent to FCM token: $targetFCMToken');
    } catch (e) {
      print('Error sending match notification: $e');
      // Fallback to local notification
      await _showLocalMatchNotification(matchedUserName);
    }
  }

  // Send message notification - NOW SENDS REAL FCM NOTIFICATION
  static Future<void> sendMessageNotification({
    required String targetUserId,
    required String senderName,
    required String message,
    required String chatId,
    required String senderId,
  }) async {
    try {
      final targetFCMToken = await getUserFCMToken(targetUserId);
      if (targetFCMToken == null) {
        print('No FCM token found for user: $targetUserId');
        // Still show local notification as fallback
        await _showLocalMessageNotification(senderName, message, chatId);
        return;
      }

      // Send actual FCM push notification
      await _sendFCMNotification(
        targetFCMToken: targetFCMToken,
        title: senderName,
        body: message,
        data: {
          'type': 'message',
          'chatId': chatId,
          'senderId': senderId,
          'senderName': senderName,
        },
      );

      print('✅ Message notification sent to FCM token: $targetFCMToken');
    } catch (e) {
      print('Error sending message notification: $e');
      // Fallback to local notification
      await _showLocalMessageNotification(senderName, message, chatId);
    }
  }

  // Send FCM notification using HTTP request
  static Future<bool> _sendFCMNotification({
    required String targetFCMToken,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    const String serverKey = 'AIzaSyAJYkpVaiqWT8AFyvuE9u2sLTZB73Jj5cQ';

    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': targetFCMToken,
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data': data,
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM notification sent successfully');
        return true;
      } else {
        print('❌ FCM notification failed: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending FCM notification: $e');
      return false;
    }
  }

  // Show local match notification
  static Future<void> _showLocalMatchNotification(
    String matchedUserName,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'sambandha_match_channel',
          'Match Notifications',
          channelDescription: 'Notifications for new matches',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "It's a Match! 💕",
      'You and $matchedUserName liked each other!',
      platformChannelSpecifics,
      payload: jsonEncode({
        'type': 'match',
        'matchedUserName': matchedUserName,
      }),
    );
  }

  // Show local message notification
  static Future<void> _showLocalMessageNotification(
    String senderName,
    String message,
    String chatId,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'sambandha_message_channel',
          'Message Notifications',
          channelDescription: 'Notifications for new messages',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      senderName,
      message,
      platformChannelSpecifics,
      payload: jsonEncode({
        'type': 'message',
        'chatId': chatId,
        'senderName': senderName,
      }),
    );
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message: ${message.notification?.title}');

    // Show local notification for foreground messages
    await _showLocalNotification(message);
  }

  // Show local notification from RemoteMessage
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final type = message.data['type'];

    if (type == 'match') {
      await _showLocalMatchNotification(
        message.data['matchedUserName'] ?? 'Someone',
      );
    } else if (type == 'message') {
      await _showLocalMessageNotification(
        message.notification?.title ?? 'New Message',
        message.notification?.body ?? '',
        message.data['chatId'] ?? '',
      );
    }
  }

  // Show local notification from RemoteMessage for background handler
  static Future<void> _showLocalNotificationFromRemote(
    RemoteMessage message,
  ) async {
    try {
      final type = message.data['type'];

      if (type == 'match') {
        await _showLocalMatchNotification(
          message.data['matchedUserName'] ?? 'Someone',
        );
      } else if (type == 'message') {
        await _showLocalMessageNotification(
          message.notification?.title ?? 'New Message',
          message.notification?.body ?? '',
          message.data['chatId'] ?? '',
        );
      }
    } catch (e) {
      print('Error showing background notification: $e');
    }
  }

  // Handle notification taps from Firebase messages
  static void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');

    final type = message.data['type'];

    if (type == 'match') {
      _handleMatchNotificationTap(message.data);
    } else if (type == 'message') {
      _handleMessageNotificationTap(message.data);
    }
  }

  // Handle local notification taps
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    if (notificationResponse.payload != null) {
      try {
        final data = jsonDecode(notificationResponse.payload!);
        final type = data['type'];

        if (type == 'match') {
          _handleMatchNotificationTap(data);
        } else if (type == 'message') {
          _handleMessageNotificationTap(data);
        }
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  static void _handleMatchNotificationTap(Map<String, dynamic> data) {
    print('Handle match notification tap: $data');
    // Navigate to matches screen
    if (onNotificationTap != null) {
      onNotificationTap!('/matches', data);
    }
  }

  static void _handleMessageNotificationTap(Map<String, dynamic> data) {
    print('Handle message notification tap: $data');
    // Navigate to specific chat
    if (onNotificationTap != null) {
      onNotificationTap!('/chat', {
        'chatId': data['chatId'],
        'senderName': data['senderName'],
      });
    }
  }

  // Set navigation callback
  static void setNavigationCallback(
    Function(String route, Map<String, dynamic>? arguments) callback,
  ) {
    onNotificationTap = callback;
  }

  // Get current FCM token
  static Future<String?> getCurrentFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error getting current FCM token: $e');
      return null;
    }
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Clear specific notification
  static Future<void> clearNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
  }
}
