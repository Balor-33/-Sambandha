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

      // Update chat document with encrypted last message
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'lastMessage': encryptedMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
      });

      await batch.commit();

      // Send notification with decrypted message (for user readability)
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

      // Send notification with plain text message (not encrypted)
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

  // Enhanced method: Get last message info for chat preview with decryption
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

        // Decrypt the message text for display
        String decryptedText = '';
        try {
          decryptedText = EncryptionHelper.decryptText(
            messageData['text'] ?? '',
          );
        } catch (e) {
          print('Error decrypting last message: $e');
          decryptedText = '[Unable to decrypt]';
        }

        return {
          'text': decryptedText, // Return decrypted text
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

  // Get enriched chat data with other user's information and decrypted last messages
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

          // Decrypt the last message for display
          String decryptedLastMessage = '';
          if (chatData['lastMessage'] != null &&
              chatData['lastMessage'].toString().isNotEmpty) {
            try {
              decryptedLastMessage = EncryptionHelper.decryptText(
                chatData['lastMessage'],
              );
            } catch (e) {
              print('Error decrypting last message for chat ${chatDoc.id}: $e');
              decryptedLastMessage = '[Unable to decrypt]';
            }
          }

          // Create a modified chatData with decrypted last message
          final modifiedChatData = Map<String, dynamic>.from(chatData);
          modifiedChatData['lastMessage'] = decryptedLastMessage;

          enrichedChats.add({
            'id': chatDoc.id,
            'chatData':
                modifiedChatData, // Use modified data with decrypted message
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

  // Get enriched chat data with other user's information (Stream version with decryption)
  Stream<List<Map<String, dynamic>>> getUserChatsWithUserDataStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> enrichedChats = [];

          for (var chatDoc in snapshot.docs) {
            final chatData = chatDoc.data();
            final participants = List<String>.from(
              chatData['participants'] ?? [],
            );

            // Get the other user's ID
            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherUserId.isNotEmpty) {
              // Try to get user data from user_interests first, then users collection
              var otherUserData = await getUserData(otherUserId);
              otherUserData ??= await getUserFromUsersCollection(otherUserId);

              // Decrypt the last message for display
              String decryptedLastMessage = '';
              if (chatData['lastMessage'] != null &&
                  chatData['lastMessage'].toString().isNotEmpty) {
                try {
                  decryptedLastMessage = EncryptionHelper.decryptText(
                    chatData['lastMessage'],
                  );
                } catch (e) {
                  print(
                    'Error decrypting last message for chat ${chatDoc.id}: $e',
                  );
                  decryptedLastMessage = '[Unable to decrypt]';
                }
              }

              // Create a modified chatData with decrypted last message
              final modifiedChatData = Map<String, dynamic>.from(chatData);
              modifiedChatData['lastMessage'] = decryptedLastMessage;

              enrichedChats.add({
                'id': chatDoc.id,
                'chatData': modifiedChatData,
                'otherUserId': otherUserId,
                'otherUserData':
                    otherUserData ?? {'name': 'Unknown User', 'image': ''},
              });
            }
          }

          return enrichedChats;
        });
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

  // Get chat data with decrypted last message
  Future<Map<String, dynamic>?> getChatDataWithDecryption(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (!doc.exists) return null;

      final chatData = Map<String, dynamic>.from(doc.data()!);

      // Decrypt the last message if it exists
      if (chatData['lastMessage'] != null &&
          chatData['lastMessage'].toString().isNotEmpty) {
        try {
          chatData['lastMessage'] = EncryptionHelper.decryptText(
            chatData['lastMessage'],
          );
        } catch (e) {
          print(
            'Error decrypting last message in getChatDataWithDecryption: $e',
          );
          chatData['lastMessage'] = '[Unable to decrypt]';
        }
      }

      return chatData;
    } catch (e) {
      print('Error getting chat data with decryption: $e');
      return null;
    }
  }

  // Mark messages as read (optional feature for read receipts)
  Future<void> markMessagesAsRead(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // This could be implemented to track read status
      // For now, we'll just update a field in the chat document
      await _firestore.collection('chats').doc(chatId).update({
        'lastReadBy$currentUserId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Delete a message (optional feature)
  Future<void> deleteMessage(String chatId, String messageId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Get the message to check if current user is the sender
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final messageData = messageDoc.data()!;
      if (messageData['senderId'] != currentUserId) {
        throw Exception('You can only delete your own messages');
      }

      // Delete the message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();

      // Optionally update the last message if this was the last message
      // This would require fetching the new last message and updating the chat document
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  // Search messages in a chat (with decryption)
  Future<List<Map<String, dynamic>>> searchMessagesInChat(
    String chatId,
    String searchQuery,
  ) async {
    if (searchQuery.trim().isEmpty) return [];

    try {
      // Note: Firestore doesn't support full-text search on encrypted data
      // This is a limitation of client-side encryption
      // You would need to fetch all messages and decrypt them locally for search
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> matchingMessages = [];

      for (var doc in messagesSnapshot.docs) {
        final messageData = doc.data();

        // Decrypt message for search
        try {
          final decryptedText = EncryptionHelper.decryptText(
            messageData['text'] ?? '',
          );

          // Check if decrypted text contains search query (case insensitive)
          if (decryptedText.toLowerCase().contains(searchQuery.toLowerCase())) {
            matchingMessages.add({
              'id': doc.id,
              'text': decryptedText,
              'senderId': messageData['senderId'],
              'timestamp': messageData['timestamp'],
              'type': messageData['type'] ?? 'text',
            });
          }
        } catch (e) {
          print('Error decrypting message for search: $e');
          // Skip messages that can't be decrypted
          continue;
        }
      }

      return matchingMessages;
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }
}
