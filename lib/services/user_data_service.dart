import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class UserDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user data from user_interests collection
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_interests')
          .doc(userId)
          .get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Get user name
  Future<String> getUserName(String userId) async {
    try {
      final userData = await getUserData(userId);
      return userData?['name'] ?? 'Unknown User';
    } catch (e) {
      print('Error getting user name: $e');
      return 'Unknown User';
    }
  }

  /// Get user profile picture as base64 string
  Future<String?> getUserProfilePicture(String userId) async {
    try {
      final userData = await getUserData(userId);
      return userData?['profilePicture'] as String?;
    } catch (e) {
      print('Error getting profile picture: $e');
      return null;
    }
  }

  /// Convert base64 string to MemoryImage for avatars
  MemoryImage? getMemoryImageFromBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;

    try {
      return MemoryImage(const Base64Decoder().convert(base64String));
    } catch (e) {
      print('Error decoding base64 image: $e');
      return null;
    }
  }

  /// Get user age from birthdate
  int? getUserAge(Map<String, dynamic>? userData) {
    if (userData == null || userData['birthdate'] == null) return null;

    try {
      final birthdate = (userData['birthdate'] as Timestamp).toDate();
      final now = DateTime.now();
      int age = now.year - birthdate.year;

      if (now.month < birthdate.month ||
          (now.month == birthdate.month && now.day < birthdate.day)) {
        age--;
      }

      return age;
    } catch (e) {
      print('Error calculating age: $e');
      return userData['age'] as int?;
    }
  }

  /// Get multiple users data efficiently
  Future<Map<String, Map<String, dynamic>>> getUsersData(
    List<String> userIds,
  ) async {
    Map<String, Map<String, dynamic>> usersData = {};

    try {
      // Use batch reading for efficiency
      for (String userId in userIds) {
        final userData = await getUserData(userId);
        if (userData != null) {
          usersData[userId] = userData;
        }
      }
    } catch (e) {
      print('Error getting users data: $e');
    }

    return usersData;
  }

  /// Stream user data for real-time updates
  Stream<Map<String, dynamic>?> getUserDataStream(String userId) {
    return _firestore
        .collection('user_interests')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }
}
