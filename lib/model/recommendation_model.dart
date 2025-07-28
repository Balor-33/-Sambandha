import 'package:cloud_firestore/cloud_firestore.dart';

class RecommendedUser {
  final String userId;
  final String name;
  final int age;
  final List<String> gender;
  final List<String> interests;
  final List<String> hobbies;
  final String targetRelation;
  final GeoPoint? location;
  final int? distancePreference;
  final String? aboutMe;
  final String? profilePicture; // x64 encoded image
  final double? distanceKm;
  final int matchScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Breakdown of score calculation for debugging
  final int ageCompatibilityScore;
  final int genderCompatibilityScore;
  final int hobbyMatchScore;
  final int targetRelationScore;

  RecommendedUser({
    required this.userId,
    required this.name,
    required this.age,
    required this.gender,
    required this.interests,
    required this.hobbies,
    required this.targetRelation,
    this.location,
    this.distancePreference,
    this.aboutMe,
    this.profilePicture,
    this.distanceKm,
    required this.matchScore,
    this.createdAt,
    this.updatedAt,
    required this.ageCompatibilityScore,
    required this.genderCompatibilityScore,
    required this.hobbyMatchScore,
    required this.targetRelationScore,
  });

  factory RecommendedUser.fromMap(
    Map<String, dynamic> map,
    int matchScore,
    int ageScore,
    int genderScore,
    int hobbyScore,
    int relationScore,
  ) {
    final birthdate = map['birthdate'] != null
        ? (map['birthdate'] as Timestamp).toDate()
        : null;

    return RecommendedUser(
      userId: map['userId'] ?? '',
      name: map['name'] ?? 'Unknown',
      age: map['age'] ?? (birthdate != null ? _calculateAge(birthdate) : 0),
      gender: List<String>.from(map['gender'] ?? []),
      interests: List<String>.from(map['interests'] ?? []),
      hobbies: List<String>.from(map['hobbies'] ?? []),
      targetRelation: map['targetRelation'] ?? '',
      location: map['location'] as GeoPoint?,
      distancePreference: map['distancePreference'] as int?,
      aboutMe: map['aboutMe'] as String?,
      profilePicture: map['profilePicture'] as String?,
      distanceKm: map['distanceKm'] as double?,
      matchScore: matchScore,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      ageCompatibilityScore: ageScore,
      genderCompatibilityScore: genderScore,
      hobbyMatchScore: hobbyScore,
      targetRelationScore: relationScore,
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
      'name': name,
      'age': age,
      'gender': gender,
      'interests': interests,
      'hobbies': hobbies,
      'targetRelation': targetRelation,
      'location': location,
      'distancePreference': distancePreference,
      'aboutMe': aboutMe,
      'profilePicture': profilePicture,
      'distanceKm': distanceKm,
      'matchScore': matchScore,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'ageCompatibilityScore': ageCompatibilityScore,
      'genderCompatibilityScore': genderCompatibilityScore,
      'hobbyMatchScore': hobbyMatchScore,
      'targetRelationScore': targetRelationScore,
    };
  }

  @override
  String toString() {
    return 'RecommendedUser{userId: $userId, name: $name, age: $age, matchScore: $matchScore, ageScore: $ageCompatibilityScore, genderScore: $genderCompatibilityScore, hobbyScore: $hobbyMatchScore, relationScore: $targetRelationScore}';
  }
}

class MatchingCriteria {
  final int currentUserAge;
  final List<String> currentUserGender;
  final List<String>
  currentUserInterestedIn; // What gender user is interested in
  final List<String> currentUserHobbies;
  final String currentUserTargetRelation;
  final GeoPoint? currentUserLocation;
  final int? maxDistanceKm;
  final int maxAgeGap;

  MatchingCriteria({
    required this.currentUserAge,
    required this.currentUserGender,
    required this.currentUserInterestedIn,
    required this.currentUserHobbies,
    required this.currentUserTargetRelation,
    this.currentUserLocation,
    this.maxDistanceKm,
    this.maxAgeGap = 4, // Default ±4 years
  });

  factory MatchingCriteria.fromUserData(Map<String, dynamic> userData) {
    final birthdate = userData['birthdate'] != null
        ? (userData['birthdate'] as Timestamp).toDate()
        : null;

    return MatchingCriteria(
      currentUserAge:
          userData['age'] ?? (birthdate != null ? _calculateAge(birthdate) : 0),
      currentUserGender: List<String>.from(userData['gender'] ?? []),
      currentUserInterestedIn: List<String>.from(userData['interests'] ?? []),
      currentUserHobbies: List<String>.from(userData['hobbies'] ?? []),
      currentUserTargetRelation: userData['targetRelation'] ?? '',
      currentUserLocation: userData['location'] as GeoPoint?,
      maxDistanceKm: userData['distancePreference'] as int?,
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

  @override
  String toString() {
    return 'MatchingCriteria{currentUserAge: $currentUserAge, currentUserGender: $currentUserGender, currentUserInterestedIn: $currentUserInterestedIn, currentUserHobbies: $currentUserHobbies, currentUserTargetRelation: $currentUserTargetRelation, maxAgeGap: $maxAgeGap}';
  }
}
