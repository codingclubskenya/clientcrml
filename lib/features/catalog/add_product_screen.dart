import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/product_model.dart';
import '../../services/catalog_service.dart';
import 'catalog_seed.dart';
import 'catalog_theme.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key, this.suppliers, this.categories, this.initialProduct});

  final List<String>? suppliers;
  final List<String>? categories;
  final Product? initialProduct;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _service = CatalogService.instance;

  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _unitPriceCtrl = TextEditingController();
  final _wholesaleCtrl = TextEditingController();
  final _currentStockCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '0');
  final _maxStockCtrl = TextEditingController(text: '100');

  final _authorCtrl = TextEditingController();
  final _publisherCtrl = TextEditingController();
  final _isbnCtrl = TextEditingController();
  final _editionCtrl = TextEditingController();
  final _pageCountCtrl = TextEditingController();

  String? _supplierId;
  String? _supplierName;
  String? _category;
  String? _gradeLevel;
  String? _subject;
  String? _language;
  String? _unit;
  File? _pickedImage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    final ip = widget.initialProduct;
    if (ip != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill(ip));
    }
  }

  void _prefill(Product p) {
    setState(() {
      _nameCtrl.text = p.name;
      _skuCtrl.text = p.sku ?? '';
      _descCtrl.text = p.description ?? '';
      _barcodeCtrl.text = p.barcode ?? '';
      _unitPriceCtrl.text = p.unitPrice.toStringAsFixed(2);
      _wholesaleCtrl.text =
          p.wholesalePrice > 0 ? p.wholesalePrice.toStringAsFixed(2) : '';
      _currentStockCtrl.text = p.currentStock.toString();
      _minStockCtrl.text = p.minStock.toString();
      _maxStockCtrl.text = p.maxStock.toString();
      _supplierName = p.supplierName;
      _category = p.category;
      _unit = p.unit;
      if (p.isBook) {
        _authorCtrl.text = p.author ?? '';
        _publisherCtrl.text = p.publisher ?? '';
        _isbnCtrl.text = p.isbn ?? '';
        _editionCtrl.text = p.edition ?? '';
        _gradeLevel = p.gradeLevel;
        _subject = p.subject;
        _language = p.language;
        _pageCountCtrl.text = p.pageCount?.toString() ?? '';
      }
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    for (final c in [
      _nameCtrl,
      _skuCtrl,
      _descCtrl,
      _barcodeCtrl,
      _unitPriceCtrl,
      _wholesaleCtrl,
      _currentStockCtrl,
      _minStockCtrl,
      _maxStockCtrl,
      _authorCtrl,
      _publisherCtrl,
      _isbnCtrl,
      _editionCtrl,
      _pageCountCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  /// Dynamic supplier list — pulled from the service catalog. If the
  /// caller passed in an explicit list (e.g. for testing), honour it.
  List<String> get _suppliers {
    if (widget.suppliers != null && widget.suppliers!.isNotEmpty) {
      return widget.suppliers!;
    }
    return _service.suppliers;
  }

  /// Dynamic category list.
  List<String> get _categories {
    if (widget.categories != null && widget.categories!.isNotEmpty) {
      return widget.categories!;
    }
    return _service.categories;
  }

  List<String> get _units => _service.units;

  /// Used by the unit dropdown to seed itself with the first available
  /// unit on first build.
  String? get _defaultUnit => _units.isNotEmpty ? _units.first : null;

  /// Falls back to the static seed list when the catalog has no
  /// products yet (first run), so the form remains usable.
  List<String> get _gradeOptions {
    final live = _service.gradeLevels;
    if (live.isNotEmpty) return live;
    return ProductCatalog.gradeLevels;
  }

  List<String> get _subjectOptions {
    final live = _service.subjects;
    if (live.isNotEmpty) return live;
    return ProductCatalog.subjects;
  }

  List<String> get _languageOptions {
    final live = _service.languages;
    if (live.isNotEmpty) return live;
    return ProductCatalog.languages;
  }

  bool get _isBook => (_category ?? '').toLowerCase() == 'books';

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => _pickedImage = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier')),
      );
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 700));

    final product = Product(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      supplierId: _supplierId!,
      supplierName: _supplierName!,
      category: _category!,
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      unitPrice: double.parse(_unitPriceCtrl.text),
      wholesalePrice: _wholesaleCtrl.text.isEmpty
          ? double.parse(_unitPriceCtrl.text)
          : double.parse(_wholesaleCtrl.text),
      unit: _unit ?? _defaultUnit ?? 'pieces',
      currentStock: int.parse(_currentStockCtrl.text),
      minStock: int.parse(_minStockCtrl.text),
      maxStock: int.parse(_maxStockCtrl.text),
      imageUrl: _pickedImage?.path,
      author: _isBook && _authorCtrl.text.trim().isNotEmpty
          ? _authorCtrl.text.trim()
          : null,
      publisher: _isBook && _publisherCtrl.text.trim().isNotEmpty
          ? _publisherCtrl.text.trim()
          : null,
      isbn: _isBook && _isbnCtrl.text.trim().isNotEmpty
          ? _isbnCtrl.text.trim()
          : null,
      edition: _isBook && _editionCtrl.text.trim().isNotEmpty
          ? _editionCtrl.text.trim()
          : null,
      gradeLevel: _isBook ? _gradeLevel : null,
      subject: _isBook ? _subject : null,
      language: _isBook ? _language : null,
      pageCount: _isBook && _pageCountCtrl.text.trim().isNotEmpty
          ? int.tryParse(_pageCountCtrl.text.trim())
          : null,
    );

    if (!mounted) return;
    Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CatalogColors.neutralBackground,
      appBar: AppBar(
        title: const Text('Add Product'),
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                final left = _buildLeftColumn();
                final right = _buildRightColumn();
                if (wide) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 16),
                          Expanded(child: right),
                        ],
                      ),
                      if (_isBook) ...[
                        const SizedBox(height: 16),
                        _bookDetailsSection(),
                      ],
                      const SizedBox(height: 16),
                      _mediaSection(),
                      const SizedBox(height: 16),
                      _submitBar(),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    left,
                    const SizedBox(height: 16),
                    right,
                    if (_isBook) ...[
                      const SizedBox(height: 16),
                      _bookDetailsSection(),
                    ],
                    const SizedBox(height: 16),
                    _mediaSection(),
                    const SizedBox(height: 16),
                    _submitBar(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return _section(
      title: 'Product Information',
      icon: Icons.info_outline,
      children: [
        _field(
          controller: _nameCtrl,
          label: 'Product Name',
          required: true,
          hint: 'e.g., Maize Seeds 2kg',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _skuCtrl,
          label: 'SKU',
          hint: 'Stock keeping unit (optional)',
        ),
        const SizedBox(height: 12),
        _field(
          controller: _descCtrl,
          label: 'Description',
          hint: 'Short description of the product',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Supplier',
          required: true,
          value: _supplierId,
          items: _suppliers
              .map((s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() {
            _supplierId = v;
            _supplierName = v;
          }),
          validator: (v) => v == null ? 'Please select a supplier' : null,
        ),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Category',
          required: true,
          value: _category,
          items: _categories
              .map((c) => DropdownMenuItem<String>(
                    value: c,
                    child: Text(c),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _category = v),
          validator: (v) => v == null ? 'Please select a category' : null,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _barcodeCtrl,
          label: 'Barcode',
          hint: 'Scan or enter barcode (optional)',
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      children: [
        _section(
          title: 'Pricing',
          icon: Icons.payments_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _unitPriceCtrl,
                    label: 'Unit Price (KSh)',
                    required: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    hint: '0.00',
                    validator: _amountValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _wholesaleCtrl,
                    label: 'Wholesale Price',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    hint: '0.00',
                    validator: _amountValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _dropdownField(
              label: 'Unit of Measurement',
              value: _unit ?? _defaultUnit,
              items: _units
                  .map((u) => DropdownMenuItem<String>(
                        value: u,
                        child: Text(_unitLabel(u)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Inventory Thresholds',
          icon: Icons.warehouse_outlined,
          children: [
            _field(
              controller: _currentStockCtrl,
              label: 'Current Stock',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _intValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _minStockCtrl,
                    label: 'Minimum Stock',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _intValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _maxStockCtrl,
                    label: 'Maximum Stock',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _intValidator,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _mediaSection() {
    return _section(
      title: 'Media',
      icon: Icons.image_outlined,
      children: [
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CatalogColors.cardBorder,
                style: BorderStyle.solid,
              ),
            ),
            child: _pickedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_pickedImage!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_upload_outlined,
                          size: 32, color: CatalogColors.primaryAccent),
                      SizedBox(height: 8),
                      Text('Tap to upload product image'),
                      SizedBox(height: 4),
                      Text('PNG, JPG up to 5MB',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
          ),
        ),
        if (_pickedImage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _pickedImage = null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove image'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _submitBar() {
    return Row(
      children: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: CatalogColors.primaryAccent,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_submitting ? 'Saving...' : 'Save Product'),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CatalogColors.primaryAccent),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _bookDetailsSection() {
    return _section(
      title: 'Book Details',
      icon: Icons.menu_book_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _field(
                controller: _authorCtrl,
                label: 'Author',
                hint: 'e.g., J.M. Otieno',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                controller: _publisherCtrl,
                label: 'Publisher',
                hint: 'e.g., Longhorn Publishers',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _field(
                controller: _isbnCtrl,
                label: 'ISBN',
                hint: 'e.g., 9789966012345',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                controller: _editionCtrl,
                label: 'Edition',
                hint: 'e.g., 3rd Edition',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final stacked = c.maxWidth < 520;
            final grade = _dropdownField(
              label: 'Grade Level',
              value: _gradeLevel,
              items: _gradeOptions
                  .map((g) => DropdownMenuItem<String>(
                        value: g,
                        child: Text(g),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _gradeLevel = v),
            );
            final subject = _dropdownField(
              label: 'Subject',
              value: _subject,
              items: _subjectOptions
                  .map((s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(s),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _subject = v),
            );
            final language = _dropdownField(
              label: 'Language',
              value: _language,
              items: _languageOptions
                  .map((l) => DropdownMenuItem<String>(
                        value: l,
                        child: Text(l),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _language = v),
            );
            final pages = _field(
              controller: _pageCountCtrl,
              label: 'Pages',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            );
            if (stacked) {
              return Column(
                children: [
                  grade,
                  const SizedBox(height: 12),
                  subject,
                  const SizedBox(height: 12),
                  language,
                  const SizedBox(height: 12),
                  pages,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: grade),
                const SizedBox(width: 12),
                Expanded(child: subject),
                const SizedBox(width: 12),
                Expanded(child: language),
                const SizedBox(width: 12),
                Expanded(child: pages),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters ??
          (keyboardType == const TextInputType.numberWithOptions(decimal: true)
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        isDense: true,
      ),
      validator: validator,
    );
  }

  String _unitLabel(String u) {
    switch (u) {
      case 'pieces':
        return 'Pieces';
      case 'copies':
        return 'Copies (books)';
      case 'packs':
        return 'Packs';
      case 'sets':
        return 'Sets';
      case 'shrink':
        return 'Shrink';
      case 'cases':
        return 'Cases';
      case 'kg':
        return 'Kilograms';
      case 'litres':
        return 'Litres';
      case 'boxes':
        return 'Boxes';
      case 'reams':
        return 'Reams';
      default:
        return u;
    }
  }

  Widget _dropdownField({
    required String label,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? value,
    bool required = false,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        isDense: true,
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  String? _amountValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Must be positive';
    return null;
  }

  String? _intValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final parsed = int.tryParse(v);
    if (parsed == null) return 'Enter a whole number';
    if (parsed < 0) return 'Must be positive';
    return null;
  }
}