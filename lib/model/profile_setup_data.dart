import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileSetupData {
  String? firstName;
  String? gender; // "Male" | "Female"
  DateTime? birthDate; // stored as DateTime
  String? interest; // "Women" | "Men"
  List<String>? hobbies;
  String? relationshipTarget;
  int? distancePreference;
  GeoPoint? currentLocation;

  ProfileSetupData({
    this.firstName,
    this.gender,
    this.birthDate,
    this.interest,
    this.hobbies,
    this.distancePreference,
    this.relationshipTarget,
    this.currentLocation,
  });

  // Helper method to get age from birthDate
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  @override
  String toString() {
    return 'ProfileSetupData{firstName: $firstName, gender: $gender, birthDate: $birthDate, age: $age, interest: $interest, hobbies: $hobbies, distancePreference: $distancePreference, relationshipTarget: $relationshipTarget}';
  }
}
