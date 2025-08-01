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
  final UserDataService _userDataService = UserDataService();
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final chatId = await _chatService.createOrGetChat(matchUserId);
      final userName = await _getUserName(matchUserId);
      final userImageUrl = await _getUserImageUrl(matchUserId);

      if (mounted) Navigator.pop(context);

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

      if (widget.onChat != null) {
        widget.onChat!(matchUserId, userName);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: screenWidth * 0.16,
                    color: Colors.grey,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    'No matches yet',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'Keep swiping to find your perfect match!',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.02,
            ),
            itemCount: matches.length,
            separatorBuilder: (context, i) =>
                Divider(height: screenHeight * 0.01),
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
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey,
                        radius: screenWidth * 0.07,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Loading...'),
                      subtitle: const Text(''),
                    );
                  }

                  final results =
                      futureSnapshot.data ?? ['', 'Unknown User', 0];
                  final profilePic = results[0] as String?;
                  final userName = results[1] as String;
                  final unreadCount = results[2] as int;

                  return ListTile(
                    leading: CircleAvatar(
                      radius: screenWidth * 0.07,
                      backgroundImage: _userDataService
                          .getMemoryImageFromBase64(profilePic),
                      backgroundColor: Colors.grey.shade200,
                      child: (profilePic == null || profilePic.isEmpty)
                          ? Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: screenWidth * 0.07,
                            )
                          : null,
                    ),
                    title: Text(
                      userName,
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.w600,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    subtitle: Text(
                      'Matched on ${match.timestamp.toDate().toLocal().toString().split(".").first}',
                      style: TextStyle(fontSize: screenWidth * 0.035),
                    ),
                    trailing: unreadCount > 0
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.025,
                              vertical: screenHeight * 0.005,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.04,
                              ),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: screenWidth * 0.07,
                          ),
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
