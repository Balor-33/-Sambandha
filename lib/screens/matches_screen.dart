import 'package:flutter/material.dart';
import 'package:sambandha/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_user_service.dart';

import '../services/user_data_service.dart';
import '../model/match_model.dart';
import '../screens/chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  final void Function(String matchUserId, String matchUserName)? onChat;
  const MatchesScreen({super.key, this.onChat});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final FirebaseUserService _userService = FirebaseUserService();
  final ChatService _chatService = ChatService();
  final UserDataService _userDataService = UserDataService(); // Add this
  late Stream<List<Match>> _matchesStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _userService.currentUserId;
    _matchesStream = _getMatchesStream();
  }

  Stream<List<Match>> _getMatchesStream() {
    final uid = _userService.currentUserId;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection(FirebaseUserService.MATCHES_COLLECTION)
        .where('userA', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Match.fromMap(doc.data(), doc.id))
              .toList(),
        )
        .asyncMap((matchesA) async {
          final matchesB = await FirebaseFirestore.instance
              .collection(FirebaseUserService.MATCHES_COLLECTION)
              .where('userB', isEqualTo: uid)
              .get();
          final matchesBList = matchesB.docs
              .map((doc) => Match.fromMap(doc.data(), doc.id))
              .toList();
          return [...matchesA, ...matchesBList];
        });
  }

  Future<String?> _getProfilePicture(String userId) async {
    return await _userService.getUserProfilePicture(userId);
  }

  Future<int> _getUnreadCount(String matchUserId) async {
    try {
      final chatId = _chatService.getChatId(_currentUserId!, matchUserId);
      return await _chatService.getUnreadMessageCount(chatId);
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<String> _getUserName(String userId) async {
    return await _userDataService.getUserName(userId);
  }

  Future<String> _getUserImageUrl(String userId) async {
    try {
      final profilePic = await _userDataService.getUserProfilePicture(userId);
      return profilePic ?? '';
    } catch (e) {
      print('Error getting user image: $e');
      return '';
    }
  }

  void _openChat(String matchUserId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Create or get chat ID
      final chatId = await _chatService.createOrGetChat(matchUserId);

      // Get user details
      final userName = await _getUserName(matchUserId);
      final userImageUrl = await _getUserImageUrl(matchUserId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUserId: matchUserId,
              otherUserName: userName,
              otherUserImage: userImageUrl,
            ),
          ),
        );
      }

      // Call the callback if provided
      if (widget.onChat != null) {
        widget.onChat!(matchUserId, userName);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: StreamBuilder<List<Match>>(
        stream: _matchesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data ?? [];
          if (matches.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No matches yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Keep swiping to find your perfect match!',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: matches.length,
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final match = matches[i];
              final matchUserId = match.userA == _currentUserId
                  ? match.userB
                  : match.userA;

              return FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  _getProfilePicture(matchUserId),
                  _getUserName(matchUserId),
                  _getUnreadCount(matchUserId),
                ]),
                builder: (context, futureSnapshot) {
                  if (futureSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Loading...'),
                      subtitle: Text(''),
                    );
                  }

                  final results =
                      futureSnapshot.data ?? ['', 'Unknown User', 0];
                  final profilePic = results[0] as String?;
                  final userName = results[1] as String;
                  final unreadCount = results[2] as int;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: _userDataService
                          .getMemoryImageFromBase64(profilePic),
                      backgroundColor: Colors.grey.shade200,
                      child: (profilePic == null || profilePic.isEmpty)
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    title: Text(userName),
                    subtitle: Text(
                      'Matched on ${match.timestamp.toDate().toLocal().toString().split(".").first}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _openChat(matchUserId),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
