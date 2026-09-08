import 'package:uuid/uuid.dart';

class EventModel {
  final String id;
  final String name;
  final String? eventType;
  final String? organization;
  final String? venue;
  final String? region;
  final String? subregion;
  final DateTime? startAt;
  final DateTime? endAt;
  final int? expectedAttendance;
  final double? budget;
  final String? objectives;
  final List<dynamic> products;
  final String? notes;
  final String status;
  final String? createdBy;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventModel({
    String? id,
    required this.name,
    this.eventType,
    this.organization,
    this.venue,
    this.region,
    this.subregion,
    this.startAt,
    this.endAt,
    this.expectedAttendance,
    this.budget,
    this.objectives,
    this.products = const [],
    this.notes,
    this.status = 'scheduled',
    this.createdBy,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'event_type': eventType,
      'organization': organization,
      'venue': venue,
      'region': region,
      'subregion': subregion,
      'start_at': startAt?.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'expected_attendance': expectedAttendance,
      'budget': budget,
      'objectives': objectives,
      'products': products,
      'notes': notes,
      'status': status,
      'created_by': createdBy,
      'isSynced': isSynced,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? '',
      eventType: map['event_type']?.toString(),
      organization: map['organization']?.toString(),
      venue: map['venue']?.toString(),
      region: map['region']?.toString(),
      subregion: map['subregion']?.toString(),
      startAt:
          map['start_at'] != null
              ? DateTime.tryParse(map['start_at'].toString())
              : null,
      endAt:
          map['end_at'] != null
              ? DateTime.tryParse(map['end_at'].toString())
              : null,
      expectedAttendance:
          map['expected_attendance'] is int
              ? map['expected_attendance']
              : int.tryParse(map['expected_attendance']?.toString() ?? ''),
      budget:
          map['budget'] is num
              ? (map['budget'] as num).toDouble()
              : double.tryParse(map['budget']?.toString() ?? ''),
      objectives: map['objectives']?.toString(),
      products: map['products'] is List ? map['products'] : [],
      notes: map['notes']?.toString(),
      status: map['status']?.toString() ?? 'scheduled',
      createdBy: map['created_by']?.toString(),
      isSynced: map['isSynced'] == true,
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(map['updated_at'].toString())
              : null,
    );
  }

