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

    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      // Create new chat
      await chatRef.set({
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
      });
    }

    return chatId;
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

  // Get unread message count for a chat
  Future<int> getUnreadMessageCount(String chatId, String userId) async {
    try {
      // This is a simplified version. For a complete implementation,
      // you'd need to track read status for each message
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .orderBy('senderId')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      // For now, return 0. Implement proper read tracking if needed
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Get all chats for current user
  Stream<List<Map<String, dynamic>>> getUserChats() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }
}
