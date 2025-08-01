import 'package:cloud_firestore/cloud_firestore.dart';

class UserAction {
  final String actionId;
  final String actorUserId;
  final String targetUserId;
  final String actionType; // 'like' or 'pass'
  final Timestamp timestamp;
  final bool matchStatus;

  UserAction({
    required this.actionId,
    required this.actorUserId,
    required this.targetUserId,
    required this.actionType,
    required this.timestamp,
    this.matchStatus = false,
  });

  factory UserAction.fromMap(Map<String, dynamic> map, String id) {
    return UserAction(
      actionId: id,
      actorUserId: map['actorUserId'] ?? '',
      targetUserId: map['targetUserId'] ?? '',
      actionType: map['actionType'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      matchStatus: map['matchStatus'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorUserId': actorUserId,
      'targetUserId': targetUserId,
      'actionType': actionType,
      'timestamp': timestamp,
      'matchStatus': matchStatus,
    };
  }
}
