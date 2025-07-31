import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_user_service.dart';
import '../model/match_model.dart';
import 'dart:convert';

class MatchesScreen extends StatefulWidget {
  final void Function(String matchUserId, String matchUserName)? onChat;
  const MatchesScreen({Key? key, this.onChat}) : super(key: key);

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final FirebaseUserService _userService = FirebaseUserService();
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

  // Placeholder for unread message count (replace with real logic)
  Future<int> _getUnreadCount(String matchUserId) async {
    // TODO: Integrate with chat/message service
    return 0;
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
              child: Text('No matches yet', style: TextStyle(fontSize: 18)),
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
              return FutureBuilder<String?>(
                future: _getProfilePicture(matchUserId),
                builder: (context, picSnapshot) {
                  final profilePic = picSnapshot.data;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          (profilePic != null && profilePic.isNotEmpty)
                          ? MemoryImage(
                              const Base64Decoder().convert(profilePic),
                            )
                          : null,
                      backgroundColor: Colors.grey.shade200,
                      child: (profilePic == null || profilePic.isEmpty)
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    title: Text('Match with ${matchUserId.substring(0, 8)}'),
                    subtitle: Text(
                      'Matched on ${match.timestamp.toDate().toLocal().toString().split(".").first}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: FutureBuilder<int>(
                      future: _getUnreadCount(matchUserId),
                      builder: (context, unreadSnapshot) {
                        final unread = unreadSnapshot.data ?? 0;
                        return unread > 0
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
                                  '$unread',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                    onTap: () {
                      if (widget.onChat != null) {
                        widget.onChat!(matchUserId, '');
                      }
                      // TODO: Navigate to chat screen with matchUserId
                    },
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
