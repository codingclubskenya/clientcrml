import 'package:flutter/material.dart';
import '../project/project_form_store.dart';
import '../../services/api_service.dart';

enum _QuestionType {
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

class _FormQuestion {
  _FormQuestion({
    required this.title,
    required this.type,
    this.required = false,
    List<String>? options,
  }) : options = options ?? <String>['Option 1'];

  String title;
  _QuestionType type;
  bool required;
  List<String> options;
}

class ProjectFormBuilderPage extends StatefulWidget {
  const ProjectFormBuilderPage({super.key});

  @override
  State<ProjectFormBuilderPage> createState() => _ProjectFormBuilderPageState();
}

class _ProjectFormBuilderPageState extends State<ProjectFormBuilderPage> {
  final TextEditingController _formTitleController = TextEditingController(
    text: 'Untitled Project Form',
  );
  final TextEditingController _formDescriptionController =
      TextEditingController();
  final List<_FormQuestion> _questions = <_FormQuestion>[
    _FormQuestion(title: 'Untitled Question', type: _QuestionType.shortAnswer),
  ];
  bool _isPublishing = false;
  bool _loadingRole5Users = true;
  List<Map<String, String>> _role5Users = <Map<String, String>>[];
  final Set<String> _selectedAssigneeIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadRole5Users();
  }

