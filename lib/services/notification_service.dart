// Enhanced notification_service.dart with campaign integration
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

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

  // Campaign configuration - REPLACE WITH YOUR ACTUAL VALUES
  static const String _campaignApiUrl =
      'YOUR_CAMPAIGN_API_ENDPOINT'; // Replace with your campaign API
  static const String _campaignApiKey =
      'YOUR_CAMPAIGN_API_KEY'; // Replace with your API key
  static const String _matchCampaignId =
      'sambandha_match_campaign'; // Your match campaign ID
  static const String _messageCampaignId =
      'sambandha_message_campaign'; // Your message campaign ID

  // Firebase Server Key (keep your existing one)
  static const String _firebaseServerKey =
      'AIzaSyAJYkpVaiqWT8AFyvuE9u2sLTZB73Jj5cQ';

  // Navigation callback
  static Function(String route, Map<String, dynamic>? arguments)?
  onNotificationTap;

  // Initialize notification service
  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _requestPermissions();
    await _initializeLocalNotifications();
    await _configureFCM();
    await _getAndStoreFCMToken();
  }

  static Future<void> _requestPermissions() async {
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
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

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

    _firebaseMessaging.onTokenRefresh.listen(_storeFCMToken);
  }

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

  // Enhanced match notification with campaign integration
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
        await _showLocalMatchNotification(matchedUserName);
        return;
      }

      // Try campaign notification first
      bool campaignSent = await _sendCampaignMatchNotification(
        targetUserId: targetUserId,
        targetFCMToken: targetFCMToken,
        matchedUserName: matchedUserName,
        matchedUserId: matchedUserId,
        matchedUserProfilePic: matchedUserProfilePic,
      );

      // If campaign fails, fall back to direct FCM
      if (!campaignSent) {
        print('Campaign notification failed, falling back to direct FCM');
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
      }

      print('✅ Match notification sent successfully');
    } catch (e) {
      print('Error sending match notification: $e');
      await _showLocalMatchNotification(matchedUserName);
    }
  }

  // Enhanced message notification with campaign integration
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
        await _showLocalMessageNotification(senderName, message, chatId);
        return;
      }

      // Try campaign notification first
      bool campaignSent = await _sendCampaignMessageNotification(
        targetUserId: targetUserId,
        targetFCMToken: targetFCMToken,
        senderName: senderName,
        message: message,
        chatId: chatId,
        senderId: senderId,
      );

      // If campaign fails, fall back to direct FCM
      if (!campaignSent) {
        print('Campaign notification failed, falling back to direct FCM');
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
      }

      print('✅ Message notification sent successfully');
    } catch (e) {
      print('Error sending message notification: $e');
      await _showLocalMessageNotification(senderName, message, chatId);
    }
  }

  // NEW: Send notification via campaign API for matches
  static Future<bool> _sendCampaignMatchNotification({
    required String targetUserId,
    required String targetFCMToken,
    required String matchedUserName,
    required String matchedUserId,
    String? matchedUserProfilePic,
  }) async {
    try {
      if (_campaignApiUrl == 'YOUR_CAMPAIGN_API_ENDPOINT') {
        print('Campaign API not configured, skipping campaign notification');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_campaignApiUrl/send-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_campaignApiKey',
        },
        body: jsonEncode({
          'campaign_id': _matchCampaignId,
          'recipient': {'user_id': targetUserId, 'fcm_token': targetFCMToken},
          'notification_data': {
            'title': "It's a Match! 💕",
            'body': 'You and $matchedUserName liked each other!',
            'type': 'match',
            'matched_user_id': matchedUserId,
            'matched_user_name': matchedUserName,
            'matched_user_profile_pic': matchedUserProfilePic,
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Campaign match notification sent successfully');
        return true;
      } else {
        print('❌ Campaign match notification failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending campaign match notification: $e');
      return false;
    }
  }

  // NEW: Send notification via campaign API for messages
  static Future<bool> _sendCampaignMessageNotification({
    required String targetUserId,
    required String targetFCMToken,
    required String senderName,
    required String message,
    required String chatId,
    required String senderId,
  }) async {
    try {
      if (_campaignApiUrl == 'YOUR_CAMPAIGN_API_ENDPOINT') {
        print('Campaign API not configured, skipping campaign notification');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_campaignApiUrl/send-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_campaignApiKey',
        },
        body: jsonEncode({
          'campaign_id': _messageCampaignId,
          'recipient': {'user_id': targetUserId, 'fcm_token': targetFCMToken},
          'notification_data': {
            'title': senderName,
            'body': message,
            'type': 'message',
            'chat_id': chatId,
            'sender_id': senderId,
            'sender_name': senderName,
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Campaign message notification sent successfully');
        return true;
      } else {
        print('❌ Campaign message notification failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending campaign message notification: $e');
      return false;
    }
  }

  // Send FCM notification using HTTP request (fallback method)
  static Future<bool> _sendFCMNotification({
    required String targetFCMToken,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_firebaseServerKey',
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

  // NEW: Method to track notification delivery status
  static Future<void> trackNotificationDelivery({
    required String userId,
    required String notificationType,
    required String status, // 'sent', 'delivered', 'opened', 'failed'
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firestore.collection('notification_analytics').add({
        'userId': userId,
        'notificationType': notificationType,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      });
    } catch (e) {
      print('Error tracking notification: $e');
    }
  }

  // Rest of your existing methods remain the same...
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

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message: ${message.notification?.title}');
    await _showLocalNotification(message);
  }

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

  static void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');

    final type = message.data['type'];

    if (type == 'match') {
      _handleMatchNotificationTap(message.data);
    } else if (type == 'message') {
      _handleMessageNotificationTap(message.data);
    }
  }

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
    if (onNotificationTap != null) {
      onNotificationTap!('/matches', data);
    }
  }

  static void _handleMessageNotificationTap(Map<String, dynamic> data) {
    print('Handle message notification tap: $data');
    if (onNotificationTap != null) {
      onNotificationTap!('/chat', {
        'chatId': data['chatId'],
        'senderName': data['senderName'],
      });
    }
  }

  static void setNavigationCallback(
    Function(String route, Map<String, dynamic>? arguments) callback,
  ) {
    onNotificationTap = callback;
  }

  static Future<String?> getCurrentFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error getting current FCM token: $e');
      return null;
    }
  }

  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  static Future<void> clearNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
  }
}
