import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../model/user_action_model.dart';
import '../model/match_model.dart';

class FirebaseUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference for user interests
  static const String USER_INTERESTS_COLLECTION = 'user_interests';
  static const String USER_ACTIONS_COLLECTION = 'user_actions';
  static const String MATCHES_COLLECTION = 'matches';

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Calculate age from birthdate
  int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    // Check if birthday hasn't occurred this year yet
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  /// Update lastUpdated field on user profile
  Future<void> updateLastUpdated() async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');
    await _firestore.collection(USER_INTERESTS_COLLECTION).doc(uid).update({
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Get lastUpdated field for the current user
  Future<Timestamp?> getLastUpdated() async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');
    final doc = await _firestore
        .collection(USER_INTERESTS_COLLECTION)
        .doc(uid)
        .get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['lastUpdated'] as Timestamp?;
    }
    return null;
  }

  /// Reset pass actions for the current user (delete or mark as inactive)
  Future<void> resetPassActions() async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');
    final query = await _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('actorUserId', isEqualTo: uid)
        .where('actionType', isEqualTo: 'pass')
        .get();
    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }

  /// Save user interests and profile information
  Future<void> saveUserInterests({
    required String name,
    required List<String> gender,
    required List<String> interests,
    required DateTime birthdate,
    required List<String> hobbies,
    required String targetRelation,
    GeoPoint? location,
    int? distancePreference,
    String? aboutMe, // Added aboutMe parameter
    Map<String, dynamic>? additionalFields,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Calculate age dynamically from birthdate
      final calculatedAge = calculateAge(birthdate);

      final userInterestsData = {
        'userId': userId,
        'gender': gender,
        'interests': interests,
        'birthdate': Timestamp.fromDate(birthdate),
        'age': calculatedAge, // Store calculated age
        'hobbies': hobbies,
        'targetRelation': targetRelation,
        'location': location,
        'distancePreference': distancePreference,
        'name': name,
        'aboutMe': aboutMe, // Added aboutMe field
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(), // Track lastUpdated
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
    List<String>? gender,
    List<String>? interests,
    DateTime? birthdate,
    List<String>? hobbies,
    String? targetRelation,
    GeoPoint? location,
    int? distancePreference,
    String? occupation,
    String? bio,
    String? aboutMe, // Added aboutMe parameter
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
        'lastUpdated': FieldValue.serverTimestamp(), // Track lastUpdated
      };

      if (interests != null) updateData['interests'] = interests;
      if (birthdate != null) {
        updateData['birthdate'] = Timestamp.fromDate(birthdate);
        updateData['age'] = calculateAge(
          birthdate,
        ); // Recalculate age when birthdate changes
      }
      if (gender != null) updateData['gender'] = gender;
      if (hobbies != null) updateData['hobbies'] = hobbies;
      if (targetRelation != null) updateData['targetRelation'] = targetRelation;
      if (location != null) updateData['location'] = location;
      if (distancePreference != null)
        updateData['distancePreference'] = distancePreference;
      if (name != null) updateData['name'] = name;
      if (bio != null) updateData['bio'] = bio;
      if (aboutMe != null)
        updateData['aboutMe'] = aboutMe; // Added aboutMe handling
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

  /// Get user interests and profile information with current age
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
        final data = doc.data()!;

        // Update age if birthdate exists
        if (data['birthdate'] != null) {
          final birthdate = (data['birthdate'] as Timestamp).toDate();
          data['age'] = calculateAge(birthdate); // Always return current age
        }

        return data;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user interests: $e');
    }
  }

  /// Stream user interests for real-time updates with current age
  Stream<Map<String, dynamic>?> getUserInterestsStream([String? userId]) {
    final uid = userId ?? currentUserId;
    if (uid == null) {
      throw Exception('User ID not provided and user not authenticated');
    }

    return _firestore
        .collection(USER_INTERESTS_COLLECTION)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data()!;

            // Update age if birthdate exists
            if (data['birthdate'] != null) {
              final birthdate = (data['birthdate'] as Timestamp).toDate();
              data['age'] = calculateAge(
                birthdate,
              ); // Always return current age
            }

            return data;
          }
          return null;
        });
  }

  /// Update all users' ages based on their birthdates (maintenance function)
  Future<void> updateAllUsersAges() async {
    try {
      final snapshot = await _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .get();

      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['birthdate'] != null) {
          final birthdate = (data['birthdate'] as Timestamp).toDate();
          final currentAge = calculateAge(birthdate);

          // Only update if age has changed
          if (data['age'] != currentAge) {
            batch.update(doc.reference, {
              'age': currentAge,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update all users ages: $e');
    }
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
          // Update age if birthdate exists
          if (data['birthdate'] != null) {
            final birthdate = (data['birthdate'] as Timestamp).toDate();
            data['age'] = calculateAge(birthdate);
          }

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
          // Update age if birthdate exists
          if (data['birthdate'] != null) {
            final birthdate = (data['birthdate'] as Timestamp).toDate();
            data['age'] = calculateAge(birthdate);
          }

          users.add(data);
        }
      }

      return users;
    } catch (e) {
      throw Exception('Failed to get users by target relation: $e');
    }
  }

  /// Get users within distance range based on GeoPoint location
  Future<List<Map<String, dynamic>>> getUsersWithinDistance(
    GeoPoint userLocation,
    double maxDistanceKm, {
    int limit = 10,
    List<String>? excludeUserIds,
  }) async {
    try {
      // Note: This is a simplified implementation. For production, consider using
      // GeoFlutterFire or similar libraries for more efficient geo queries
      final snapshot = await _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .limit(limit * 3) // Get more to filter by distance
          .get();

      List<Map<String, dynamic>> users = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        // Exclude current user and specified user IDs
        if (userId != currentUserId &&
            (excludeUserIds == null || !excludeUserIds.contains(userId))) {
          // Check if user has location data
          if (data['location'] != null) {
            final userGeoPoint = data['location'] as GeoPoint;
            final distance = _calculateDistance(
              userLocation.latitude,
              userLocation.longitude,
              userGeoPoint.latitude,
              userGeoPoint.longitude,
            );

            if (distance <= maxDistanceKm) {
              // Update age if birthdate exists
              if (data['birthdate'] != null) {
                final birthdate = (data['birthdate'] as Timestamp).toDate();
                data['age'] = calculateAge(birthdate);
              }

              // Add distance to the data
              data['distanceKm'] = distance;
              users.add(data);
            }
          }
        }
      }

      // Sort by distance and limit results
      users.sort((a, b) => a['distanceKm'].compareTo(b['distanceKm']));
      return users.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get users within distance: $e');
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
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

  /// Check if two users have mutually liked each other
  Future<bool> checkMutualLike({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final query = await _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('actorUserId', isEqualTo: currentUserId)
        .where('targetUserId', isEqualTo: otherUserId)
        .where('actionType', isEqualTo: 'like')
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// Update match status for an action
  Future<void> updateMatchStatus({
    required String actionId,
    required bool status,
  }) async {
    await _firestore.collection(USER_ACTIONS_COLLECTION).doc(actionId).update({
      'matchStatus': status,
    });
  }

  /// Record a user action (like or pass) - Updated version
  Future<bool> recordUserAction({
    required String targetUserId,
    required String actionType,
  }) async {
    final actorUserId = currentUserId;
    if (actorUserId == null) throw Exception('User not authenticated');

    // Create the action document
    final actionRef = _firestore.collection(USER_ACTIONS_COLLECTION).doc();
    final userAction = UserAction(
      actionId: actionRef.id,
      actorUserId: actorUserId,
      targetUserId: targetUserId,
      actionType: actionType,
      timestamp: Timestamp.now(),
      matchStatus: false,
    );

    // For likes, check for mutual match
    if (actionType == 'like') {
      final mutualLike = await _checkForMatch(actorUserId, targetUserId);
      if (mutualLike) {
        // Update both actions as matches
        await _updateMatchStatusForOtherUserLike(actorUserId, targetUserId);
        await actionRef.set({...userAction.toMap(), 'matchStatus': true});
        await _createMatch(actorUserId, targetUserId);
        return true;
      }
    }

    await actionRef.set(userAction.toMap());
    return false;
  }

  /// Check if a match exists (i.e., both users liked each other)
  Future<bool> _checkForMatch(String actorUserId, String targetUserId) async {
    final query = await _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('actorUserId', isEqualTo: targetUserId)
        .where('targetUserId', isEqualTo: actorUserId)
        .where('actionType', isEqualTo: 'like')
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Update matchStatus for the other user's like action if a match is found
  Future<void> _updateMatchStatusForOtherUserLike(
    String actorUserId,
    String targetUserId,
  ) async {
    final query = await _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('actorUserId', isEqualTo: targetUserId)
        .where('targetUserId', isEqualTo: actorUserId)
        .where('actionType', isEqualTo: 'like')
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final docRef = query.docs.first.reference;
      await docRef.update({'matchStatus': true});
    }
  }

  /// Create a new match document in 'matches' collection
  Future<void> _createMatch(String userA, String userB) async {
    // Ensure consistent ordering for userA/userB
    final sorted = [userA, userB]..sort();
    final matchId = '${sorted[0]}_${sorted[1]}';
    final matchRef = _firestore.collection(MATCHES_COLLECTION).doc(matchId);
    final match = Match(
      matchId: matchId,
      userA: sorted[0],
      userB: sorted[1],
      timestamp: Timestamp.now(),
    );
    await matchRef.set(match.toMap());
  }

  /// Placeholder for triggering a match notification
  void _triggerMatchNotification(String userA, String userB) {
    // TODO: Integrate with notification system
    print('Match notification: $userA and $userB matched!');
  }

  /// Get all actions performed by the current user
  Future<List<UserAction>> getUserActions({String? userId}) async {
    final uid = userId ?? currentUserId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    final query = await _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('actorUserId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .get();
    return query.docs
        .map((doc) => UserAction.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get all actions where the current user is the target (for matches, etc.)
  Future<List<UserAction>> getActionsTargetingUser({String? userId}) async {
    final uid = userId ?? currentUserId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    final query = await _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('targetUserId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .get();
    return query.docs
        .map((doc) => UserAction.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Real-time stream of actions where the current user is the target (for matches, etc.)
  Stream<List<UserAction>> getActionsTargetingUserStream({String? userId}) {
    final uid = userId ?? currentUserId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('targetUserId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserAction.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get all matches for the current user
  Future<List<Match>> getMatchesForUser({String? userId}) async {
    final uid = userId ?? currentUserId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    final query = await _firestore
        .collection(MATCHES_COLLECTION)
        .where('userA', isEqualTo: uid)
        .get();
    final query2 = await _firestore
        .collection(MATCHES_COLLECTION)
        .where('userB', isEqualTo: uid)
        .get();
    final matches = [
      ...query.docs.map((doc) => Match.fromMap(doc.data(), doc.id)),
      ...query2.docs.map((doc) => Match.fromMap(doc.data(), doc.id)),
    ];
    return matches;
  }

  /// Check if two users have matched
  Future<bool> haveUsersMatched(String userA, String userB) async {
    final sorted = [userA, userB]..sort();
    final matchId = '${sorted[0]}_${sorted[1]}';
    final doc = await _firestore
        .collection(MATCHES_COLLECTION)
        .doc(matchId)
        .get();
    return doc.exists;
  }

  /// Get a user's profile picture (base64 string) by userId
  Future<String?> getUserProfilePicture(String userId) async {
    final doc = await _firestore
        .collection(USER_INTERESTS_COLLECTION)
        .doc(userId)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('profilePicture')) {
        return data['profilePicture'] as String?;
      }
    }
    return null;
  }

  /// Get all actions (like/pass) performed by the current user
  Future<List<UserAction>> getActionHistoryForCurrentUser() async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    final query = await _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('actorUserId', isEqualTo: uid)
        .get();
    return query.docs
        .map((doc) => UserAction.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get all actions (like/pass) where the current user is the target
  Future<List<UserAction>> getActionsTargetingCurrentUser() async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    final query = await _firestore
        .collection(USER_ACTIONS_COLLECTION)
        .where('targetUserId', isEqualTo: uid)
        .get();
    return query.docs
        .map((doc) => UserAction.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Reset any cached action filters (placeholder, if needed for stateful filtering)
  void resetActionFilters() {
    // No-op for now, but can be used to clear local caches if implemented
  }
}

// Updated Model class for type safety
class UserInterests {
  final String userId;
  final List<String> interests;
  final List<String> gender;
  final DateTime birthdate;
  final int age; // This will be calculated dynamically
  final List<String> hobbies;
  final String targetRelation;
  final GeoPoint? location;
  final int? distancePreference;
  final String? name;
  final String? aboutMe; // Added aboutMe field
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalFields;

  UserInterests({
    required this.userId,
    required this.gender,
    required this.interests,
    required this.birthdate,
    required this.age,
    required this.hobbies,
    required this.targetRelation,
    this.location,
    this.distancePreference,
    required this.name,
    this.aboutMe, // Added aboutMe parameter
    this.createdAt,
    this.updatedAt,
    this.additionalFields,
  });

  factory UserInterests.fromMap(Map<String, dynamic> map) {
    final birthdate = (map['birthdate'] as Timestamp).toDate();

    return UserInterests(
      userId: map['userId'] ?? '',
      gender: List<String>.from(map['gender'] ?? []),
      interests: List<String>.from(map['interests'] ?? []),
      birthdate: birthdate,
      age: _calculateAge(birthdate), // Always calculate current age
      hobbies: List<String>.from(map['hobbies'] ?? []),
      targetRelation: map['targetRelation'] ?? '',
      location: map['location'] as GeoPoint?,
      distancePreference: map['distancePreference'] as int?,
      name: map['name'],
      aboutMe: map['aboutMe'], // Added aboutMe mapping
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      additionalFields: map['additionalFields'],
    );
  }

  static int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'gender': gender,
      'interests': interests,
      'birthdate': Timestamp.fromDate(birthdate),
      'age': age, // Store current calculated age
      'hobbies': hobbies,
      'targetRelation': targetRelation,
      'location': location,
      'distancePreference': distancePreference,
      'name': name,
      'aboutMe': aboutMe, // Added aboutMe to map
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'additionalFields': additionalFields,
    };
  }
}
