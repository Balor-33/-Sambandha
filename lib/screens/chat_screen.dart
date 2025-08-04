import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../widgets/encryption_helper.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();

    // Test encryption/decryption
    if (EncryptionHelper.testEncryption()) {
      print('✅ Encryption test PASSED - Ready to use!');
    } else {
      print('❌ Encryption test FAILED - Check implementation!');
    }

    _ensureChatExists();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureChatExists() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatDoc = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) {
        await _firestore.collection('chats').doc(widget.chatId).set({
          'participants': [currentUser.uid, widget.otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageSenderId': '',
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ensuring chat exists: $e')),
        );
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final batch = _firestore.batch();

      // ENCRYPT the message before saving to Firestore
      final encryptedMessage = EncryptionHelper.encryptText(message);
      print(
        'Sending encrypted message: ${encryptedMessage.substring(0, 20)}...',
      );

      final messageRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'text': encryptedMessage, // Save encrypted text
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      batch.update(chatRef, {
        'lastMessage': encryptedMessage, // Save encrypted last message
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
      });

      await batch.commit();
      print('Message sent successfully');

      // Auto-scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  ImageProvider? _getImageProvider(String imageString) {
    if (imageString.isEmpty) return null;
    if (imageString.startsWith('http')) {
      return NetworkImage(imageString);
    }
    try {
      return MemoryImage(const Base64Decoder().convert(imageString));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
              radius: screenWidth * 0.055,
              backgroundImage: _getImageProvider(widget.otherUserImage),
              backgroundColor: Colors.grey.shade200,
              child: widget.otherUserImage.isEmpty
                  ? Icon(
                      Icons.person,
                      color: Colors.grey,
                      size: screenWidth * 0.055,
                    )
                  : null,
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Active now',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: screenWidth * 0.03,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: screenWidth * 0.12,
                          color: Colors.red,
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Text('Error loading messages: ${snapshot.error}'),
                        SizedBox(height: screenHeight * 0.02),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
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
                          radius: screenWidth * 0.13,
                          backgroundImage: _getImageProvider(
                            widget.otherUserImage,
                          ),
                          backgroundColor: Colors.grey.shade200,
                          child: widget.otherUserImage.isEmpty
                              ? Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: screenWidth * 0.13,
                                )
                              : null,
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Text(
                          'You matched with ${widget.otherUserName}!',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        Text(
                          'Start the conversation with a friendly message!',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * 0.04,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

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
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.01,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final message = messageDoc.data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == _auth.currentUser?.uid;

                    // DECRYPT the message text for display
                    String decryptedText = '';
                    try {
                      final encryptedMessage = message['text'] ?? '';
                      if (encryptedMessage.isEmpty) {
                        decryptedText = '[Empty message]';
                      } else {
                        decryptedText = EncryptionHelper.decryptText(
                          encryptedMessage,
                        );
                        print('Decrypted message: $decryptedText');
                      }
                    } catch (e) {
                      print('Error decrypting message: $e');
                      decryptedText = '[Unable to decrypt message]';
                    }

                    return _buildMessageBubble(
                      decryptedText,
                      isMe,
                      message['timestamp'] as Timestamp?,
                      screenWidth,
                      screenHeight,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(screenWidth, screenHeight),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    String message,
    bool isMe,
    Timestamp? timestamp,
    double screenWidth,
    double screenHeight,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: screenWidth * 0.045,
              backgroundImage: _getImageProvider(widget.otherUserImage),
              backgroundColor: Colors.grey.shade200,
              child: widget.otherUserImage.isEmpty
                  ? Icon(
                      Icons.person,
                      color: Colors.grey,
                      size: screenWidth * 0.045,
                    )
                  : null,
            ),
            SizedBox(width: screenWidth * 0.02),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenHeight * 0.015,
              ),
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
                message, // This is now the decrypted message
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                  fontSize: screenWidth * 0.042,
                ),
              ),
            ),
          ),
          if (isMe) ...[
            SizedBox(width: screenWidth * 0.02),
            CircleAvatar(
              radius: screenWidth * 0.045,
              backgroundImage: _getImageProvider(
                _auth.currentUser?.photoURL ?? '',
              ),
              backgroundColor: Colors.grey.shade200,
              child: _auth.currentUser?.photoURL?.isEmpty != false
                  ? Icon(
                      Icons.person,
                      color: Colors.grey,
                      size: screenWidth * 0.045,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(double screenWidth, double screenHeight) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: screenHeight * 0.012,
        ),
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
                  borderRadius: BorderRadius.circular(screenWidth * 0.07),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenHeight * 0.016,
                    ),
                    counterText: '', // Hide character counter
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  maxLength: 1000,
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFF4458),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: screenWidth * 0.06,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
