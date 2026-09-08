import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/sales_access.dart';
import '../database/database_service.dart';
import '../profile/crm_notification_service.dart';
import '../../models/pipeline_stage.dart';
import '../../models/school_sale_model.dart';
import 'add_order_page.dart';

class SchoolSellPage extends StatefulWidget {
  const SchoolSellPage({super.key, required this.school});

  final Map<String, dynamic> school;

  @override
  State<SchoolSellPage> createState() => _SchoolSellPageState();
}

class _SchoolSellPageState extends State<SchoolSellPage> {
  final _databaseService = DatabaseService();
  final _packageController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiptController = TextEditingController();
  final _nextActionController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _sampleQtyController = TextEditingController();
  final _quoteRefController = TextEditingController();
  final _decisionOwnerController = TextEditingController();
  final _negotiationTopicController = TextEditingController();
  final _lossReasonController = TextEditingController();
  final _dormantReasonController = TextEditingController();
  bool _saving = false;
  bool _loadingPipeline = true;
  int? _currentRole;
  String? _paymentMethod;
  String? _saleId;
  PipelineStage _currentStage = PipelineStage.lead;
  PipelineStage _selectedStage = PipelineStage.lead;
  DateTime? _expectedCloseDate;
  DateTime? _nextActionDueDate;
  Color _stageColor(PipelineStage stage) {
    switch (stage) {
      case PipelineStage.won:
        return Colors.green;
      case PipelineStage.lost:
        return Colors.red;
      case PipelineStage.negotiation:
        return Colors.orange;
      case PipelineStage.contacted:
      case PipelineStage.meetingScheduled:
      case PipelineStage.sampleIssued:
      case PipelineStage.quotationSent:
      case PipelineStage.decisionPending:
        return Colors.blue;
      case PipelineStage.dormant:
        return Colors.grey;
      default:
        return AppColors.primaryGreen;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _packageController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _receiptController.dispose();
    _nextActionController.dispose();
    _contactPersonController.dispose();
    _sampleQtyController.dispose();
    _quoteRefController.dispose();
    _decisionOwnerController.dispose();
    _negotiationTopicController.dispose();
    _lossReasonController.dispose();
    _dormantReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final role = await _databaseService.getCurrentUserRole();
    final schoolId = widget.school['id']?.toString();
    if (schoolId == null || schoolId.isEmpty) {
      setState(() {
        _currentRole = role;
        _loadingPipeline = false;
      });
      return;
    }

    final latestSale = await _databaseService.getLatestSchoolSale(schoolId);
    if (!mounted) return;

    if (latestSale != null) {
      _saleId = latestSale.id;
      _currentStage = latestSale.stage;
      _selectedStage = latestSale.stage;
      _expectedCloseDate = latestSale.expectedCloseDate;
    }

    setState(() {
      _currentRole = role;
      _loadingPipeline = false;
    });
  }

  bool get _isAdminRole => SalesAccess.isAdmin(_currentRole);
  bool get _isViewOnlyRole => SalesAccess.isViewOnly(_currentRole);
  bool get _canCheckout => SalesAccess.canCheckout(_currentRole);
  bool get _isCheckoutStage => _selectedStage == PipelineStage.won;

  List<_StageFieldConfig> get _stageFields {
    switch (_selectedStage) {
      case PipelineStage.contacted:
        return [
          _StageFieldConfig(
            label: 'Contact Person',
            controller: _contactPersonController,
            required: true,
          ),
        ];
      case PipelineStage.sampleIssued:
        return [
          _StageFieldConfig(
            label: 'Sample Quantity',
            controller: _sampleQtyController,
            required: true,
            numeric: true,
          ),
        ];
      case PipelineStage.quotationSent:
        return [
          _StageFieldConfig(
            label: 'Quotation Reference',
            controller: _quoteRefController,
            required: true,
          ),
        ];
      case PipelineStage.decisionPending:
        return [
          _StageFieldConfig(
            label: 'Decision Owner',
            controller: _decisionOwnerController,
            required: true,
          ),
        ];
      case PipelineStage.negotiation:
        return [
          _StageFieldConfig(
            label: 'Negotiation Topic',
            controller: _negotiationTopicController,
            required: true,
          ),
        ];
      case PipelineStage.lost:
        return [
          _StageFieldConfig(
            label: 'Loss Reason',
            controller: _lossReasonController,
            required: true,
          ),
        ];
      case PipelineStage.dormant:
        return [
          _StageFieldConfig(
            label: 'Dormancy Reason',
            controller: _dormantReasonController,
            required: true,
          ),
        ];
      default:
        return const [];
    }
  }

  String _buildStageContextNotes() {
    final parts = <String>[];
    for (final field in _stageFields) {
      final value = field.controller.text.trim();
      if (value.isNotEmpty) {
        parts.add('${field.label}: $value');
      }
    }
    if (parts.isEmpty) return '';
    final lines = parts.join(' | ');
    return 'Stage Context: $lines';
  }

  Future<void> _proceedToOrderBuilder() async {
    if (_isCheckoutStage && !_canCheckout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your role cannot proceed to checkout.')),
      );
      return;
    }
    double? checkoutAmount;
    if (_isCheckoutStage) {
      if (_paymentMethod == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a payment method to continue.')),
        );
        return;
      }

      if (_amountController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the checkout amount.')),
        );
        return;
      }

