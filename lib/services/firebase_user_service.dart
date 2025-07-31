import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../model/user_action_model.dart';
import '../model/match_model.dart';

class FirebaseUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection names
  static const String USER_ACTIONS_COLLECTION = 'user_actions';
  static const String MATCHES_COLLECTION = 'matches';
  static const String USER_INTERESTS_COLLECTION = 'user_interests';

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
    String? aboutMe,
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
        'age': calculatedAge,
        'hobbies': hobbies,
        'targetRelation': targetRelation,
        'location': location,
        'distancePreference': distancePreference,
        'name': name,
        'aboutMe': aboutMe,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        ...?additionalFields,
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
    String? aboutMe,
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
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (interests != null) updateData['interests'] = interests;
      if (birthdate != null) {
        updateData['birthdate'] = Timestamp.fromDate(birthdate);
        updateData['age'] = calculateAge(birthdate);
      }
      if (gender != null) updateData['gender'] = gender;
      if (hobbies != null) updateData['hobbies'] = hobbies;
      if (targetRelation != null) updateData['targetRelation'] = targetRelation;
      if (location != null) updateData['location'] = location;
      if (distancePreference != null)
        updateData['distancePreference'] = distancePreference;
      if (name != null) updateData['name'] = name;
      if (bio != null) updateData['bio'] = bio;
      if (aboutMe != null) updateData['aboutMe'] = aboutMe;
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
          data['age'] = calculateAge(birthdate);
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
              data['age'] = calculateAge(birthdate);
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
      final snapshot = await _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .limit(limit * 3)
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

  Future<bool> recordUserAction({
    required String targetUserId,
    required String actionType,
  }) async {
    try {
      final actorUserId = currentUserId;
      if (actorUserId == null) throw Exception('User not authenticated');

      print('Recording $actionType action from $actorUserId to $targetUserId');

      // Use transaction to ensure atomicity
      bool matchCreated = false;
      String? matchedUserId;
      
      final result = await _firestore.runTransaction<bool>((transaction) async {
        // Check for existing action to prevent duplicates
        final existingQuery = await transaction.get(_firestore
            .collection(USER_ACTIONS_COLLECTION)
            .where('actorUserId', isEqualTo: actorUserId)
            .where('targetUserId', isEqualTo: targetUserId)
            .limit(1));

        DocumentReference actionRef;
        bool isExistingAction = existingQuery.docs.isNotEmpty;

        // Handle existing or new action
        if (isExistingAction) {
          actionRef = existingQuery.docs.first.reference;
          final existingData = existingQuery.docs.first.data();

          // If action already exists with same type, return its match status
          if (existingData['actionType'] == actionType) {
            return existingData['matchStatus'] ?? false;
          }

          // Update existing action if it's a different type
          transaction.update(actionRef, {
            'actionType': actionType,
            'timestamp': FieldValue.serverTimestamp(),
            'matchStatus': false, // Reset match status for new action type
          });
        } else {
          // Create new action document
          actionRef = _firestore.collection(USER_ACTIONS_COLLECTION).doc();
          transaction.set(actionRef, {
            'actionId': actionRef.id,
            'actorUserId': actorUserId,
            'targetUserId': targetUserId,
            'actionType': actionType,
            'timestamp': FieldValue.serverTimestamp(),
            'matchStatus': false,
          });
        }

        // For like actions, check for reciprocal like
        if (actionType == 'like') {
          // Look for reciprocal like from the other user
          final reciprocalQuery = await transaction.get(_firestore
              .collection(USER_ACTIONS_COLLECTION)
              .where('actorUserId', isEqualTo: targetUserId)
              .where('targetUserId', isEqualTo: actorUserId)
              .where('actionType', isEqualTo: 'like')
              .where('matchStatus', isEqualTo: false)
              .limit(1));

          if (reciprocalQuery.docs.isNotEmpty) {
            print('Match found! Creating match and updating both documents...');
            
            // Update both like documents' matchStatus to true
            transaction.update(actionRef, {
              'matchStatus': true,
              'matchedAt': FieldValue.serverTimestamp(),
            });
            
            transaction.update(reciprocalQuery.docs.first.reference, {
              'matchStatus': true,
              'matchedAt': FieldValue.serverTimestamp(),
            });

            // Create match document
            final sortedIds = [actorUserId, targetUserId]..sort();
            final matchId = '${sortedIds[0]}_${sortedIds[1]}';
            final matchRef = _firestore.collection(MATCHES_COLLECTION).doc(matchId);

            transaction.set(matchRef, {
              'userA': sortedIds[0],
              'userB': sortedIds[1],
              'timestamp': FieldValue.serverTimestamp(),
              'isActive': true,
            });

            matchCreated = true;
            matchedUserId = targetUserId;
            return true; // Match created
          }
        }

        return false; // No match created
      });
      
      // Trigger notifications outside the transaction if a match was created
      if (result && matchCreated && matchedUserId != null) {
        _triggerMatchNotification(actorUserId, matchedUserId!);
        _triggerMatchNotification(matchedUserId!, actorUserId);
      }
      
      return result;
    } catch (e) {
      print('Error in recordUserAction: $e');
      rethrow;
    }
  }

  /// Check if the other user has already liked current user (deprecated - now handled in transaction)
  @deprecated
  Future<bool> _checkForReciprocalLike({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      print('Checking for reciprocal like from $otherUserId to $currentUserId');

      // Look for likes from the other user to current user that aren't matched yet
      final query = await _firestore
          .collection(USER_ACTIONS_COLLECTION)
          .where('actorUserId', isEqualTo: otherUserId)
          .where('targetUserId', isEqualTo: currentUserId)
          .where('actionType', isEqualTo: 'like')
          .where('matchStatus', isEqualTo: false)
          .limit(1)
          .get();

      final hasReciprocalLike = query.docs.isNotEmpty;
      print('Reciprocal like exists: $hasReciprocalLike');

      if (hasReciprocalLike) {
        print('Found reciprocal like: ${query.docs.first.id}');
      }

      return hasReciprocalLike;
    } catch (e) {
      print('Error checking for reciprocal like: $e');
      return false;
    }
  }

  /// Handle match creation between two users (deprecated - now handled in transaction)
  @deprecated
  Future<void> _handleMatchCreation(String userA, String userB) async {
    try {
      print('Creating match between $userA and $userB');

      // Find both like actions (in either direction)
      final likeActionsQuery = await _firestore
          .collection(USER_ACTIONS_COLLECTION)
          .where('actorUserId', whereIn: [userA, userB])
          .where('targetUserId', whereIn: [userA, userB])
          .where('actionType', isEqualTo: 'like')
          .where('matchStatus', isEqualTo: false)
          .get();

      if (likeActionsQuery.docs.length < 2) {
        print('Not enough like actions found for match creation');
        return;
      }

      // Use batch for atomic operations
      final batch = _firestore.batch();

      // Update all found actions to matched status
      for (final doc in likeActionsQuery.docs) {
        batch.update(doc.reference, {
          'matchStatus': true,
          'matchedAt': FieldValue.serverTimestamp(),
        });
      }

      // Create match document
      final sortedIds = [userA, userB]..sort();
      final matchId = '${sortedIds[0]}_${sortedIds[1]}';
      final matchRef = _firestore.collection(MATCHES_COLLECTION).doc(matchId);

      batch.set(matchRef, {
        'userA': sortedIds[0],
        'userB': sortedIds[1],
        'timestamp': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Execute batch
      print('Committing match batch...');
      await batch.commit();
      print('Match created successfully!');

      // Trigger notification for both users
      _triggerMatchNotification(userA, userB);
      _triggerMatchNotification(userB, userA);
    } catch (e) {
      print('Error in _handleMatchCreation: $e');
      rethrow;
    }
  }

  /// Placeholder for triggering a match notification
  void _triggerMatchNotification(String userA, String userB) {
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

  /// Real-time stream of actions where the current user is the target
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

  /// Reset any cached action filters
  void resetActionFilters() {
    // No-op for now, but can be used to clear local caches if implemented
  }
}
