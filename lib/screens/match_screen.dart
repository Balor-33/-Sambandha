import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sambandha/services/like_service.dart';

class MatchScreen extends StatefulWidget {
  @override
  _MatchScreenState createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final LikeService _likeService = LikeService();
  final String _userId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _matchedProfiles = [];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    final matches = await _likeService.getMatches(_userId);
    final userCollection = FirebaseFirestore.instance.collection('users');

    List<Map<String, dynamic>> matchedProfiles = [];

    for (String matchId in matches) {
      final doc = await userCollection.doc(matchId).get();
      if (doc.exists) {
        matchedProfiles.add({'id': doc.id, ...doc.data()!});
      }
    }

    setState(() {
      _matchedProfiles = matchedProfiles;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Your Matches")),
      body: _matchedProfiles.isEmpty
          ? Center(child: Text("No matches yet"))
          : ListView.builder(
              itemCount: _matchedProfiles.length,
              itemBuilder: (context, index) {
                final user = _matchedProfiles[index];
                return Card(
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(user['name'] ?? 'Unknown'),
                    subtitle: Text(user['bio'] ?? 'No bio available'),
                    // Optional: Add avatar if your users have image URLs
                    leading: user['imageUrl'] != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(user['imageUrl']),
                          )
                        : CircleAvatar(child: Icon(Icons.person)),
                  ),
                );
              },
            ),
    );
  }
}