      checkoutAmount = double.tryParse(_amountController.text.trim());
      if (checkoutAmount == null || checkoutAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid numeric amount.')),
        );
        return;
      }

      if (_paymentMethod != 'cash' && _receiptController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter the payment reference or receipt.'),
          ),
        );
        return;
      }
    }

    final transitionAllowed = canMovePipelineStage(
      _currentStage,
      _selectedStage,
    );
    if (!transitionAllowed && !_isCheckoutStage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid move: ${_currentStage.label} to ${_selectedStage.label}.',
          ),
        ),
      );
      return;
    }

    for (final field in _stageFields) {
      final value = field.controller.text.trim();
      if (field.required && value.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${field.label} is required.')));
        return;
      }
      if (field.numeric && value.isNotEmpty && int.tryParse(value) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${field.label} must be a number.')),
        );
        return;
      }
    }

    if (_selectedStage.isActive &&
        (_nextActionController.text.trim().isEmpty ||
            _nextActionDueDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set a next action and due date for active stages.'),
        ),
      );
      return;
    }

    if (!_isCheckoutStage) {
      await _savePipelineStage(checkoutAmount: null);
      return;
    }

    setState(() => _saving = true);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddOrderPage(
              initialSchoolId: widget.school['id']?.toString(),
              initialSchoolName: widget.school['name']?.toString(),
              initialPaymentMethod: _paymentMethod,
              initialPaymentReference: _receiptController.text.trim(),
              initialCheckoutAmount: checkoutAmount!,
              initialNotes: _notesController.text.trim(),
              initialPackageName:
                  _packageController.text.trim().isEmpty
                      ? 'School Package'
                      : _packageController.text.trim(),
              initialSaleId: _saleId,
            ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      _currentStage = _selectedStage;
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.school['name']} order created successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _saving = false);
    }
  }

  Future<bool> _savePipelineStage({
    required double? checkoutAmount,
    bool orderCreated = false,
  }) async {
    final now = DateTime.now();
    final schoolId = widget.school['id']?.toString();

    if (!mounted) return false;
    setState(() => _saving = true);

    if (schoolId == null || schoolId.isEmpty) {
      setState(() => _saving = false);
      return false;
    }

    try {
      final contextNotes = _buildStageContextNotes();
      final mergedNotes = [
        if (_notesController.text.trim().isNotEmpty)
          _notesController.text.trim(),
        if (contextNotes.isNotEmpty) contextNotes,
      ].join('\n');
      final currentUserId = _databaseService.getCurrentUserId();
      final currentUser =
          currentUserId == null
              ? null
              : await _databaseService.getUser(currentUserId);
      final sale = SchoolSaleModel(
        id: _saleId,
        schoolId: schoolId,
        agentId: currentUserId,
        regionId: currentUser?.regionId,
        packageName:
            _packageController.text.trim().isEmpty
                ? 'School Package'
                : _packageController.text.trim(),
        expectedValue: checkoutAmount ?? 0,
        notes: mergedNotes.isEmpty ? null : mergedNotes,
        stage: _selectedStage,
        stageUpdatedAt: now,
        expectedCloseDate: _expectedCloseDate,
        probability: _selectedStage.defaultProbability,
        closedAt: _selectedStage == PipelineStage.won ? now : null,
        isSynced: false,
      );
      await _databaseService.saveSchoolSale(sale);
      _saleId = sale.id;

      if (_selectedStage.isActive) {
        await _databaseService.createSchoolFollowUp(
          schoolId: schoolId,
          nextStep: _nextActionController.text.trim(),
          dueAt: _nextActionDueDate!,
          notes:
              'Auto-created from stage ${_selectedStage.label}'
              '${contextNotes.isEmpty ? '' : ' • $contextNotes'}',
        );
      }

      _currentStage = _selectedStage;

      if (!mounted) return false;
      setState(() => _saving = false);
      await CrmNotificationService.showIfEnabled(
        context,
        message:
            orderCreated
                ? 'Pipeline updated after checkout.'
                : 'Pipeline stage saved.',
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _saving = false);
      await CrmNotificationService.showIfEnabled(
        context,
        message: 'Failed to save pipeline stage: $e',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolName = widget.school['name']?.toString() ?? 'School';
    final stageColor = _stageColor(_selectedStage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Pipeline & Checkout'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(
            title: schoolName,
            subtitle:
                'Move stage, plan next action, then complete checkout if ready.',
            icon: Icons.point_of_sale,
          ),
          const SizedBox(height: 20),
          if (_loadingPipeline)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_isAdminRole)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Admin mode enabled: full pipeline and checkout access.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else if (_isViewOnlyRole)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Role ${_currentRole ?? ""}: view-only mode enabled.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: stageColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: stageColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.timeline, color: stageColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Current: ${_currentStage.label}  ->  Next: ${_selectedStage.label}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stageColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_selectedStage.defaultProbability}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Pipeline Stage',
            child: Column(
              children: [
                DropdownButtonFormField<PipelineStage>(
                  initialValue: _selectedStage,
                  decoration: const InputDecoration(
                    labelText: 'Pipeline Stage',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      PipelineStage.values
                          .map(
                            (stage) => DropdownMenuItem(
                              value: stage,
                              child: Text(stage.label),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (_loadingPipeline || _isViewOnlyRole)
                          ? null
                          : (value) {
                            if (value == null) return;
                            setState(() => _selectedStage = value);
                          },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      _isViewOnlyRole
                          ? null
                          : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expectedCloseDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (picked == null) return;
                            setState(() => _expectedCloseDate = picked);
                          },
                  icon: const Icon(Icons.event),
                  label: Text(
                    _expectedCloseDate == null
                        ? 'Set Expected Close Date'
                        : 'Expected Close: ${_expectedCloseDate!.year}-${_expectedCloseDate!.month.toString().padLeft(2, '0')}-${_expectedCloseDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_stageFields.isNotEmpty) ...[
            _SectionCard(
              title: 'Stage Details',
              child: Column(
                children:
                    _stageFields
                        .map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: field.controller,
                              enabled: !_isViewOnlyRole,
                              keyboardType:
                                  field.numeric
                                      ? TextInputType.number
                                      : TextInputType.text,
                              decoration: InputDecoration(
                                labelText:
                                    field.required
                                        ? '${field.label} *'
                                        : field.label,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _SectionCard(
            title: 'Follow Up Plan',
            child: Column(
              children: [
                TextField(
                  controller: _nextActionController,
                  enabled: !_isViewOnlyRole,
                  decoration: const InputDecoration(
                    labelText: 'Next Action',
                    hintText: 'Required for active stages',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      _isViewOnlyRole
                          ? null
                          : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _nextActionDueDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked == null) return;
                            setState(() => _nextActionDueDate = picked);
                          },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _nextActionDueDate == null
                        ? 'Set Next Action Due Date'
                        : 'Next Action Due: ${_nextActionDueDate!.year}-${_nextActionDueDate!.month.toString().padLeft(2, '0')}-${_nextActionDueDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Offer Notes',
            child: Column(
              children: [
                TextField(
                  controller: _packageController,
                  decoration: const InputDecoration(
                    labelText: 'Package or Offer (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isCheckoutStage) ...[
            const Text(
              'Checkout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Method of Payment',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
              ],
              onChanged: (value) => setState(() => _paymentMethod = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'KES ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receiptController,
              decoration: InputDecoration(
                labelText:
                    _paymentMethod == 'cash'
                        ? 'Cash Receipt / Note'
                        : _paymentMethod == 'bank'
                        ? 'Bank Slip / Reference'
                        : 'M-Pesa Reference',
                border: const OutlineInputBorder(),
              ),
            ),
          ] else
            const Text(
              'Checkout is available after moving stage to Won.',
              style: TextStyle(color: Colors.black54),
            ),
          if (_isCheckoutStage && !_canCheckout) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Your role can review pipeline data, but checkout submission is restricted.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                (_saving ||
                        _isViewOnlyRole ||
                        (_isCheckoutStage && !_canCheckout))
                    ? null
                    : () async => _proceedToOrderBuilder(),
            icon:
                _saving
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.shopping_cart_checkout),
            label: Text(
              _isCheckoutStage ? 'Proceed to Checkout' : 'Save Pipeline',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.green.withValues(alpha: 0.15),
            child: Icon(icon, color: Colors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StageFieldConfig {
  final String label;
  final TextEditingController controller;
  final bool required;
  final bool numeric;

  const _StageFieldConfig({
    required this.label,
    required this.controller,
    this.required = false,
    this.numeric = false,
  });
}