  EventModel copyWith({
    String? id,
    String? name,
    String? eventType,
    String? organization,
    String? venue,
    String? region,
    String? subregion,
    DateTime? startAt,
    DateTime? endAt,
    int? expectedAttendance,
    double? budget,
    String? objectives,
    List<dynamic>? products,
    String? notes,
    String? status,
    String? createdBy,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      eventType: eventType ?? this.eventType,
      organization: organization ?? this.organization,
      venue: venue ?? this.venue,
      region: region ?? this.region,
      subregion: subregion ?? this.subregion,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      expectedAttendance: expectedAttendance ?? this.expectedAttendance,
      budget: budget ?? this.budget,
      objectives: objectives ?? this.objectives,
      products: products ?? this.products,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == 'active' || status == 'in_progress';
  bool get isUpcoming =>
      status == 'scheduled' &&
      startAt != null &&
      startAt!.isAfter(DateTime.now());
  bool get isCompleted => status == 'completed' || status == 'cancelled';
}

class EventAssignmentModel {
  final String id;
  final String eventId;
  final String agentId;
  final String? assignedBy;
  final Map<String, dynamic> schedule;
  final List<dynamic> products;
  final List<dynamic> samples;
  final List<dynamic> marketingMaterials;
  final Map<String, dynamic> targets;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventAssignmentModel({
    String? id,
    required this.eventId,
    required this.agentId,
    this.assignedBy,
    this.schedule = const {},
    this.products = const [],
    this.samples = const [],
    this.marketingMaterials = const [],
    this.targets = const {},
    this.notes,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'agent_id': agentId,
      'assigned_by': assignedBy,
      'schedule': schedule,
      'products': products,
      'samples': samples,
      'marketing_materials': marketingMaterials,
      'targets': targets,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory EventAssignmentModel.fromMap(Map<String, dynamic> map) {
    return EventAssignmentModel(
      id: map['id']?.toString(),
      eventId: map['event_id']?.toString() ?? '',
      agentId: map['agent_id']?.toString() ?? '',
      assignedBy: map['assigned_by']?.toString(),
      schedule:
          map['schedule'] is Map
              ? Map<String, dynamic>.from(map['schedule'])
              : {},
      products: map['products'] is List ? map['products'] : [],
      samples: map['samples'] is List ? map['samples'] : [],
      marketingMaterials:
          map['marketing_materials'] is List ? map['marketing_materials'] : [],
      targets:
          map['targets'] is Map
              ? Map<String, dynamic>.from(map['targets'])
              : {},
      notes: map['notes']?.toString(),
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(map['updated_at'].toString())
              : null,
    );
  }
}

class EventLeadModel {
  final String id;
  final String eventId;
  final String? agentId;
  final String? leadName;
  final String? schoolId;
  final String? phone;
  final String? email;
  final List<dynamic> interestedProducts;
  final String? purchaseTimeline;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventLeadModel({
    String? id,
    required this.eventId,
    this.agentId,
    this.leadName,
    this.schoolId,
    this.phone,
    this.email,
    this.interestedProducts = const [],
    this.purchaseTimeline,
    this.notes,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'agent_id': agentId,
      'lead_name': leadName,
      'school_id': schoolId,
      'phone': phone,
      'email': email,
      'interested_products': interestedProducts,
      'purchase_timeline': purchaseTimeline,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory EventLeadModel.fromMap(Map<String, dynamic> map) {
    return EventLeadModel(
      id: map['id']?.toString(),
      eventId: map['event_id']?.toString() ?? '',
      agentId: map['agent_id']?.toString(),
      leadName: map['lead_name']?.toString(),
      schoolId: map['school_id']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      interestedProducts:
          map['interested_products'] is List ? map['interested_products'] : [],
      purchaseTimeline: map['purchase_timeline']?.toString(),
      notes: map['notes']?.toString(),
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(map['updated_at'].toString())
              : null,
    );
  }
}

class EventExpenseModel {
  final String id;
  final String eventId;
  final String? submittedBy;
  final String? expenseType;
  final double amount;
  final String currency;
  final String? receiptUrl;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventExpenseModel({
    String? id,
    required this.eventId,
    this.submittedBy,
    this.expenseType,
    this.amount = 0,
    this.currency = 'KES',
    this.receiptUrl,
    this.status = 'pending',
    this.approvedBy,
    this.approvedAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'submitted_by': submittedBy,
      'expense_type': expenseType,
      'amount': amount,
      'currency': currency,
      'receipt_url': receiptUrl,
      'status': status,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory EventExpenseModel.fromMap(Map<String, dynamic> map) {
    return EventExpenseModel(
      id: map['id']?.toString(),
      eventId: map['event_id']?.toString() ?? '',
      submittedBy: map['submitted_by']?.toString(),
      expenseType: map['expense_type']?.toString(),
      amount:
          map['amount'] is num
              ? (map['amount'] as num).toDouble()
              : double.tryParse(map['amount']?.toString() ?? '') ?? 0,
      currency: map['currency']?.toString() ?? 'KES',
      receiptUrl: map['receipt_url']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      approvedBy: map['approved_by']?.toString(),
      approvedAt:
          map['approved_at'] != null
              ? DateTime.tryParse(map['approved_at'].toString())
              : null,
      notes: map['notes']?.toString(),
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(map['updated_at'].toString())
              : null,
    );
  }
}

class EventReportModel {
  final String id;
  final String eventId;
  final String? createdBy;
  final String? summary;
  final int attendanceCount;
  final int visitorsCount;
  final int schoolsCount;
  final int qualifiedLeadsCount;
  final int ordersCount;
  final double revenue;
  final List<dynamic> photos;
  final List<dynamic> gpsLogs;
  final Map<String, dynamic> expensesSummary;
  final List<dynamic> productsSold;
  final String? challenges;
  final String? recommendations;
  final String? exportedPdfUrl;
  final String? exportedXlsxUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventReportModel({
    String? id,
    required this.eventId,
    this.createdBy,
    this.summary,
    this.attendanceCount = 0,
    this.visitorsCount = 0,
    this.schoolsCount = 0,
    this.qualifiedLeadsCount = 0,
    this.ordersCount = 0,
    this.revenue = 0,
    this.photos = const [],
    this.gpsLogs = const [],
    this.expensesSummary = const {},
    this.productsSold = const [],
    this.challenges,
    this.recommendations,
    this.exportedPdfUrl,
    this.exportedXlsxUrl,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'created_by': createdBy,
      'summary': summary,
      'attendance_count': attendanceCount,
      'visitors_count': visitorsCount,
      'schools_count': schoolsCount,
      'qualified_leads_count': qualifiedLeadsCount,
      'orders_count': ordersCount,
      'revenue': revenue,
      'photos': photos,
      'gps_logs': gpsLogs,
      'expenses_summary': expensesSummary,
      'products_sold': productsSold,
      'challenges': challenges,
      'recommendations': recommendations,
      'exported_pdf_url': exportedPdfUrl,
      'exported_xlsx_url': exportedXlsxUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory EventReportModel.fromMap(Map<String, dynamic> map) {
    return EventReportModel(
      id: map['id']?.toString(),
      eventId: map['event_id']?.toString() ?? '',
      createdBy: map['created_by']?.toString(),
      summary: map['summary']?.toString(),
      attendanceCount:
          map['attendance_count'] is int
              ? map['attendance_count']
              : int.tryParse(map['attendance_count']?.toString() ?? '') ?? 0,
      visitorsCount:
          map['visitors_count'] is int
              ? map['visitors_count']
              : int.tryParse(map['visitors_count']?.toString() ?? '') ?? 0,
      schoolsCount:
          map['schools_count'] is int
              ? map['schools_count']
              : int.tryParse(map['schools_count']?.toString() ?? '') ?? 0,
      qualifiedLeadsCount:
          map['qualified_leads_count'] is int
              ? map['qualified_leads_count']
              : int.tryParse(map['qualified_leads_count']?.toString() ?? '') ??
                  0,
      ordersCount:
          map['orders_count'] is int
              ? map['orders_count']
              : int.tryParse(map['orders_count']?.toString() ?? '') ?? 0,
      revenue:
          map['revenue'] is num
              ? (map['revenue'] as num).toDouble()
              : double.tryParse(map['revenue']?.toString() ?? '') ?? 0,
      photos: map['photos'] is List ? map['photos'] : [],
      gpsLogs: map['gps_logs'] is List ? map['gps_logs'] : [],
      expensesSummary:
          map['expenses_summary'] is Map
              ? Map<String, dynamic>.from(map['expenses_summary'])
              : {},
      productsSold: map['products_sold'] is List ? map['products_sold'] : [],
      challenges: map['challenges']?.toString(),
      recommendations: map['recommendations']?.toString(),
      exportedPdfUrl: map['exported_pdf_url']?.toString(),
      exportedXlsxUrl: map['exported_xlsx_url']?.toString(),
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(map['updated_at'].toString())
              : null,
    );
  }
}
