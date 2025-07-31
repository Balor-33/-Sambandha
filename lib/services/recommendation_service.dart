import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_user_service.dart';
import '../model/recommendation_model.dart';
import 'dart:math' as math;

class RecommendationService {
  final FirebaseUserService _firebaseUserService = FirebaseUserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  static const String USER_INTERESTS_COLLECTION = 'user_interests';

  /// Get recommended users for the current user
  Future<List<RecommendedUser>> getRecommendedUsers({
    int limit = 20,
    List<String>? excludeUserIds,
  }) async {
    try {
      // Get current user's data
      final currentUserData = await _firebaseUserService.getUserInterests();
      if (currentUserData == null) {
        throw Exception('Current user data not found');
      }

      print('Current user data: ${currentUserData.keys}'); // Debug log

      // Create matching criteria from current user data
      final matchingCriteria = MatchingCriteria.fromUserData(currentUserData);

      // Get all potential matches from Firestore
      final potentialMatches = await _getPotentialMatches(
        matchingCriteria,
        limit: limit * 3, // Get more to have enough after filtering
        excludeUserIds: excludeUserIds,
      );

      print('Found ${potentialMatches.length} potential matches'); // Debug log

      // Calculate scores and filter matches
      final recommendedUsers = <RecommendedUser>[];

      for (final userData in potentialMatches) {
        final score = _calculateMatchScore(matchingCriteria, userData);

        print(
          'User: ${userData['name']}, Score: ${score.totalScore}',
        ); // Debug log

        // Only include users with positive scores (meaning they meet basic criteria)
        if (score.totalScore > 0) {
          final recommendedUser = RecommendedUser.fromMap(
            userData,
            score.totalScore,
            score.ageScore,
            score.genderScore,
            score.hobbyScore,
            score.relationScore,
          );
          recommendedUsers.add(recommendedUser);
        }
      }

      // Sort by match score (highest first) and limit results
      recommendedUsers.sort((a, b) => b.matchScore.compareTo(a.matchScore));

      print(
        'Final recommended users count: ${recommendedUsers.length}',
      ); // Debug log

      return recommendedUsers.take(limit).toList();
    } catch (e) {
      print('Error in getRecommendedUsers: $e'); // Debug log
      throw Exception('Failed to get recommended users: $e');
    }
  }

