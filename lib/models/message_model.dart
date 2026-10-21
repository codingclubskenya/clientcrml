import 'package:uuid/uuid.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String recipientId;
  final String subject;
  final String body;
  final String? relatedSchoolId;
  final String? relatedTaskId;
  final bool isRead;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MessageModel({
    String? id,
    required this.senderId,
    required this.recipientId,
    required this.subject,
    required this.body,
    this.relatedSchoolId,
    this.relatedTaskId,
    this.isRead = false,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'subject': subject,
      'body': body,
      'related_school_id': relatedSchoolId,
      'related_task_id': relatedTaskId,
      'is_read': isRead,
      'isSynced': isSynced,
    };

    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    if (updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }

    return map;
  }

  factory MessageModel.fromMap(Map<dynamic, dynamic> map) {
    return MessageModel(
      id: map['id'],
      senderId: map['sender_id'] ?? map['senderId'] ?? '',
      recipientId: map['recipient_id'] ?? map['recipientId'] ?? '',
      subject: map['subject'] ?? '',
      body: map['body'] ?? '',
      relatedSchoolId: map['related_school_id'] ?? map['relatedSchoolId'],
      relatedTaskId: map['related_task_id'] ?? map['relatedTaskId'],
      isRead: map['is_read'] == true || map['is_read'] == 1 || map['isRead'] == true || map['isRead'] == 1,
      isSynced: map['isSynced'] == true || map['isSynced'] == 1,
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
