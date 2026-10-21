import 'package:uuid/uuid.dart';

import 'pipeline_stage.dart';

class SchoolSaleModel {
  final String id;
  final String schoolId;
  final String? agentId;
  final String? regionId;
  final String packageName;
  final double expectedValue;
  final String? notes;
  final PipelineStage stage;
  final DateTime? stageUpdatedAt;
  final DateTime? expectedCloseDate;
  final int probability;
  final DateTime? closedAt;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SchoolSaleModel({
    String? id,
    required this.schoolId,
    this.agentId,
    this.regionId,
    required this.packageName,
    required this.expectedValue,
    this.notes,
    this.stage = PipelineStage.lead,
    this.stageUpdatedAt,
    this.expectedCloseDate,
    this.probability = 0,
    this.closedAt,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'school_id': schoolId,
      'agent_id': agentId,
      'package_name': packageName,
      'expected_value': expectedValue,
      'notes': notes,
      'sale_status': stage.dbValue,
      'stage_updated_at': stageUpdatedAt?.toIso8601String(),
      'expected_close_date': expectedCloseDate?.toIso8601String(),
      'probability': probability,
      'closed_at': closedAt?.toIso8601String(),
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

  factory SchoolSaleModel.fromMap(Map<dynamic, dynamic> map) {
    return SchoolSaleModel(
      id: map['id'],
      schoolId: map['school_id'] ?? map['schoolId'] ?? '',
      agentId: map['agent_id'] ?? map['agentId'],
      regionId: map['region_id'] ?? map['regionId'],
      packageName: map['package_name'] ?? map['packageName'] ?? '',
      expectedValue: _toDouble(map['expected_value'] ?? map['expectedValue']),
      notes: map['notes'],
      stage: pipelineStageFromDb(map['sale_status'] ?? map['saleStatus']),
      stageUpdatedAt: _parseDate(
        map['stage_updated_at'] ?? map['stageUpdatedAt'],
      ),
      expectedCloseDate: _parseDate(
        map['expected_close_date'] ?? map['expectedCloseDate'],
      ),
      probability: _toInt(map['probability']),
      closedAt: _parseDate(map['closed_at'] ?? map['closedAt']),
      isSynced: map['isSynced'] == true || map['isSynced'] == 1 || map['is_synced'] == 1,
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

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
