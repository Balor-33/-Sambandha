import 'package:cloud_firestore/cloud_firestore.dart';

class Match {
  final String matchId;
  final String userA;
  final String userB;
  final Timestamp timestamp;

  Match({
    required this.matchId,
    required this.userA,
    required this.userB,
    required this.timestamp,
  });

  factory Match.fromMap(Map<String, dynamic> map, String id) {
    return Match(
      matchId: id,
      userA: map['userA'] ?? '',
      userB: map['userB'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'userA': userA, 'userB': userB, 'timestamp': timestamp};
  }
}
