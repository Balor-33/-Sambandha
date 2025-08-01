import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
          'lastMessageAt':
              FieldValue.serverTimestamp(), // Changed from lastMessageTime
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

  // Get user data from user_interests collection (matching your existing structure)
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

      // Add message to subcollection
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(); // Auto-generate message ID

      batch.set(messageRef, {
        'text': message.trim(),
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      // Update chat document
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'lastMessage': message.trim(),
        'lastMessageAt':
            FieldValue.serverTimestamp(), // Consistent with creation
        'lastMessageSenderId': currentUser.uid,
      });

      await batch.commit();
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
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
      // Note: This is a simplified version. For production, you'd want to track
      // read timestamps per user to get accurate unread counts
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
        .orderBy(
          'lastMessageAt',
          descending: true,
        ) // Changed from lastMessageTime
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
