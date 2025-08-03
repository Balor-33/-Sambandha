import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import '../widgets/encryption_helper.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate chat ID from two user IDs (consistent ordering)
  String getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // Create or get existing chat
  Future<String> createOrGetChat(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    final chatId = getChatId(currentUserId, otherUserId);
    final chatRef = _firestore.collection('chats').doc(chatId);

    try {
      final chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        // Create new chat with required fields matching security rules
        await chatRef.set({
          'participants': [currentUserId, otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageSenderId': '',
        });
      }

      return chatId;
    } catch (e) {
      print('Error creating/getting chat: $e');
      rethrow;
    }
  }

  // Get user data from user_interests collection
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('user_interests')
          .doc(userId)
          .get();
      return userDoc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Get user data from users collection (fallback)
  Future<Map<String, dynamic>?> getUserFromUsersCollection(
    String userId,
  ) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      print('Error getting user from users collection: $e');
      return null;
    }
  }

  // Send a message
  Future<void> sendMessage(String chatId, String message) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    if (message.trim().isEmpty) return;

    try {
      final batch = _firestore.batch();

      // Encrypt the message before saving
      final encryptedMessage = EncryptionHelper.encryptText(message.trim());

      // Add message to subcollection
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'text': encryptedMessage,
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      // Update chat document
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'lastMessage': encryptedMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
      });

      await batch.commit();

      // Send notification to the other user (optional: send plain or encrypted)
      await _sendMessageNotification(chatId, message.trim(), currentUser.uid);
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Helper method to send message notifications
  Future<void> _sendMessageNotification(
    String chatId,
    String message,
    String senderId,
  ) async {
    try {
      // Get other user ID from chat ID
      final chatParts = chatId.split('_');
      if (chatParts.length != 2) return;

      final otherUserId = chatParts[0] == senderId
          ? chatParts[1]
          : chatParts[0];

      // Get sender's name
      final senderData = await getUserData(senderId);
      final senderName = senderData?['name'] ?? 'Someone';

      // Send notification
      await NotificationService.sendMessageNotification(
        targetUserId: otherUserId,
        senderName: senderName,
        message: message,
        chatId: chatId,
        senderId: senderId,
      );
    } catch (e) {
      print('Error sending message notification: $e');
    }
  }

  // Get messages stream
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get unread message count for a chat (returns count of messages from others since last read)
  Future<int> getUnreadMessageCount(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0;

    try {
      // Count messages from other users

      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .get();

      return messagesSnapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Enhanced method: Get last message info for chat preview
  Future<Map<String, dynamic>?> getLastMessage(String chatId) async {
    try {
      final lastMessageSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (lastMessageSnapshot.docs.isNotEmpty) {
        final messageData = lastMessageSnapshot.docs.first.data();
        return {
          'text': messageData['text'] ?? '',
          'senderId': messageData['senderId'] ?? '',
          'timestamp': messageData['timestamp'],
          'type': messageData['type'] ?? 'text',
        };
      }
      return null;
    } catch (e) {
      print('Error getting last message: $e');
      return null;
    }
  }

  // Get all chats for current user
  Stream<List<Map<String, dynamic>>> getUserChats() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  // Get enriched chat data with other user's information
  Future<List<Map<String, dynamic>>> getUserChatsWithUserData() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .orderBy('lastMessageAt', descending: true)
          .get();

      List<Map<String, dynamic>> enrichedChats = [];

      for (var chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);

        // Get the other user's ID
        final otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          // Try to get user data from user_interests first, then users collection
          var otherUserData = await getUserData(otherUserId);
          otherUserData ??= await getUserFromUsersCollection(otherUserId);

          enrichedChats.add({
            'id': chatDoc.id,
            'chatData': chatData,
            'otherUserId': otherUserId,
            'otherUserData':
                otherUserData ?? {'name': 'Unknown User', 'image': ''},
          });
        }
      }

      return enrichedChats;
    } catch (e) {
      print('Error getting enriched chats: $e');
      return [];
    }
  }

  // Check if chat exists
  Future<bool> chatExists(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if chat exists: $e');
      return false;
    }
  }

  // Get chat data
  Future<Map<String, dynamic>?> getChatData(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      return doc.data();
    } catch (e) {
      print('Error getting chat data: $e');
      return null;
    }
  }
}
