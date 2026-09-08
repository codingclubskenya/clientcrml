import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../models/farmer_model.dart';
import 'client_type_selector.dart';

class SchoolOnboarding extends StatefulWidget {
  const SchoolOnboarding({super.key});

  @override
  State<SchoolOnboarding> createState() => _SchoolOnboardingState();
}

class _SchoolOnboardingState extends State<SchoolOnboarding> {
  static const double _gpsAccuracyThresholdMeters = 50.0;
  final DatabaseService _dbService = DatabaseService();
  int _currentStep = 0;

  // --- FORM STATE VARIABLES ---
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactTitleController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _schoolOwnershipOtherController =
      TextEditingController();
  final TextEditingController _institutionCategoryOtherController =
      TextEditingController();
  final TextEditingController _schoolPopulationController =
      TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _dealerType;
  String? _shopCategory;
  String? _selectedProduct;
  String? _selectedBookProgram;
  List<String> _selectedBookPrograms = [];
  String? _samplesLeft;
  List<String> _selectedSampleBooks = [];
  String? _selectedSampleCategory;
  List<String> _selectedLearningMaterials = [];
  String? _partnerSubtype;
  String? _samplesToBeReturned;
  String? _selectedCounty;
  String? _schoolOwnership;
  String? _schoolLifecycleStatus;
  String? _engagementType;
  List<String> _sampleBookOptions = <String>[];
  final Map<String, String> _sampleBookCategoryByLabel = <String, String>{};
  XFile? _capturedPhoto;
  Uint8List? _capturedPhotoBytes;
  XFile? _sampleProofPhoto;
  Uint8List? _sampleProofPhotoBytes;
  Position? _currentPosition;
  String? _captureStatus;
  String _sampleBookSearchQuery = '';
  bool isOffline = true;
  bool _isSubmitting = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  static const List<String> _crmPipelineStatusOptions = [
    'Lead',
    'Contacted',
    'Meeting Scheduled',
    'Sample Issued',
    'Quotation Sent',
    'Decision Pending',
    'Negotiation',
    'Won',
    'Lost',
    'Dormant',
  ];

