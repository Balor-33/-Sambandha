import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

// Make sure to import your updated ChatService
// import 'chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Use ChatService for better error handling
  // late final ChatService _chatService;

  @override
  void initState() {
    super.initState();
    // _chatService = ChatService();
    _ensureChatExists();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Ensure chat document exists before loading messages
  Future<void> _ensureChatExists() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatDoc = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) {
        // Create chat if it doesn't exist
        await _firestore.collection('chats').doc(widget.chatId).set({
          'participants': [currentUser.uid, widget.otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageSenderId': '',
        });
      }
    } catch (e) {
      print('Error ensuring chat exists: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Use batch write for atomicity
      final batch = _firestore.batch();

      // Add message to subcollection
      final messageRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(); // Auto-generate ID

      batch.set(messageRef, {
        'text': message,
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      // Update chat's last message
      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      batch.update(chatRef, {
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
      });

      await batch.commit();

      // Auto scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: _getImageProvider(widget.otherUserImage),
              backgroundColor: Colors.grey.shade200,
              child: widget.otherUserImage.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Active now',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.grey),
            onPressed: () {
              // Video call functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: Colors.grey),
            onPressed: () {
              // Voice call functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Stream error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}), // Trigger rebuild
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _getImageProvider(
                            widget.otherUserImage,
                          ),
                          backgroundColor: Colors.grey.shade200,
                          child: widget.otherUserImage.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 50,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You matched with ${widget.otherUserName}!',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start the conversation with a friendly message!',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Auto-scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final message = messageDoc.data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == _auth.currentUser?.uid;

                    return _buildMessageBubble(
                      message['text'] ?? '',
                      isMe,
                      message['timestamp'] as Timestamp?,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // Helper method to get appropriate image provider
  ImageProvider? _getImageProvider(String imageString) {
    if (imageString.isEmpty) return null;

    if (imageString.startsWith('data:image')) {
      // Data URL format
      return NetworkImage(imageString);
    } else if (imageString.startsWith('http')) {
      // Regular URL
      return NetworkImage(imageString);
    } else {
      // Assume base64 string
      try {
        return MemoryImage(const Base64Decoder().convert(imageString));
      } catch (e) {
        print('Error decoding base64 image: $e');
        return null;
      }
    }
  }

  // Helper method for current user image
  ImageProvider? _getCurrentUserImageProvider() {
    final photoURL = _auth.currentUser?.photoURL;
    if (photoURL?.isNotEmpty == true) {
      return NetworkImage(photoURL!);
    }
    return null;
  }

  Widget _buildMessageBubble(String message, bool isMe, Timestamp? timestamp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: _getImageProvider(widget.otherUserImage),
              backgroundColor: Colors.grey.shade200,
              child: widget.otherUserImage.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFFF4458) : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: _getCurrentUserImageProvider(),
              backgroundColor: Colors.grey.shade200,
              child: _auth.currentUser?.photoURL?.isEmpty != false
                  ? const Icon(Icons.person, color: Colors.grey, size: 16)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLength: 1000, // Match security rules limit
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) {
                      // Hide counter unless close to limit
                      if (currentLength > 900) {
                        return Text(
                          '$currentLength/$maxLength',
                          style: TextStyle(
                            color: currentLength >= maxLength!
                                ? Colors.red
                                : Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
                    },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFF4458),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