  @override
  void dispose() {
    _formTitleController.dispose();
    _formDescriptionController.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        _FormQuestion(
          title: 'Untitled Question',
          type: _QuestionType.shortAnswer,
        ),
      );
    });
  }

  Future<void> _loadRole5Users() async {
    try {
      final res = await ApiService().getAll(
        'users', filter: {'role': 5},
        orderBy: 'full_name', orderDir: 'ASC', limit: 500,
      );
      _role5Users =
          res.map((row) {
            final map = Map<String, dynamic>.from(row as Map);
            final id = map['id']?.toString() ?? '';
            final name =
                (map['full_name']?.toString().trim().isNotEmpty ?? false)
                    ? map['full_name'].toString().trim()
                    : (map['email']?.toString() ?? 'Role 5 User');
            return <String, String>{'id': id, 'name': name};
          }).toList();
    } catch (_) {
      _role5Users = <Map<String, String>>[];
    } finally {
      if (mounted) setState(() => _loadingRole5Users = false);
    }
  }

  String _typeLabel(_QuestionType type) {
    switch (type) {
      case _QuestionType.shortAnswer:
        return 'Short answer';
      case _QuestionType.paragraph:
        return 'Paragraph';
      case _QuestionType.multipleChoice:
        return 'Multiple choice';
      case _QuestionType.checkboxes:
        return 'Checkboxes';
      case _QuestionType.dropdown:
        return 'Dropdown';
      case _QuestionType.fileUpload:
        return 'File Upload';
      case _QuestionType.datePicker:
        return 'Date Picker';
      case _QuestionType.timePicker:
        return 'Time Picker';
      case _QuestionType.dateTimePicker:
        return 'Date & Time Picker';
      case _QuestionType.numberInput:
        return 'Number Input';
      case _QuestionType.emailInput:
        return 'Email Input';
      case _QuestionType.phoneNumberInput:
        return 'Phone Number Input';
      case _QuestionType.urlInput:
        return 'URL Input';
      case _QuestionType.ratingScale:
        return 'Rating Scale';
      case _QuestionType.slider:
        return 'Slider';
      case _QuestionType.toggleSwitch:
        return 'Toggle Switch';
      case _QuestionType.linearScale:
        return 'Linear Scale';
      case _QuestionType.matrixGrid:
        return 'Matrix/Grid Question';
      case _QuestionType.sectionBreak:
        return 'Section Break / Divider';
      case _QuestionType.imageChoice:
        return 'Image Choice';
      case _QuestionType.signatureInput:
        return 'Signature Input';
      case _QuestionType.locationPicker:
        return 'Location Picker';
      case _QuestionType.autocompleteInput:
        return 'Autocomplete Input';
      case _QuestionType.passwordInput:
        return 'Password Input';
      case _QuestionType.richTextInput:
        return 'Rich Text Input';
    }
  }

  bool _supportsOptions(_QuestionType type) {
    return type == _QuestionType.multipleChoice ||
        type == _QuestionType.checkboxes ||
        type == _QuestionType.dropdown ||
        type == _QuestionType.imageChoice ||
        type == _QuestionType.autocompleteInput ||
        type == _QuestionType.matrixGrid;
  }

  Future<void> _publishForm() async {
    final title = _formTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add a form title.')));
      return;
    }
    if (_selectedAssigneeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one Role 5 user.')),
      );
      return;
    }

    final form = ProjectForm(
      title: title,
      description: _formDescriptionController.text.trim(),
      questions:
          _questions
              .map(
                (q) => ProjectFormQuestion(
                  title:
                      q.title.trim().isEmpty
                          ? 'Untitled Question'
                          : q.title.trim(),
                  type: _toSharedType(q.type),
                  required: q.required,
                  options: List<String>.from(q.options),
                ),
              )
              .toList(),
      publishedAt: DateTime.now(),
      assignedUserIds: _selectedAssigneeIds.toList(),
    );
    setState(() => _isPublishing = true);
    try {
      await ProjectFormStore.publish(form);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Publish failed: $e')));
      setState(() => _isPublishing = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isPublishing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Form "$title" published with ${_questions.length} question(s).',
        ),
      ),
    );
  }

  ProjectQuestionType _toSharedType(_QuestionType type) {
    switch (type) {
      case _QuestionType.shortAnswer:
        return ProjectQuestionType.shortAnswer;
      case _QuestionType.paragraph:
        return ProjectQuestionType.paragraph;
      case _QuestionType.multipleChoice:
        return ProjectQuestionType.multipleChoice;
      case _QuestionType.checkboxes:
        return ProjectQuestionType.checkboxes;
      case _QuestionType.dropdown:
        return ProjectQuestionType.dropdown;
      case _QuestionType.fileUpload:
        return ProjectQuestionType.fileUpload;
      case _QuestionType.datePicker:
        return ProjectQuestionType.datePicker;
      case _QuestionType.timePicker:
        return ProjectQuestionType.timePicker;
      case _QuestionType.dateTimePicker:
        return ProjectQuestionType.dateTimePicker;
      case _QuestionType.numberInput:
        return ProjectQuestionType.numberInput;
      case _QuestionType.emailInput:
        return ProjectQuestionType.emailInput;
      case _QuestionType.phoneNumberInput:
        return ProjectQuestionType.phoneNumberInput;
      case _QuestionType.urlInput:
        return ProjectQuestionType.urlInput;
      case _QuestionType.ratingScale:
        return ProjectQuestionType.ratingScale;
      case _QuestionType.slider:
        return ProjectQuestionType.slider;
      case _QuestionType.toggleSwitch:
        return ProjectQuestionType.toggleSwitch;
      case _QuestionType.linearScale:
        return ProjectQuestionType.linearScale;
      case _QuestionType.matrixGrid:
        return ProjectQuestionType.matrixGrid;
      case _QuestionType.sectionBreak:
        return ProjectQuestionType.sectionBreak;
      case _QuestionType.imageChoice:
        return ProjectQuestionType.imageChoice;
      case _QuestionType.signatureInput:
        return ProjectQuestionType.signatureInput;
      case _QuestionType.locationPicker:
        return ProjectQuestionType.locationPicker;
      case _QuestionType.autocompleteInput:
        return ProjectQuestionType.autocompleteInput;
      case _QuestionType.passwordInput:
        return ProjectQuestionType.passwordInput;
      case _QuestionType.richTextInput:
        return ProjectQuestionType.richTextInput;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 700;
    final maxContentWidth = screenWidth > 1200 ? 1080.0 : 940.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Form Builder'),
        actions: [
          if (isSmall)
            IconButton(
              onPressed: _isPublishing ? null : _publishForm,
              icon: const Icon(Icons.publish),
              tooltip: _isPublishing ? 'Publishing...' : 'Publish',
            )
          else
            TextButton.icon(
              onPressed: _isPublishing ? null : _publishForm,
              icon: const Icon(Icons.publish, color: Colors.white),
              label: Text(
                _isPublishing ? 'Publishing...' : 'Publish',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addQuestion,
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: ListView(
            padding: EdgeInsets.all(isSmall ? 12 : 16),
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(isSmall ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _formTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Form title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _formDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Form description',
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildAssigneeSection(),
              const SizedBox(height: 16),
              _buildPreviewSection(),
              const SizedBox(height: 16),
              for (int i = 0; i < _questions.length; i++) ...[
                _QuestionCard(
                  index: i,
                  question: _questions[i],
                  typeLabel: _typeLabel,
                  supportsOptions: _supportsOptions,
                  onChanged: () => setState(() {}),
                  onDelete:
                      _questions.length == 1
                          ? null
                          : () => setState(() => _questions.removeAt(i)),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project Users (Role 5)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Only selected users will see this form in Project.'),
            const SizedBox(height: 12),
            if (_loadingRole5Users)
              const LinearProgressIndicator()
            else
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _openAssigneePicker,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Select Users'),
                ),
              ),
            const SizedBox(height: 8),
            if (_selectedAssigneeIds.isEmpty)
              const Text(
                'No users selected yet.',
                style: TextStyle(color: Colors.black54),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _role5Users
                        .where((u) => _selectedAssigneeIds.contains(u['id']))
                        .map(
                          (u) => Chip(
                            label: Text(u['name'] ?? 'User'),
                            onDeleted:
                                () => setState(
                                  () => _selectedAssigneeIds.remove(u['id']),
                                ),
                          ),
                        )
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAssigneePicker() async {
    final temp = Set<String>.from(_selectedAssigneeIds);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Role 5 Users',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: _role5Users.length,
                        itemBuilder: (context, index) {
                          final user = _role5Users[index];
                          final id = user['id'] ?? '';
                          final selected = temp.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            title: Text(user['name'] ?? 'Role 5 User'),
                            onChanged: (checked) {
                              setSheetState(() {
                                if (checked == true) {
                                  temp.add(id);
                                } else {
                                  temp.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _selectedAssigneeIds
                              ..clear()
                              ..addAll(temp);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply Selection'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.preview_outlined),
        title: const Text(
          'Preview Before Publish',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Live preview of how the form will appear'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formTitleController.text.trim().isEmpty
                      ? 'Untitled Project Form'
                      : _formTitleController.text.trim(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_formDescriptionController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_formDescriptionController.text.trim()),
                ],
                const SizedBox(height: 16),
                for (int i = 0; i < _questions.length; i++) ...[
                  Text(
                    '${i + 1}. ${_questions[i].title.trim().isEmpty ? 'Untitled Question' : _questions[i].title.trim()}${_questions[i].required ? ' *' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _buildPreviewInput(_questions[i]),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewInput(_FormQuestion question) {
    switch (question.type) {
      case _QuestionType.shortAnswer:
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Short answer text',
            border: OutlineInputBorder(),
          ),
        );
      case _QuestionType.paragraph:
        return const TextField(
          enabled: false,
          minLines: 3,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Long answer text',
            border: OutlineInputBorder(),
          ),
        );
      case _QuestionType.multipleChoice:
        return Column(
          children:
              question.options
                  .map(
                    (o) => RadioListTile<bool>(
                      value: true,
                      groupValue: null,
                      onChanged: null,
                      title: Text(o),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
        );
      case _QuestionType.checkboxes:
        return Column(
          children:
              question.options
                  .map(
                    (o) => CheckboxListTile(
                      value: false,
                      onChanged: null,
                      title: Text(o),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
        );
      case _QuestionType.dropdown:
        return DropdownButtonFormField<String>(
          value: null,
          items:
              question.options
                  .map(
                    (o) => DropdownMenuItem<String>(value: o, child: Text(o)),
                  )
                  .toList(),
          onChanged: null,
          decoration: const InputDecoration(
            hintText: 'Choose',
            border: OutlineInputBorder(),
          ),
        );
      case _QuestionType.fileUpload:
        return OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Upload file'),
        );
      case _QuestionType.datePicker:
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Select date',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
        );
      case _QuestionType.timePicker:
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Select time',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.schedule_outlined),
          ),
        );
      case _QuestionType.dateTimePicker:
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Select date and time',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.event_outlined),
          ),
        );
      case _QuestionType.numberInput:
        return const TextField(
          enabled: false,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter number',
            border: OutlineInputBorder(),
          ),
        );
      case _QuestionType.emailInput:
        return const TextField(
          enabled: false,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'name@example.com',
            border: OutlineInputBorder(),
          ),
        );
      case _QuestionType.phoneNumberInput:
        return const TextField(
          enabled: false,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+1 555 000 0000',
            border: OutlineInputBorder(),
          ),
        );
      case _QuestionType.urlInput:
        return const TextField(
          enabled: false,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://example.com',
            border: OutlineInputBorder(),
          ),
        );
      case _QuestionType.ratingScale:
        return Row(
          children: List.generate(
            5,
            (i) => const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.star_border),
            ),
          ),
        );
      case _QuestionType.slider:
        return const Slider(value: 5, min: 0, max: 10, onChanged: null);
      case _QuestionType.toggleSwitch:
        return SwitchListTile(
          value: false,
          onChanged: null,
          contentPadding: EdgeInsets.zero,
          title: const Text('No / Yes'),
        );
      case _QuestionType.linearScale:
        return Wrap(
          spacing: 8,
          children: List.generate(10, (i) => Chip(label: Text('${i + 1}'))),
        );
      case _QuestionType.matrixGrid:
        final options =
            question.options.isEmpty
                ? <String>['Option 1', 'Option 2', 'Option 3']
                : question.options;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Matrix preview'),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Item')),
                  ...options.map((o) => DataColumn(label: Text(o))),
                ],
                rows:
                    const [
                      DataRow(cells: [DataCell(Text('Row 1'))]),
                    ].map((row) {
                      final cells = List<DataCell>.from(row.cells);
                      while (cells.length < options.length + 1) {
                        cells.add(
                          const DataCell(Icon(Icons.radio_button_unchecked)),
                        );
                      }
                      return DataRow(cells: cells);
                    }).toList(),
              ),
            ),
          ],
        );
      case _QuestionType.sectionBreak:
        return const Divider(thickness: 1.2);
      case _QuestionType.imageChoice:
        final options =
            question.options.isEmpty ? <String>['Choice'] : question.options;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options
                  .map(
                    (o) => Container(
                      width: 120,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.image_outlined),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(o, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  )
                  .toList(),
        );
      case _QuestionType.signatureInput:
        return Container(
          height: 90,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Text('Signature area'),
        );
      case _QuestionType.locationPicker:
        return Container(
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: const Center(child: Text('Map / GPS picker preview')),
        );
      case _QuestionType.autocompleteInput:
        return TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText:
                question.options.isEmpty
                    ? 'Start typing...'
                    : 'Suggestions: ${question.options.take(3).join(', ')}',
            border: const OutlineInputBorder(),
          ),
        );
      case _QuestionType.passwordInput:
        return const TextField(
          enabled: false,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Enter password',
            border: OutlineInputBorder(),
          ),
        );
      case _QuestionType.richTextInput:
        return const TextField(
          enabled: false,
          minLines: 4,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Rich text response (bold, italic, lists...)',
            border: OutlineInputBorder(),
          ),
        );
    }
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.typeLabel,
    required this.supportsOptions,
    required this.onChanged,
    this.onDelete,
  });

  final int index;
  final _FormQuestion question;
  final String Function(_QuestionType) typeLabel;
  final bool Function(_QuestionType) supportsOptions;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete question',
                  ),
              ],
            ),
            TextFormField(
              initialValue: question.title,
              decoration: const InputDecoration(labelText: 'Question title'),
              onChanged: (value) {
                question.title = value;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_QuestionType>(
              value: question.type,
              decoration: const InputDecoration(labelText: 'Question type'),
              items:
                  _QuestionType.values
                      .map(
                        (type) => DropdownMenuItem<_QuestionType>(
                          value: type,
                          child: Text(typeLabel(type)),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                question.type = value;
                if (!supportsOptions(value)) {
                  question.options = <String>['Option 1'];
                }
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Required'),
              value: question.required,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                question.required = value;
                onChanged();
              },
            ),
            if (supportsOptions(question.type)) ...[
              const SizedBox(height: 8),
              const Text(
                'Options',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (
                int optionIndex = 0;
                optionIndex < question.options.length;
                optionIndex++
              ) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: question.options[optionIndex],
                        decoration: InputDecoration(
                          labelText: 'Option ${optionIndex + 1}',
                        ),
                        onChanged: (value) {
                          question.options[optionIndex] = value;
                          onChanged();
                        },
                      ),
                    ),
                    IconButton(
                      onPressed:
                          question.options.length == 1
                              ? null
                              : () {
                                question.options.removeAt(optionIndex);
                                onChanged();
                              },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    question.options.add(
                      'Option ${question.options.length + 1}',
                    );
                    onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
