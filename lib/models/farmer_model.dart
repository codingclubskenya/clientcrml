import 'package:uuid/uuid.dart';

class SchoolModel {
  final String id;
  final String name;
  final String phone;
  final String county;
  final List<String> focusAreas;
  final String? bookCategory;
  final String? dealerType;
  final String? shopCategory;
  final String? selectedProduct;
  final String? partnerSubtype;
  final String? competitorAnalysis;
  final String? schoolLevel;
  final String? designation;
  final int? projectedQuantity;
  final String? samplesToBeReturned;
  final List<String>? learningMaterials;
  final List<String>? bookPrograms;
  final String? institutionCategoryOther;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyMeters;
  final String? photoUrl;
  final String? photoPath;
  final String? capturedBy;
  final DateTime? capturedAt;
  final String? captureStatus;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? contactTitle;
  final String? feedback;
  final String? notes;
  final String? samplesLeft;
  final List<String>? sampleBooks;
  final String? sampleProofUrl;
  final String? sampleProofPath;
  final String? schoolOwnership;
  final String? schoolOwnershipOther;
  final int? schoolPopulation;
  final String? schoolLifecycleStatus;
  final String? engagementType;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SchoolModel({
    String? id,
    required this.name,
    required this.phone,
    required this.county,
    required this.focusAreas,
    this.bookCategory,
    this.dealerType,
    this.shopCategory,
    this.selectedProduct,
    this.partnerSubtype,
    this.competitorAnalysis,
    this.schoolLevel,
    this.designation,
    this.projectedQuantity,
    this.samplesToBeReturned,
    this.learningMaterials,
    this.bookPrograms,
    this.institutionCategoryOther,
    this.latitude,
    this.longitude,
    this.gpsAccuracyMeters,
    this.photoUrl,
    this.photoPath,
    this.capturedBy,
    this.capturedAt,
    this.captureStatus,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.contactTitle,
    this.feedback,
    this.notes,
    this.samplesLeft,
    this.sampleBooks,
    this.sampleProofUrl,
    this.sampleProofPath,
    this.schoolOwnership,
    this.schoolOwnershipOther,
    this.schoolPopulation,
    this.schoolLifecycleStatus,
    this.engagementType,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'phone': phone,
      'county': county,
      'focusAreas': focusAreas,
      'book_category': bookCategory,
      'dealer_type': dealerType,
      'shop_category': shopCategory,
      'selected_product': selectedProduct,
      'partner_subtype': partnerSubtype,
      'competitor_analysis': competitorAnalysis,
      'school_level': schoolLevel,
      'designation': designation,
      'projected_quantity': projectedQuantity,
      'samples_to_be_returned': samplesToBeReturned,
      'learning_materials': learningMaterials,
      'book_programs': bookPrograms,
      'institution_category_other': institutionCategoryOther,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy_meters': gpsAccuracyMeters,
      'photo_url': photoUrl,
      'photo_path': photoPath,
      'captured_by': capturedBy,
      'captured_at': capturedAt?.toIso8601String(),
      'capture_status': captureStatus,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'contact_title': contactTitle,
      'feedback': feedback,
      'notes': notes,
      'samples_left': samplesLeft,
      'sample_books': sampleBooks?.join(','),
      'sample_proof_url': sampleProofUrl,
      'sample_proof_path': sampleProofPath,
      'school_ownership': schoolOwnership,
      'school_ownership_other': schoolOwnershipOther,
      'school_population': schoolPopulation,
      'school_lifecycle_status': schoolLifecycleStatus,
      'engagement_type': engagementType,
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

  factory SchoolModel.fromMap(Map<dynamic, dynamic> map) {
    return SchoolModel(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      county: map['county'],
      focusAreas: List<String>.from(map['focusAreas'] ?? const []),
      bookCategory: map['book_category'] ?? map['bookCategory'],
      dealerType: map['dealer_type'] ?? map['dealerType'],
      shopCategory: map['shop_category'] ?? map['shopCategory'],
      selectedProduct: map['selected_product'] ?? map['selectedProduct'],
      partnerSubtype: map['partner_subtype'] ?? map['partnerSubtype'],
      competitorAnalysis: map['competitor_analysis'],
      schoolLevel: map['school_level'],
      designation: map['designation'],
      projectedQuantity: _toInt(map['projected_quantity']),
      samplesToBeReturned: map['samples_to_be_returned'],
      learningMaterials:
          map['learning_materials'] is List
              ? List<String>.from(map['learning_materials'])
              : null,
      bookPrograms:
          map['book_programs'] is List
              ? List<String>.from(map['book_programs'])
              : null,
      institutionCategoryOther: map['institution_category_other'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      gpsAccuracyMeters: _parseDouble(
        map['gps_accuracy_meters'] ?? map['gpsAccuracyMeters'],
      ),
      photoUrl: map['photo_url'] ?? map['photoUrl'],
      photoPath: map['photo_path'] ?? map['photoPath'],
      capturedBy: map['captured_by'] ?? map['capturedBy'],
      capturedAt: _parseDate(map['captured_at'] ?? map['capturedAt']),
      captureStatus: map['capture_status'] ?? map['captureStatus'],
      contactName: map['contact_name'] ?? map['contactName'],
      contactPhone: map['contact_phone'] ?? map['contactPhone'],
      contactEmail: map['contact_email'] ?? map['contactEmail'],
      contactTitle: map['contact_title'] ?? map['contactTitle'],
      feedback: map['feedback'],
      notes: map['notes'],
      samplesLeft: map['samples_left'] ?? map['samplesLeft'],
      sampleBooks: (map['sample_books'] ?? map['sampleBook'])?.toString().split(
        ',',
      ),
      sampleProofUrl: map['sample_proof_url'] ?? map['sampleProofUrl'],
      sampleProofPath: map['sample_proof_path'] ?? map['sampleProofPath'],
      schoolOwnership: map['school_ownership'] ?? map['schoolOwnership'],
      schoolOwnershipOther:
          map['school_ownership_other'] ?? map['schoolOwnershipOther'],
      schoolPopulation: (map['school_population'] as num?)?.toInt(),
      schoolLifecycleStatus:
          map['school_lifecycle_status'] ?? map['schoolLifecycleStatus'],
      engagementType: map['engagement_type'] ?? map['engagementType'],
      isSynced: map['isSynced'] ?? map['is_synced'] ?? false,
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

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  SchoolModel copyWithSynced(bool value) {
    return SchoolModel(
      id: id,
      name: name,
      phone: phone,
      county: county,
      focusAreas: focusAreas,
      bookCategory: bookCategory,
      dealerType: dealerType,
      shopCategory: shopCategory,
      selectedProduct: selectedProduct,
      partnerSubtype: partnerSubtype,
      competitorAnalysis: competitorAnalysis,
      schoolLevel: schoolLevel,
      designation: designation,
      projectedQuantity: projectedQuantity,
      samplesToBeReturned: samplesToBeReturned,
      learningMaterials: learningMaterials,
      bookPrograms: bookPrograms,
      institutionCategoryOther: institutionCategoryOther,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracyMeters: gpsAccuracyMeters,
      photoUrl: photoUrl,
      photoPath: photoPath,
      capturedBy: capturedBy,
      capturedAt: capturedAt,
      captureStatus: captureStatus,
      contactName: contactName,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      contactTitle: contactTitle,
      feedback: feedback,
      notes: notes,
      samplesLeft: samplesLeft,
      sampleBooks: sampleBooks,
      sampleProofUrl: sampleProofUrl,
      sampleProofPath: sampleProofPath,
      schoolOwnership: schoolOwnership,
      schoolOwnershipOther: schoolOwnershipOther,
      schoolPopulation: schoolPopulation,
      schoolLifecycleStatus: schoolLifecycleStatus,
      engagementType: engagementType,
      isSynced: value,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
