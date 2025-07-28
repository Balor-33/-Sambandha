import 'package:cloud_firestore/cloud_firestore.dart';

class LikeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> likeUser(String currentUserId, String likedUserId) async {
    final currentUserRef = _firestore.collection('likes').doc(currentUserId);
    final likedUserRef = _firestore.collection('likes').doc(likedUserId);

    // Add likedUserId to currentUserId's liked list
    await currentUserRef.set({
      'likedUsers': FieldValue.arrayUnion([likedUserId]),
    }, SetOptions(merge: true));

    // Check if likedUserId already liked currentUserId
    final likedUserSnapshot = await likedUserRef.get();
    final likedUserData = likedUserSnapshot.data();
    final likedUserLikes = likedUserData?['likedUsers'] ?? [];

    if (likedUserLikes.contains(currentUserId)) {
      // It's a match! Add each to matches
      await currentUserRef.set({
        'matches': FieldValue.arrayUnion([likedUserId]),
      }, SetOptions(merge: true));

      await likedUserRef.set({
        'matches': FieldValue.arrayUnion([currentUserId]),
      }, SetOptions(merge: true));
    }
  }

  Future<List<String>> getMatches(String userId) async {
    final snapshot = await _firestore.collection('likes').doc(userId).get();
    return List<String>.from(snapshot.data()?['matches'] ?? []);
  }

  Future<List<String>> getLikedUsers(String userId) async {
    final snapshot = await _firestore.collection('likes').doc(userId).get();
    return List<String>.from(snapshot.data()?['likedUsers'] ?? []);
  }
}
