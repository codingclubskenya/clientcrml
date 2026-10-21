import 'package:uuid/uuid.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final int targetRole;
  final DateTime? dueAt;
  final String status;
  final String? createdBy;
  final bool isSynced;

  TaskModel({
    String? id,
    required this.title,
    required this.description,
    required this.targetRole,
    this.dueAt,
    this.status = 'open',
    this.createdBy,
    this.isSynced = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'target_role': targetRole,
      'due_at': dueAt?.toIso8601String(),
      'status': status,
      'created_by': createdBy,
      'isSynced': isSynced,
    };
  }

  factory TaskModel.fromMap(Map<dynamic, dynamic> map) {
    return TaskModel(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      targetRole: _parseRole(map['target_role'] ?? map['targetRole']),
      dueAt: _parseDate(map['due_at'] ?? map['dueAt']),
      status: map['status'] ?? 'open',
      createdBy: map['created_by'] ?? map['createdBy'],
      isSynced: map['isSynced'] == true || map['isSynced'] == 1,
    );
  }

  static int _parseRole(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 2;
    }
    return 2;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