  /// Get potential matches from Firestore with basic filtering
  Future<List<Map<String, dynamic>>> _getPotentialMatches(
    MatchingCriteria criteria, {
    required int limit,
    List<String>? excludeUserIds,
  }) async {
    try {
      final currentUserId = _firebaseUserService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      print('Getting potential matches for user: $currentUserId'); // Debug log
      print('Criteria: $criteria'); // Debug log

      // Get all users except current user and excluded users
      Query query = _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .limit(limit);

      final snapshot = await query.get();
      final potentialMatches = <Map<String, dynamic>>[];

      print('Total users in database: ${snapshot.docs.length}'); // Debug log

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String? ?? data['uid'] as String?;

        // Skip current user and excluded users
        if (userId == currentUserId ||
            (excludeUserIds != null && excludeUserIds.contains(userId))) {
          continue;
        }

        // Skip users without required fields
        if (data['name'] == null ||
            data['age'] == null ||
            data['gender'] == null ||
            data['interests'] == null) {
          print(
            'Skipping user with missing required fields: $userId',
          ); // Debug log
          continue;
        }

        // Basic age filter (±4 years)
        final userAge = data['age'] as int? ?? 0;
        if (userAge == 0) {
          // Try to calculate age from birthdate if age is missing
          if (data['birthdate'] != null) {
            final birthdate = (data['birthdate'] as Timestamp).toDate();
            data['age'] = _calculateAge(birthdate);
          } else {
            continue; // Skip users without valid age
          }
        }

        if ((data['age'] - criteria.currentUserAge).abs() >
            criteria.maxAgeGap) {
          continue;
        }

        // Basic gender compatibility check
        final userGender = List<String>.from(data['gender'] ?? []);
        final userInterestedIn = List<String>.from(data['interests'] ?? []);

        if (userGender.isEmpty || userInterestedIn.isEmpty) {
          continue; // Skip users without gender/interest preferences
        }

        // Check if current user's gender matches what this user is interested in
        // AND if this user's gender matches what current user is interested in
        bool genderMatch = _checkGenderCompatibility(
          criteria.currentUserGender,
          criteria.currentUserInterestedIn,
          userGender,
          userInterestedIn,
        );

        if (!genderMatch) {
          continue;
        }

        // Ensure profilePicture field exists (even if null)
        if (!data.containsKey('profilePicture')) {
          data['profilePicture'] = null;
        }

        // Add distance if both users have location
        if (criteria.currentUserLocation != null && data['location'] != null) {
          final userLocation = data['location'] as GeoPoint;
          final distance = _calculateDistance(
            criteria.currentUserLocation!.latitude,
            criteria.currentUserLocation!.longitude,
            userLocation.latitude,
            userLocation.longitude,
          );
          data['distanceKm'] = distance;

          // Filter by distance preference if set
          if (criteria.maxDistanceKm != null &&
              distance > criteria.maxDistanceKm!) {
            continue;
          }
        }

        potentialMatches.add(data);
      }

      return potentialMatches;
    } catch (e) {
      print('Error in _getPotentialMatches: $e'); // Debug log
      throw Exception('Failed to get potential matches: $e');
    }
  }

  /// Check gender compatibility between two users
  bool _checkGenderCompatibility(
    List<String> currentUserGender,
    List<String> currentUserInterestedIn,
    List<String> otherUserGender,
    List<String> otherUserInterestedIn,
  ) {
    // Check if current user's gender is in other user's interested list
    bool currentUserGenderMatches = currentUserGender.any(
      (gender) => otherUserInterestedIn.contains(gender),
    );

    // Check if other user's gender is in current user's interested list
    bool otherUserGenderMatches = otherUserGender.any(
      (gender) => currentUserInterestedIn.contains(gender),
    );

    // Both conditions must be true for compatibility
    return currentUserGenderMatches && otherUserGenderMatches;
  }

  /// Calculate match score based on the algorithm
  MatchScore _calculateMatchScore(
    MatchingCriteria criteria,
    Map<String, dynamic> userData,
  ) {
    int ageScore = 0;
    int genderScore = 0;
    int hobbyScore = 0;
    int relationScore = 0;

    // 1. Age compatibility (±4 years) - Base requirement
    final userAge = userData['age'] as int? ?? 0;
    final ageDifference = (userAge - criteria.currentUserAge).abs();
    if (ageDifference <= criteria.maxAgeGap) {
      ageScore = 1; // Base compatibility score
    }

    // 2. Gender compatibility - Base requirement
    final userGender = List<String>.from(userData['gender'] ?? []);
    final userInterestedIn = List<String>.from(userData['interests'] ?? []);

    if (_checkGenderCompatibility(
      criteria.currentUserGender,
      criteria.currentUserInterestedIn,
      userGender,
      userInterestedIn,
    )) {
      genderScore = 1; // Base compatibility score
    }

    // 3. Hobby matching (2 points per matched hobby)
    final userHobbies = List<String>.from(userData['hobbies'] ?? []);
    final matchedHobbies = criteria.currentUserHobbies
        .where((hobby) => userHobbies.contains(hobby))
        .length;
    hobbyScore = matchedHobbies * 2;

    // 4. Target relation matching (4 points if matched)
    final userTargetRelation = userData['targetRelation'] as String? ?? '';
    if (userTargetRelation.isNotEmpty &&
        userTargetRelation == criteria.currentUserTargetRelation) {
      relationScore = 4;
    }

    // Total score (only if age and gender requirements are met)
    final totalScore = (ageScore > 0 && genderScore > 0)
        ? ageScore + genderScore + hobbyScore + relationScore
        : 0;

    return MatchScore(
      totalScore: totalScore,
      ageScore: ageScore,
      genderScore: genderScore,
      hobbyScore: hobbyScore,
      relationScore: relationScore,
    );
  }

  /// Calculate age from birthdate
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
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

  /// Create sample test data for debugging
  Future<void> createTestUsers() async {
    final testUsers = [
      {
        'userId': 'test1',
        'name': 'Emma Johnson',
        'age': 24,
        'gender': ['Female'],
        'interests': ['Male'],
        'hobbies': ['Photography', 'Travel', 'Reading'],
        'targetRelation': 'Long-term relationship',
        'profilePicture': null, // You can add base64 string here for testing
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'userId': 'test2',
        'name': 'Michael Chen',
        'age': 26,
        'gender': ['Male'],
        'interests': ['Female'],
        'hobbies': ['Music', 'Cooking', 'Travel'],
        'targetRelation': 'Casual dating',
        'profilePicture': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'userId': 'test3',
        'name': 'Sarah Williams',
        'age': 23,
        'gender': ['Female'],
        'interests': ['Male'],
        'hobbies': ['Fitness', 'Photography', 'Movies'],
        'targetRelation': 'Long-term relationship',
        'profilePicture': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final user in testUsers) {
      await _firestore
          .collection(USER_INTERESTS_COLLECTION)
          .doc(user['userId'] as String)
          .set(user, SetOptions(merge: true));
    }

    print('Test users created successfully!');
  }
}

/// Helper class for match score breakdown
class MatchScore {
  final int totalScore;
  final int ageScore;
  final int genderScore;
  final int hobbyScore;
  final int relationScore;

  MatchScore({
    required this.totalScore,
    required this.ageScore,
    required this.genderScore,
    required this.hobbyScore,
    required this.relationScore,
  });

  @override
  String toString() {
    return 'MatchScore{total: $totalScore, age: $ageScore, gender: $genderScore, hobby: $hobbyScore, relation: $relationScore}';
  }
}
