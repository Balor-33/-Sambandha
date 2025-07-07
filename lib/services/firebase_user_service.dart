import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference for user interests
  static const String USER_INTERESTS_COLLECTION = 'user_interests';

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Save user interests and profile information
  Future<void> saveUserInterests({
    required String name,
    required List<String> interests,
    required DateTime birthdate,
    required List<String> hobbies,
    required String targetRelation,
    String? location,

    Map<String, dynamic>? additionalFields,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final userInterestsData = {
        'userId': userId,
        'interests': interests,
        'birthdate': Timestamp.fromDate(birthdate),
        'hobbies': hobbies,
        'targetRelation': targetRelation,
        'location': location,
        'name': name,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...?additionalFields, // Spread additional fields if provided
      };

      await _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .doc(userId)
          .set(userInterestsData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save user interests: $e');
    }
  }

  /// Update specific user interest fields
  Future<void> updateUserInterests({
    String? name,
    List<String>? interests,
    DateTime? birthdate,
    List<String>? hobbies,
    String? targetRelation,
    String? location,
    String? occupation,
    String? bio,
    List<String>? languages,
    Map<String, dynamic>? additionalFields,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (interests != null) updateData['interests'] = interests;
      if (birthdate != null)
        updateData['birthdate'] = Timestamp.fromDate(birthdate);
      if (hobbies != null) updateData['hobbies'] = hobbies;
      if (targetRelation != null) updateData['targetRelation'] = targetRelation;
      if (location != null) updateData['location'] = location;
      if (occupation != null) updateData['occupation'] = occupation;
      if (bio != null) updateData['bio'] = bio;
      if (languages != null) updateData['languages'] = languages;
      if (additionalFields != null) updateData.addAll(additionalFields);

      await _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .doc(userId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update user interests: $e');
    }
  }

  /// Get user interests and profile information
  Future<Map<String, dynamic>?> getUserInterests([String? userId]) async {
    try {
      final uid = userId ?? currentUserId;
      if (uid == null) {
        throw Exception('User ID not provided and user not authenticated');
      }

      final doc = await _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .doc(uid)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user interests: $e');
    }
  }

  /// Stream user interests for real-time updates
  Stream<Map<String, dynamic>?> getUserInterestsStream([String? userId]) {
    final uid = userId ?? currentUserId;
    if (uid == null) {
      throw Exception('User ID not provided and user not authenticated');
    }

    return _firestore
        .collection(USER_INTERESTS_COLLECTION)
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists ? snapshot.data() : null);
  }

  /// Delete user interests
  Future<void> deleteUserInterests([String? userId]) async {
    try {
      final uid = userId ?? currentUserId;
      if (uid == null) {
        throw Exception('User ID not provided and user not authenticated');
      }

      await _firestore.collection(USER_INTERESTS_COLLECTION).doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user interests: $e');
    }
  }

  /// Check if user interests exist
  Future<bool> userInterestsExist([String? userId]) async {
    try {
      final uid = userId ?? currentUserId;
      if (uid == null) {
        throw Exception('User ID not provided and user not authenticated');
      }

      final doc = await _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .doc(uid)
          .get();

      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check user interests existence: $e');
    }
  }

  /// Get users by interests (for matching purposes)
  Future<List<Map<String, dynamic>>> getUsersByInterests(
    List<String> interests, {
    int limit = 10,
    List<String>? excludeUserIds,
  }) async {
    try {
      Query query = _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .where('interests', arrayContainsAny: interests)
          .limit(limit);

      final snapshot = await query.get();
      List<Map<String, dynamic>> users = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String?;

        // Exclude current user and specified user IDs
        if (userId != currentUserId &&
            (excludeUserIds == null || !excludeUserIds.contains(userId))) {
          users.add(data);
        }
      }

      return users;
    } catch (e) {
      throw Exception('Failed to get users by interests: $e');
    }
  }

  /// Get users by target relation
  Future<List<Map<String, dynamic>>> getUsersByTargetRelation(
    String targetRelation, {
    int limit = 10,
    List<String>? excludeUserIds,
  }) async {
    try {
      Query query = _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .where('targetRelation', isEqualTo: targetRelation)
          .limit(limit);

      final snapshot = await query.get();
      List<Map<String, dynamic>> users = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String?;

        // Exclude current user and specified user IDs
        if (userId != currentUserId &&
            (excludeUserIds == null || !excludeUserIds.contains(userId))) {
          users.add(data);
        }
      }

      return users;
    } catch (e) {
      throw Exception('Failed to get users by target relation: $e');
    }
  }

  /// Batch operations for multiple users
  Future<void> batchUpdateUserInterests(
    List<Map<String, dynamic>> updates,
  ) async {
    try {
      final batch = _firestore.batch();

      for (var update in updates) {
        final userId = update['userId'] as String?;
        if (userId == null) continue;

        final docRef = _firestore
            .collection(USER_INTERESTS_COLLECTION)
            .doc(userId);

        update['updatedAt'] = FieldValue.serverTimestamp();
        batch.update(docRef, update);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to batch update user interests: $e');
    }
  }
}

// Model class for type safety
class UserInterests {
  final String userId;
  final List<String> interests;
  final DateTime birthdate;
  final List<String> hobbies;
  final String targetRelation;
  final String? location;
  final String? name;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalFields;

  UserInterests({
    required this.userId,
    required this.interests,
    required this.birthdate,
    required this.hobbies,
    required this.targetRelation,
    this.location,
    required this.name,

    this.createdAt,
    this.updatedAt,
    this.additionalFields,
  });

  factory UserInterests.fromMap(Map<String, dynamic> map) {
    return UserInterests(
      userId: map['userId'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      birthdate: (map['birthdate'] as Timestamp).toDate(),
      hobbies: List<String>.from(map['hobbies'] ?? []),
      targetRelation: map['targetRelation'] ?? '',
      location: map['location'],
      name: map['name'],

      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      additionalFields: map['additionalFields'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'interests': interests,
      'birthdate': Timestamp.fromDate(birthdate),
      'hobbies': hobbies,
      'targetRelation': targetRelation,
      'location': location,
      'name': name,

      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'additionalFields': additionalFields,
    };
  }
}
