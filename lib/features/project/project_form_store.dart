import '../../services/api_service.dart';

enum ProjectQuestionType {
  shortAnswer,
  paragraph,
  multipleChoice,
  checkboxes,
  dropdown,
  fileUpload,
  datePicker,
  timePicker,
  dateTimePicker,
  numberInput,
  emailInput,
  phoneNumberInput,
  urlInput,
  ratingScale,
  slider,
  toggleSwitch,
  linearScale,
  matrixGrid,
  sectionBreak,
  imageChoice,
  signatureInput,
  locationPicker,
  autocompleteInput,
  passwordInput,
  richTextInput,
}

class ProjectFormQuestion {
  const ProjectFormQuestion({
    required this.title,
    required this.type,
    required this.required,
    required this.options,
  });

  final String title;
  final ProjectQuestionType type;
  final bool required;
  final List<String> options;
}

class ProjectForm {
  const ProjectForm({
    this.id,
    required this.title,
    required this.description,
    required this.questions,
    required this.publishedAt,
    this.createdBy,
    required this.assignedUserIds,
  });

  final String? id;
  final String title;
  final String description;
  final List<ProjectFormQuestion> questions;
  final DateTime publishedAt;
  final String? createdBy;
  final List<String> assignedUserIds;
}

class ProjectFormResponse {
  const ProjectFormResponse({
    required this.id,
    required this.formId,
    required this.formTitle,
    required this.respondentId,
    required this.answers,
    required this.submittedAt,
  });

  final String id;
  final String formId;
  final String formTitle;
  final String respondentId;
  final Map<String, dynamic> answers;
  final DateTime submittedAt;
}

class ProjectFormStore {
  ProjectFormStore._();

  static ApiService get _api => ApiService();

  static Future<void> publish(ProjectForm form) async {
    await _api.create('project_forms', {
      'title': form.title,
      'description': form.description,
      'questions': form.questions.map(_questionToMap).toList(),
      'published_at': form.publishedAt.toUtc().toIso8601String(),
      'created_by': _api.currentUserId,
      'assigned_user_ids': form.assignedUserIds,
    });
  }

  static Future<List<ProjectForm>> fetchPublishedForms() async {
    final data = await _api.getAll('project_forms', orderBy: 'published_at', orderDir: 'DESC', limit: 500);
    return data
        .map((row) => _formFromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  static Future<void> submitResponse({
    required String formId,
    required String formTitle,
    required Map<String, dynamic> answers,
  }) async {
    await _api.create('project_form_responses', {
      'form_id': formId,
      'form_title': formTitle,
      'respondent_id': _api.currentUserId,
      'answers': answers,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<List<ProjectFormResponse>> fetchResponses({
    String? formNameFilter,
  }) async {
    final filter = formNameFilter?.trim() ?? '';
    final data = await _api.getAll('project_form_responses', orderBy: 'submitted_at', orderDir: 'DESC', limit: 500);
    if (filter.isNotEmpty) data.removeWhere((row) => !row['form_title'].toString().toLowerCase().contains(filter.toLowerCase()));

    return data.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return _responseFromMap(map);
    }).toList();
  }

  static Future<List<ProjectFormResponse>> fetchResponsesPage({
    String? formNameFilter,
    required int page,
    int pageSize = 50,
  }) async {
    final from = page * pageSize;
    final filter = formNameFilter?.trim() ?? '';
    final data = await _api.getAll('project_form_responses', orderBy: 'submitted_at', orderDir: 'DESC', limit: 500);
    if (filter.isNotEmpty) data.removeWhere((row) => !row['form_title'].toString().toLowerCase().contains(filter.toLowerCase()));
    final pageData = data.skip(from).take(pageSize).toList();

    return pageData.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return _responseFromMap(map);
    }).toList();
  }

  static Future<List<ProjectFormResponse>> fetchMyResponsesForForm(
    String formId,
  ) async {
    final userId = _api.currentUserId;
    if (userId == null) return <ProjectFormResponse>[];

    final data = await _api.getAll('project_form_responses', filter: {'form_id': formId, 'respondent_id': userId}, orderBy: 'submitted_at', orderDir: 'DESC', limit: 500);

    return data.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return _responseFromMap(map);
    }).toList();
  }

  static Future<List<ProjectFormResponse>> fetchMyResponses() async {
    final userId = _api.currentUserId;
    if (userId == null) return <ProjectFormResponse>[];
    final data = await _api.getAll('project_form_responses', filter: {'respondent_id': userId}, orderBy: 'submitted_at', orderDir: 'DESC', limit: 500);
    return data
        .map((row) => _responseFromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  static Map<String, dynamic> _questionToMap(ProjectFormQuestion q) {
    return {
      'title': q.title,
      'type': q.type.name,
      'required': q.required,
      'options': q.options,
    };
  }

  static ProjectForm _formFromMap(Map<String, dynamic> row) {
    final rawQuestions = (row['questions'] as List<dynamic>? ?? <dynamic>[]);
    return ProjectForm(
      id: row['id']?.toString(),
      title: row['title']?.toString() ?? 'Untitled Project Form',
      description: row['description']?.toString() ?? '',
      questions:
          rawQuestions
              .map(
                (item) =>
                    _questionFromMap(Map<String, dynamic>.from(item as Map)),
              )
              .toList(),
      publishedAt:
          DateTime.tryParse(row['published_at']?.toString() ?? '') ??
          DateTime.now(),
      createdBy: row['created_by']?.toString(),
      assignedUserIds:
          (row['assigned_user_ids'] as List<dynamic>? ?? <dynamic>[])
              .map((id) => id.toString())
              .toList(),
    );
  }

  static ProjectFormQuestion _questionFromMap(Map<String, dynamic> map) {
    final typeName =
        map['type']?.toString() ?? ProjectQuestionType.shortAnswer.name;
    final type = ProjectQuestionType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => ProjectQuestionType.shortAnswer,
    );
    return ProjectFormQuestion(
      title: map['title']?.toString() ?? 'Untitled Question',
      type: type,
      required: map['required'] == true,
      options:
          (map['options'] as List<dynamic>? ?? <dynamic>[])
              .map((o) => o.toString())
              .toList(),
    );
  }

  static ProjectFormResponse _responseFromMap(Map<String, dynamic> map) {
    return ProjectFormResponse(
      id: map['id']?.toString() ?? '',
      formId: map['form_id']?.toString() ?? '',
      formTitle: map['form_title']?.toString() ?? '',
      respondentId: map['respondent_id']?.toString() ?? '',
      answers: Map<String, dynamic>.from(
        map['answers'] as Map? ?? <String, dynamic>{},
      ),
      submittedAt:
          DateTime.tryParse(map['submitted_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
