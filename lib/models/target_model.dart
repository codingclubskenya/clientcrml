import 'package:uuid/uuid.dart';

class TargetModel {
  final String id;
  final String scope; // regional, agent, business_advisor, sales_rep
  final String? regionId;
  final String? subRegion;
  final String? assignedTo;
  final String
  targetType; // product_sales, customer_visits, collections, new_customers, sample_distribution, consignment
  final String targetPeriod; // daily, weekly, monthly, quarterly, yearly, ytd
  final Map<String, dynamic> targetData;
  final DateTime createdAt;
  final DateTime updatedAt;

  TargetModel({
    String? id,
    required this.scope,
    this.regionId,
    this.subRegion,
    this.assignedTo,
    required this.targetType,
    required this.targetPeriod,
    Map<String, dynamic>? targetData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       targetData = targetData ?? const {},
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  TargetModel copyWith({
    String? id,
    String? scope,
    String? regionId,
    String? subRegion,
    String? assignedTo,
    String? targetType,
    String? targetPeriod,
    Map<String, dynamic>? targetData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TargetModel(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      regionId: regionId ?? this.regionId,
      subRegion: subRegion ?? this.subRegion,
      assignedTo: assignedTo ?? this.assignedTo,
      targetType: targetType ?? this.targetType,
      targetPeriod: targetPeriod ?? this.targetPeriod,
      targetData: targetData ?? this.targetData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'scope': scope,
      'target_type': targetType,
      'target_period': targetPeriod,
      'target_data': targetData,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    if (regionId != null) {
      map['region_id'] = regionId;
    }
    if (subRegion != null) {
      map['sub_region'] = subRegion;
    }
    if (assignedTo != null) {
      map['assigned_to'] = assignedTo;
    }

    return map;
  }

  factory TargetModel.fromMap(Map<dynamic, dynamic> map) {
    final targetData = map['target_data'];
    return TargetModel(
      id: map['id']?.toString(),
      scope: map['scope']?.toString() ?? 'regional',
      regionId: map['region_id']?.toString(),
      subRegion: map['sub_region']?.toString(),
      assignedTo: map['assigned_to']?.toString(),
      targetType: map['target_type']?.toString() ?? 'product_sales',
      targetPeriod: map['target_period']?.toString() ?? 'monthly',
      targetData:
          targetData is Map ? Map<String, dynamic>.from(targetData) : {},
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'TargetModel(scope: $scope, type: $targetType, period: $targetPeriod)';
  }
}