  static const List<String> _counties = [
    'Mombasa',
    'Kwale',
    'Kilifi',
    'Tana River',
    'Lamu',
    'Taita-Taveta',
    'Garissa',
    'Wajir',
    'Mandera',
    'Marsabit',
    'Isiolo',
    'Meru',
    'Tharaka-Nithi',
    'Embu',
    'Kitui',
    'Machakos',
    'Makueni',
    'Nyandarua',
    'Nyeri',
    'Kirinyaga',
    'Murang\'a',
    'Kiambu',
    'Turkana',
    'West Pokot',
    'Samburu',
    'Trans Nzoia',
    'Uasin Gishu',
    'Elgeyo-Marakwet',
    'Nandi',
    'Baringo',
    'Laikipia',
    'Nakuru',
    'Narok',
    'Kajiado',
    'Kericho',
    'Bomet',
    'Kakamega',
    'Vihiga',
    'Bungoma',
    'Busia',
    'Siaya',
    'Kisumu',
    'Homa Bay',
    'Migori',
    'Kisii',
    'Nyamira',
    'Nairobi',
  ];

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _shopNameController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactTitleController.dispose();
    _contactEmailController.dispose();
    _feedbackController.dispose();
    _notesController.dispose();
    _schoolOwnershipOtherController.dispose();
    _institutionCategoryOtherController.dispose();
    _schoolPopulationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectClientType();
      _watchConnectivity();
      _fetchCurrentLocation();
      _loadSampleBooks();
    });
  }

  Future<void> _selectClientType() async {
    if (!mounted) return;
    final selected = await showClientTypeModal(context, includeAll: false);
    if (!mounted) return;
    if (selected == null) {
      if (_dealerType == null) {
        setState(() {});
      }
      return;
    }
    setState(() {
      _dealerType = selected.value;
      _shopCategory = null;
      _partnerSubtype = null;
      _selectedProduct = null;
      _selectedBookProgram = null;
    });
  }

  Future<void> _watchConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => isOffline = initial.contains(ConnectivityResult.none));

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() => isOffline = results.contains(ConnectivityResult.none));
    });
  }

  Future<void> _pickContactFromPhonebook() async {
    FocusScope.of(context).unfocus();

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final permission = await FlutterContacts.permissions.request(
          PermissionType.read,
        );
        if (permission != PermissionStatus.granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contacts permission is required to pick a phone number.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      if (!mounted || contact == null) return;
      if (contact.phones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected contact has no phone number.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final pickedName = contact.displayName?.trim() ?? '';
      final pickedPhone = contact.phones.first.number.trim();

      setState(() {
        if (_contactNameController.text.trim().isEmpty &&
            pickedName.isNotEmpty) {
          _contactNameController.text = pickedName;
        }
        _contactPhoneController.text = pickedPhone;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open contacts picker: ${e.message ?? e.code}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    final schoolName = _shopNameController.text.trim();
    final phone = _contactPhoneController.text.trim();
    final county = _selectedCounty?.trim() ?? '';
    final labelType = _dealerType ?? 'School';

    if (schoolName.isEmpty || phone.isEmpty || county.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter ${labelType.toLowerCase()} name, phone number, and county.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture GPS location before submitting onboarding.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_hasAccurateGps) {
      final currentAccuracy = _currentPosition!.accuracy.toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS accuracy is $currentAccuracy m. Improve to <= ${_gpsAccuracyThresholdMeters.toStringAsFixed(0)} m and try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final payload = _buildSubmissionPayload();
    final focusAreas = <String>[
      if (_shopCategory != null) _shopCategory!,
      if (_selectedProduct != null) _selectedProduct!,
      if (_partnerSubtype != null) _partnerSubtype!,
    ];
    if (focusAreas.isEmpty) {
      focusAreas.add('General');
    }
    final submissionAccuracy = _currentPosition!.accuracy;
    final submissionCaptureStatus =
        'GPS submitted (${submissionAccuracy.toStringAsFixed(1)}m accuracy)';

    setState(() => _isSubmitting = true);
    final uploadedPhoto = await _uploadSchoolPhoto();
    final uploadedSampleProof = await _uploadSampleProofPhoto();
    if (_samplesLeft == 'Yes' &&
        (uploadedSampleProof['proofUrl'] ?? '').trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not upload stamped sample proof photo. Please retake and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
      return;
    }

    final school = SchoolModel(
      name: schoolName,
      phone: phone,
      county: county,
      focusAreas: focusAreas,
      bookCategory: _selectedBookProgram,
      dealerType: _dealerType,
      shopCategory: _shopCategory,
      selectedProduct: _selectedProduct,
      partnerSubtype: _partnerSubtype,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      gpsAccuracyMeters: _currentPosition?.accuracy,
      photoUrl: uploadedPhoto['photoUrl'],
      photoPath: uploadedPhoto['photoPath'],
      captureStatus: submissionCaptureStatus,
      contactName:
          _contactNameController.text.trim().isEmpty
              ? null
              : _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      contactEmail:
          _contactEmailController.text.trim().isEmpty
              ? null
              : _contactEmailController.text.trim(),
      contactTitle:
          _contactTitleController.text.trim().isEmpty
              ? null
              : _contactTitleController.text.trim(),
      feedback:
          _feedbackController.text.trim().isEmpty
              ? null
              : _feedbackController.text.trim(),
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      samplesLeft: _samplesLeft,
      samplesToBeReturned: _samplesToBeReturned,
      sampleBooks: _selectedSampleBooks.isEmpty ? null : _selectedSampleBooks,
      learningMaterials:
          _selectedLearningMaterials.isEmpty
              ? null
              : _selectedLearningMaterials,
      bookPrograms:
          _selectedBookPrograms.isEmpty ? null : _selectedBookPrograms,
      institutionCategoryOther:
          _dealerType == 'Institution'
              ? _institutionCategoryOtherController.text.trim()
              : null,
      sampleProofUrl: uploadedSampleProof['proofUrl'],
      sampleProofPath: uploadedSampleProof['proofPath'],
      schoolOwnership: _schoolOwnership,
      schoolOwnershipOther:
          _schoolOwnership == 'Others'
              ? _schoolOwnershipOtherController.text.trim()
              : null,
      schoolPopulation: int.tryParse(_schoolPopulationController.text.trim()),
      schoolLifecycleStatus: _schoolLifecycleStatus,
      engagementType: _engagementType,
      capturedBy: _dbService.getCurrentUserId(),
      capturedAt: DateTime.now(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${_dealerType ?? "School"} onboarding collected with GPS accuracy ${submissionAccuracy.toStringAsFixed(1)}m",
        ),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(seconds: 1),
      ),
    );

    debugPrint('Onboarding payload: $payload');

    var syncedToDatabase = false;
    var syncMessage = '';
    try {
      final saveResult = await _dbService.saveSchoolProfileWithStatus(school);
      syncedToDatabase = saveResult.syncedToDatabase;
      syncMessage = saveResult.message;

      try {
        await _dbService.recordSchoolVisit(
          schoolId: school.id,
          agentId: _dbService.getCurrentUserId() ?? '',
          outcome: _engagementType,
          notes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
          visitStatus: 'completed',
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
          photoUrl: uploadedPhoto['photoUrl'],
          photoPath: uploadedPhoto['photoPath'],
        );
      } catch (e) {
        debugPrint('Could not record onboarding school visit: $e');
      }
      if (_samplesLeft == 'Yes' &&
          (uploadedSampleProof['proofUrl'] ?? '').trim().isNotEmpty &&
          _selectedSampleBooks.isNotEmpty) {
        try {
          for (final book in _selectedSampleBooks) {
            await _dbService.recordSampleDistribution(
              schoolId: school.id,
              sampleName: book.trim().isNotEmpty ? book.trim() : 'Sample Book',
              sampleCategory:
                  _selectedSampleCategory ??
                  _sampleBookCategoryByLabel[book] ??
                  'Onboarding',
              quantity: 1,
              notes: 'Captured during onboarding',
              stampedReceiptUrl: uploadedSampleProof['proofUrl'],
              stampedReceiptPath: uploadedSampleProof['proofPath'],
            );
          }
        } catch (e) {
          debugPrint('Could not create onboarding sample receipt row: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Saved ${_dealerType ?? "school"}, but could not save stamped receipt: $e',
                ),
                backgroundColor: Colors.orange.shade700,
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedToDatabase
                ? "${_dealerType ?? "School"} onboarded and synced to database."
                : syncMessage.isEmpty
                ? "${_dealerType ?? "School"} saved locally. Database sync pending."
                : syncMessage,
          ),
          backgroundColor:
              syncedToDatabase ? AppColors.primaryGreen : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    });
  }

  Future<void> _captureSchoolPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _capturedPhoto = photo;
        _capturedPhotoBytes = bytes;
        _captureStatus = "Photo captured successfully";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captureStatus = "Could not open the camera";
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _captureStatus = "Enable location services to capture GPS";
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _captureStatus = "Location permission is required";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      final accuracy = position.accuracy;
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        if (accuracy <= _gpsAccuracyThresholdMeters) {
          _captureStatus =
              "GPS updated successfully (${accuracy.toStringAsFixed(1)}m accuracy)";
        } else {
          _captureStatus =
              "GPS captured but accuracy is low (${accuracy.toStringAsFixed(1)}m). Move outside and refresh.";
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captureStatus = "Could not fetch the current location";
      });
    }
  }

  bool get _hasAccurateGps {
    final position = _currentPosition;
    if (position == null) return false;
    return position.accuracy <= _gpsAccuracyThresholdMeters;
  }

  @override
  Widget build(BuildContext context) {
    if (_dealerType == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Onboard Client')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.app_registration_outlined,
                    size: 36,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select a Client Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the type of client you want to onboard to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _selectClientType,
                  icon: const Icon(Icons.touch_app_outlined),
                  label: const Text('Choose Client Type'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Onboard ${_dealerType ?? 'School'}"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              isOffline ? Icons.cloud_off : Icons.cloud_done,
              color: isOffline ? AppColors.secondaryOrange : Colors.white,
            ),
          ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 700;
            final isLarge = constraints.maxWidth >= 1100;
            final stepperType =
                constraints.maxWidth < 900
                    ? StepperType.vertical
                    : StepperType.horizontal;
            final maxContentWidth = isLarge ? 1080.0 : 940.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 8 : 16,
                    vertical: isSmall ? 8 : 12,
                  ),
                  child: Stepper(
                    type: stepperType,
                    currentStep: _currentStep,
                    onStepContinue: () {
                      final validationError = _validateCurrentStep();
                      if (validationError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(validationError),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_currentStep < 4) {
                        setState(() => _currentStep += 1);
                      } else {
                        _submitForm();
                      }
                    },
                    onStepCancel: () {
                      if (_currentStep > 0) setState(() => _currentStep -= 1);
                    },
                    controlsBuilder: (context, details) {
                      return _buildStepControls(details);
                    },
                    steps: [
                      _buildLocationStep(),
                      _buildClassificationStep(),
                      _buildIntelligenceStep(),
                      _buildVisitationStep(),
                      _buildPreviewStep(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Step _buildLocationStep() {
    return Step(
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.editing,
      title: const Text("Loc"),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final twoCols = constraints.maxWidth >= 900;
          return Column(
            children: [
              _buildSectionHeader(
                "${_dealerType ?? 'School'} Visuals & Location",
              ),
              const SizedBox(height: 20),
              if (twoCols)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildMediaPicker()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildLocationDisplay()),
                  ],
                )
              else ...[
                _buildMediaPicker(),
                const SizedBox(height: 20),
                _buildLocationDisplay(),
              ],
            ],
          );
        },
      ),
    );
  }

  Step _buildClassificationStep() {
    return Step(
      isActive: _currentStep >= 1,
      state:
          _currentStep > 1
              ? StepState.complete
              : (_currentStep == 1 ? StepState.editing : StepState.indexed),
      title: const Text("Classification"),
      content: Column(
        children: [
          _buildSectionHeader("Classification"),
          TextField(
            controller: _shopNameController,
            decoration: InputDecoration(
              labelText: "${_dealerType ?? 'School'} Name",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCounty,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "County",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items:
                _counties
                    .map(
                      (county) => DropdownMenuItem<String>(
                        value: county,
                        child: Text(
                          county,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _selectedCounty = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _dealerType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "Client Type",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: "School", child: Text("School")),
              DropdownMenuItem(
                value: "Institution",
                child: Text("Institution"),
              ),
              DropdownMenuItem(value: "Bookshop", child: Text("Bookshop")),
            ],
            onChanged:
                (val) => setState(() {
                  _dealerType = val;
                  _shopCategory = null;
                  _partnerSubtype = null;
                  _selectedProduct = null;
                  _selectedBookProgram = null;
                }),
          ),
          const SizedBox(height: 16),
          if (_dealerType == "School")
            _buildDropdown(
              "School Category",
              [
                "ECDE",
                "Primary",
                "Junior Secondary",
                "Senior Secondary",
                "University",
                "Others",
              ],
              (val) => setState(() => _shopCategory = val),
              value: _shopCategory,
            )
          else if (_dealerType == "Bookshop")
            _buildDropdown(
              "Bookshop Category",
              ["Retail", "Chain", "Distributor", "Others"],
              (val) => setState(() => _partnerSubtype = val),
              value: _partnerSubtype,
            )
          else if (_dealerType == "Institution")
            _buildDropdown(
              "Institution Category",
              ["Library", "County", "NGO", "Others"],
              (val) => setState(() {
                _partnerSubtype = val;
                if (val != 'Others') {
                  _institutionCategoryOtherController.clear();
                }
              }),
              value: _partnerSubtype,
            )
          else
            const SizedBox.shrink(),
          const SizedBox(height: 24),

          if (_dealerType == "School") ...[
            _buildSectionHeader("Book Program"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final program in ["Book List", "Book Fund"])
                  FilterChip(
                    label: Text(program),
                    selected: _selectedBookPrograms.contains(program),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedBookPrograms.add(program);
                        } else {
                          _selectedBookPrograms.remove(program);
                        }
                      });
                    },
                  ),
              ],
            ),
          ] else if (_dealerType == "Bookshop") ...[
            _buildSectionHeader("Bookshop Services"),
            _buildSingleSelect([
              "Retail",
              "Bulk Supply",
              "Special Orders",
              "Promotions",
            ]),
            const SizedBox(height: 16),
            _buildSectionHeader("Learning Materials Stocked"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in [
                  'Course Books',
                  'ECD Books',
                  'Reference',
                  'Teacher Guides',
                ])
                  FilterChip(
                    label: Text(item),
                    selected: _selectedLearningMaterials.contains(item),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLearningMaterials.add(item);
                        } else {
                          _selectedLearningMaterials.remove(item);
                        }
                      });
                    },
                  ),
              ],
            ),
          ] else if (_dealerType == "Institution") ...[
            _buildSectionHeader("Specify Institution Category"),
            if (_partnerSubtype == "Others") ...[
              const SizedBox(height: 8),
              _buildTextField(
                "Specify",
                controller: _institutionCategoryOtherController,
                maxLines: 2,
              ),
            ],
          ],
          if (_dealerType == "School") ...[
            const SizedBox(height: 16),
            _buildDropdown(
              "School Ownership",
              ["Private", "Public", "Others"],
              (val) => setState(() {
                _schoolOwnership = val;
                if (val != 'Others') {
                  _schoolOwnershipOtherController.clear();
                }
              }),
              value: _schoolOwnership,
            ),
            if (_schoolOwnership == 'Others') ...[
              const SizedBox(height: 16),
              _buildTextField(
                "Specify Ownership",
                controller: _schoolOwnershipOtherController,
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              "School Population",
              controller: _schoolPopulationController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              "School Status",
              ["Existing", "New"],
              (val) => setState(() {
                _schoolLifecycleStatus = val;
                final stages = _crmEngagementStages;
                if (_engagementType != null &&
                    !stages.contains(_engagementType)) {
                  _engagementType = null;
                }
              }),
              value: _schoolLifecycleStatus,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              "CRM Workflow Status",
              _crmEngagementStages,
              (val) => setState(() => _engagementType = val),
              value: _engagementType,
            ),
          ] else if (_dealerType == "Bookshop" ||
              _dealerType == "Institution") ...[
            const SizedBox(height: 16),
            _buildDropdown(
              "${_dealerType == 'Bookshop' ? 'Bookshop' : 'Institution'} CRM Status",
              _crmEngagementStages,
              (val) => setState(() => _engagementType = val),
              value: _engagementType,
            ),
          ],
        ],
      ),
    );
  }

  Step _buildIntelligenceStep() {
    return Step(
      isActive: _currentStep >= 2,
      state:
          _currentStep > 2
              ? StepState.complete
              : (_currentStep == 2 ? StepState.editing : StepState.indexed),
      title: const Text("Data"),
      content: Column(
        children: [
          _buildSectionHeader(_contactPersonSectionTitle),
          _buildTextField(
            _contactNameLabel,
            controller: _contactNameController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _contactPhoneLabel,
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            suffixIcon: Icons.contacts_outlined,
            suffixTooltip: 'Pick from phonebook',
            onSuffixPressed: _pickContactFromPhonebook,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _contactEmailLabel,
            controller: _contactEmailController,
            keyboardType: TextInputType.emailAddress,
            helperText: 'Optional',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _contactTitleLabel,
            controller: _contactTitleController,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(_samplesSectionTitle),
          _buildDropdown(
            _samplesLeftLabel,
            ["Yes", "No"],
            (val) => setState(() {
              _samplesLeft = val;
              if (val != "Yes") {
                _selectedSampleCategory = null;
                _selectedSampleBooks = [];
                _sampleProofPhoto = null;
                _sampleProofPhotoBytes = null;
              }
            }),
            value: _samplesLeft,
          ),
          if (_samplesLeft == "Yes") ...[
            const SizedBox(height: 16),
            const SizedBox(height: 12),
            _buildDropdown(
              'To be returned?',
              ['Yes', 'No'],
              (val) => setState(() => _samplesToBeReturned = val),
              value: _samplesToBeReturned,
            ),
            const SizedBox(height: 16),
            if (_dealerType == 'School') ...[
              _buildSectionHeader('Learning Materials Left'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in [
                    'Course Books',
                    'ECD Books',
                    'Reference',
                    'Teacher Guides',
                  ])
                    FilterChip(
                      label: Text(item),
                      selected: _selectedLearningMaterials.contains(item),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedLearningMaterials.add(item);
                          } else {
                            _selectedLearningMaterials.remove(item);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _buildSampleProofPicker(),
          ],
        ],
      ),
    );
  }

  Step _buildVisitationStep() {
    return Step(
      isActive: _currentStep >= 3,
      state: _currentStep == 3 ? StepState.editing : StepState.indexed,
      title: const Text("Feedback"),
      content: Column(
        children: [
          _buildSectionHeader(_feedbackSectionTitle),
          _buildTextField(
            _feedbackLabel,
            maxLines: 3,
            controller: _feedbackController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _notesLabel,
            maxLines: 3,
            controller: _notesController,
          ),
        ],
      ),
    );
  }

  Step _buildPreviewStep() {
    final displayType = _dealerType ?? 'School';
    return Step(
      isActive: _currentStep >= 4,
      state: _currentStep == 4 ? StepState.editing : StepState.indexed,
      title: const Text("Preview"),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Review Before Submit"),
          _previewCard(
            title: "Location & Media",
            onEdit: () => setState(() => _currentStep = 0),
            lines: [
              "Photo: ${_capturedPhoto != null ? 'Captured' : 'Not captured'}",
              "Latitude: ${_currentPosition?.latitude?.toStringAsFixed(6) ?? '-'}",
              "Longitude: ${_currentPosition?.longitude?.toStringAsFixed(6) ?? '-'}",
              "GPS Accuracy: ${_currentPosition?.accuracy.toStringAsFixed(1) ?? '-'} m",
            ],
          ),
          const SizedBox(height: 12),
          _previewCard(
            title: "Classification",
            onEdit: () => setState(() => _currentStep = 1),
            lines: [
              "$displayType Name: ${_shopNameController.text.trim()}",
              "County: ${_selectedCounty ?? '-'}",
              "Client Type: $displayType",
              "Category: ${_shopCategory ?? _partnerSubtype ?? '-'}",
              "Product: ${_selectedProduct ?? '-'}",
              if (_dealerType == "School") ...[
                "Book Program: ${_selectedBookPrograms.isEmpty ? '-' : _selectedBookPrograms.join(', ')}",
                "School Status: ${_schoolLifecycleStatus ?? '-'}",
              ],
              "CRM Stage: ${_engagementType ?? '-'}",
            ],
          ),
          const SizedBox(height: 12),
          _previewCard(
            title: "Contact & Samples",
            onEdit: () => setState(() => _currentStep = 2),
            lines: [
              "${_contactNameLabel}: ${_contactNameController.text.trim().isEmpty ? '-' : _contactNameController.text.trim()}",
              "${_contactPhoneLabel}: ${_contactPhoneController.text.trim()}",
              "${_contactEmailLabel}: ${_contactEmailController.text.trim().isEmpty ? '-' : _contactEmailController.text.trim()}",
              "${_contactTitleLabel}: ${_contactTitleController.text.trim().isEmpty ? '-' : _contactTitleController.text.trim()}",
              "Samples Left: ${_samplesLeft ?? '-'}",
              "To be returned: ${_samplesToBeReturned ?? '-'}",
              if (_dealerType == 'School')
                "Learning Materials Stocked: ${_selectedLearningMaterials.isEmpty ? '-' : _selectedLearningMaterials.join(', ')}",
              "Sample Proof: ${_sampleProofPhoto != null ? 'Captured' : 'Not captured'}",
            ],
          ),
          const SizedBox(height: 12),
          _previewCard(
            title: "Feedback",
            onEdit: () => setState(() => _currentStep = 3),
            lines: [
              "Feedback: ${_feedbackController.text.trim().isEmpty ? '-' : _feedbackController.text.trim()}",
              "Notes: ${_notesController.text.trim().isEmpty ? '-' : _notesController.text.trim()}",
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String get _contactPersonSectionTitle {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Contact Person";
      case "Institution":
        return "Institution Contact Person";
      case "School":
      default:
        return "Contact Person";
    }
  }

  String get _contactNameLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Contact Name";
      case "Institution":
        return "Institution Contact Name";
      case "School":
      default:
        return "Name";
    }
  }

  String get _contactPhoneLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Phone Number";
      case "Institution":
        return "Institution Phone Number";
      case "School":
      default:
        return "Phone Number";
    }
  }

  String get _contactEmailLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Email";
      case "Institution":
        return "Institution Email";
      case "School":
      default:
        return "Email";
    }
  }

  String get _contactTitleLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Title in the Bookshop";
      case "Institution":
        return "Title in the Institution";
      case "School":
      default:
        return "Title in the School";
    }
  }

  String get _samplesSectionTitle {
    switch (_dealerType) {
      case "Bookshop":
        return "Samples Left in Bookshop";
      case "Institution":
        return "Samples Left for Institution";
      case "School":
      default:
        return "Samples Left";
    }
  }

  String get _samplesLeftLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Any samples left?";
      case "Institution":
        return "Any stock samples left?";
      case "School":
      default:
        return "Samples left?";
    }
  }

  String get _feedbackSectionTitle {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Feedback";
      case "Institution":
        return "Institution Feedback";
      case "School":
      default:
        return "Feedback";
    }
  }

  String get _feedbackLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Feedback";
      case "Institution":
        return "Institution Feedback";
      case "School":
      default:
        return "Feedback";
    }
  }

  String get _notesLabel {
    switch (_dealerType) {
      case "Bookshop":
        return "Bookshop Notes";
      case "Institution":
        return "Institution Notes";
      case "School":
      default:
        return "Notes";
    }
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    ValueChanged<String?> onChanged, {
    String? value,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items:
          items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSingleSelect(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          items
              .map(
                (item) => FilterChip(
                  label: Text(item),
                  selected: _selectedProduct == item,
                  onSelected: (_) => setState(() => _selectedProduct = item),
                ),
              )
              .toList(),
    );
  }

  Widget _buildMultiSelectSampleBooks() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          _filteredSampleBookOptions
              .map(
                (item) => FilterChip(
                  label: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: _selectedSampleBooks.contains(item),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSampleBooks.add(item);
                      } else {
                        _selectedSampleBooks.remove(item);
                      }
                    });
                  },
                ),
              )
              .toList(),
    );
  }

  Widget _buildTextField(
    String label, {
    TextEditingController? controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    String? helperText,
    IconData? suffixIcon,
    VoidCallback? onSuffixPressed,
    String? suffixTooltip,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon:
            suffixIcon == null
                ? null
                : IconButton(
                  tooltip: suffixTooltip,
                  onPressed: onSuffixPressed,
                  icon: Icon(suffixIcon),
                ),
      ),
    );
  }

  List<String> get _filteredSampleBookOptions {
    var options = _sampleBookOptions;
    if ((_selectedSampleCategory ?? '').trim().isNotEmpty) {
      options =
          options
              .where(
                (item) =>
                    (_sampleBookCategoryByLabel[item] ?? '').toLowerCase() ==
                    _selectedSampleCategory!.toLowerCase(),
              )
              .toList();
    }
    if (_sampleBookSearchQuery.isEmpty) return options;
    return options
        .where((item) => item.toLowerCase().contains(_sampleBookSearchQuery))
        .toList();
  }

  List<String> get _sampleBookCategories {
    final categories =
        _sampleBookCategoryByLabel.values
            .where((c) => c.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return categories;
  }

  Widget _buildMediaPicker() {
    final displayType = _dealerType ?? 'School';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$displayType Photo",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child:
                  _capturedPhoto == null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_camera_outlined,
                              size: 44,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _captureStatus ??
                                  "Take a photo of the ${displayType.toLowerCase()}",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          _capturedPhotoBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _captureSchoolPhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text("Capture Photo"),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Retake photo',
                onPressed:
                    _capturedPhoto == null
                        ? null
                        : () => setState(() {
                          _capturedPhoto = null;
                          _capturedPhotoBytes = null;
                          _captureStatus = "Photo cleared";
                        }),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDisplay() {
    final latitude = _currentPosition?.latitude;
    final longitude = _currentPosition?.longitude;
    final accuracyMeters = _currentPosition?.accuracy;
    final hasLocation = latitude != null && longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "GPS Capture",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _fetchCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text("Refresh"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  hasLocation
                      ? AppColors.primaryGreen.withValues(alpha: 0.08)
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _captureStatus ??
                      (hasLocation
                          ? "GPS captured successfully"
                          : "Location not captured yet"),
                  style: TextStyle(
                    color:
                        hasLocation ? AppColors.primaryGreen : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 8),
                  Text("Latitude: ${latitude.toStringAsFixed(6)}"),
                  Text("Longitude: ${longitude.toStringAsFixed(6)}"),
                  if (accuracyMeters != null)
                    Text(
                      "Accuracy: ${accuracyMeters.toStringAsFixed(1)} m",
                      style: TextStyle(
                        color:
                            _hasAccurateGps
                                ? AppColors.primaryGreen
                                : Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildSubmissionPayload() {
    return {
      'shopName': _shopNameController.text,
      'county': _selectedCounty,
      'contactName': _contactNameController.text,
      'contactEmail': _contactEmailController.text,
      'samplesLeft': _samplesLeft,
      'sampleProofCaptured': _sampleProofPhoto != null,
      'schoolOwnership': _schoolOwnership,
      'schoolOwnershipOther': _schoolOwnershipOtherController.text,
      'schoolPopulation': _schoolPopulationController.text,
      'schoolLifecycleStatus': _schoolLifecycleStatus,
      'engagementType': _engagementType,
      'photoPath': _capturedPhoto?.path,
      'photoCaptured': _capturedPhoto != null,
      'gpsLatitude': _currentPosition?.latitude,
      'gpsLongitude': _currentPosition?.longitude,
      'captureStatus': _captureStatus,
    };
  }

  Future<Map<String, String?>> _uploadSchoolPhoto() async {
    if (_capturedPhoto == null) {
      return {'photoUrl': null, 'photoPath': null};
    }

    final supabase = Supabase.instance.client;
    final fileExt = _capturedPhoto!.path.split('.').last.toLowerCase();
    final safeName =
        _shopNameController.text.trim().isEmpty
            ? 'school'
            : _shopNameController.text.trim().replaceAll(
              RegExp(r'[^a-zA-Z0-9]+'),
              '_',
            );
    final fileName =
        'schools/${safeName}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final bytes = await _capturedPhoto!.readAsBytes();

    try {
      await supabase.storage
          .from('schools')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return {
        'photoUrl': supabase.storage.from('schools').getPublicUrl(fileName),
        'photoPath': fileName,
      };
    } catch (e) {
      debugPrint('Photo upload failed: $e');
      return {'photoUrl': null, 'photoPath': _capturedPhoto!.path};
    }
  }

  Future<void> _captureSampleProofPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _sampleProofPhoto = photo;
        _sampleProofPhotoBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open camera for sample proof.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, String?>> _uploadSampleProofPhoto() async {
    if (_sampleProofPhoto == null) {
      return {'proofUrl': null, 'proofPath': null};
    }

    final supabase = Supabase.instance.client;
    final fileExt = _sampleProofPhoto!.path.split('.').last.toLowerCase();
    final safeSchool =
        _shopNameController.text.trim().isEmpty
            ? 'school'
            : _shopNameController.text.trim().replaceAll(
              RegExp(r'[^a-zA-Z0-9]+'),
              '_',
            );
    final fileName =
        'sample_proofs/${safeSchool}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final bytes = await _sampleProofPhoto!.readAsBytes();

    try {
      await supabase.storage
          .from('schools')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return {
        'proofUrl': supabase.storage.from('schools').getPublicUrl(fileName),
        'proofPath': fileName,
      };
    } catch (e) {
      debugPrint('Sample proof upload failed: $e');
      return {'proofUrl': null, 'proofPath': _sampleProofPhoto!.path};
    }
  }

  Widget _buildSampleProofPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Capture Stamped Document *',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_sampleProofPhotoBytes == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No stamped document photo captured.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _sampleProofPhotoBytes!,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _captureSampleProofPhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_sampleProofPhoto == null ? 'Capture Photo' : 'Retake'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSampleBooks() async {
    try {
      final items = await _dbService.getSampleCatalogItemsFromTable();

      if (!mounted) return;

      final options =
          items
              .map((item) {
                final name = item.name.trim();
                final sku = item.sku.trim();
                if (name.isEmpty) return '';
                return sku.isEmpty ? name : '$name (SKU: $sku)';
              })
              .where((label) => label.trim().isNotEmpty)
              .toList();
      final categoryByLabel = <String, String>{};
      for (final item in items) {
        final name = item.name.trim();
        if (name.isEmpty) continue;
        final sku = item.sku.trim();
        final label = sku.isEmpty ? name : '$name (SKU: $sku)';
        categoryByLabel[label] = item.category.trim();
      }

      setState(() {
        _sampleBookCategoryByLabel
          ..clear()
          ..addAll(categoryByLabel);
        _sampleBookOptions = options;
        if (_selectedSampleCategory != null &&
            !_sampleBookCategories.contains(_selectedSampleCategory)) {
          _selectedSampleCategory = null;
        }
        _selectedSampleBooks =
            _selectedSampleBooks
                .where((book) => _sampleBookOptions.contains(book))
                .toList();
      });
    } catch (e) {
      debugPrint('Error loading sample books: $e');
      if (!mounted) return;
      setState(() {
        _sampleBookCategoryByLabel.clear();
        _sampleBookOptions = <String>[];
      });
    }
  }

  List<String> get _crmEngagementStages {
    return _crmPipelineStatusOptions;
  }

  Widget _previewCard({
    required String title,
    required VoidCallback onEdit,
    required List<String> lines,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 4),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepControls(ControlsDetails details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        final isFinalStep = _currentStep >= 4;
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: isNarrow ? constraints.maxWidth : null,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : details.onStepContinue,
                child:
                    _isSubmitting
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(isFinalStep ? 'Submit Online' : 'Continue'),
              ),
            ),
            if (isFinalStep)
              SizedBox(
                width: isNarrow ? constraints.maxWidth : null,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : details.onStepContinue,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Push Data Online'),
                ),
              ),
            SizedBox(
              width: isNarrow ? constraints.maxWidth : null,
              child: TextButton(
                onPressed: details.onStepCancel,
                child: const Text('Back'),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _validateCurrentStep() {
    final displayType = _dealerType ?? 'School';
    if (_currentStep == 1) {
      if (_shopNameController.text.trim().isEmpty) {
        return '$displayType name is required.';
      }
      if ((_selectedCounty ?? '').trim().isEmpty) {
        return 'County is required.';
      }
      if (_dealerType == null) {
        return 'Client Type is required.';
      }
      if (_dealerType == 'School') {
        if ((_schoolOwnership ?? '').trim().isEmpty) {
          return 'School ownership is required.';
        }
        if (_schoolOwnership == 'Others' &&
            _schoolOwnershipOtherController.text.trim().isEmpty) {
          return 'Please specify school ownership.';
        }
        final population = _schoolPopulationController.text.trim();
        final parsedPopulation = int.tryParse(population);
        if (population.isEmpty ||
            parsedPopulation == null ||
            parsedPopulation < 0) {
          return 'Enter a valid school population.';
        }
        if ((_schoolLifecycleStatus ?? '').trim().isEmpty) {
          return 'School status is required.';
        }
        if ((_engagementType ?? '').trim().isEmpty) {
          return 'Engagement type is required.';
        }
      } else if (_dealerType == 'Bookshop' || _dealerType == 'Institution') {
        if ((_engagementType ?? '').trim().isEmpty) {
          return 'CRM Workflow Status is required.';
        }
      }
    }

    if (_currentStep == 2) {
      final phone = _contactPhoneController.text.trim();
      if (phone.isEmpty) return 'Phone number is required.';
      final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (digits.length < 10) return 'Enter a valid phone number.';
      if (_samplesLeft == null) {
        return 'Please indicate whether samples were left.';
      }
      if (_samplesLeft == "Yes") {
        if ((_samplesToBeReturned ?? '').trim().isEmpty) {
          return 'Please indicate whether samples will be returned.';
        }
        if (_sampleProofPhoto == null) {
          return 'Please capture the stamped document photo.';
        }
      }
    }

    return null;
  }
}
