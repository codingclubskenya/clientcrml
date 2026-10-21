import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/constants/colors.dart';
import '../../models/catalog_item_model.dart';
import '../database/database_service.dart';
import 'utils/csv_download_stub.dart'
    if (dart.library.html) 'utils/csv_download_web.dart'
    if (dart.library.io) 'utils/csv_download_io.dart';

class CatalogImportPage extends StatefulWidget {
  const CatalogImportPage({super.key});

  @override
  State<CatalogImportPage> createState() => _CatalogImportPageState();
}

class _CatalogImportPageState extends State<CatalogImportPage> {
  final _dbService = DatabaseService();
  final _csvController = TextEditingController();
  String _itemType = 'sale';
  bool _importing = false;
  String? _pickedFileName;

  @override
  void initState() {
    super.initState();
    _csvController.text = _template('sale');
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  String _template(String type) {
    if (type == 'sample') {
      return [
        'name,category,sku,stock_qty,description,is_active,sample_note',
        'Grade 1 Reader Pack,Primary,SMPL-PR-01,120,Starter reading sample,true,For classroom demo',
        'Teacher Guide Kit,Reference,SMPL-RF-02,54,Teacher support sample,true,Leave one at school office',
      ].join('\n');
    }

    return [
      'name,category,sku,unit_price,stock_qty,description,is_active',
      'Grade 1 Reader Pack,Primary,SL-PR-01,2850,120,Core sale pack,true',
      'Teacher Guide Kit,Reference,SL-RF-02,2700,60,Teacher support pack,true',
    ].join('\n');
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result.isNotEmpty && result.single.path != null) {
        final file = File(result.single.path!);
        final content = utf8.decode(await file.readAsBytes());
        setState(() {
          _csvController.text = content;
          _pickedFileName = result.single.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded: ${result.single.name}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  List<List<String>> _parseCsv(String input) {
    final lines =
        input
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    if (lines.isEmpty) return [];
    return lines.map(_splitCsvLine).toList();
  }

  List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    values.add(buffer.toString().trim());
    return values;
  }

  List<CatalogItemModel> _itemsFromCsv(String csvText) {
    final rows = _parseCsv(csvText);
    if (rows.length < 2) return [];

    final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
    final items = <CatalogItemModel>[];

    for (final row in rows.skip(1)) {
      final record = <String, String>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        record[headers[i]] = row[i];
      }

      final name = record['name']?.trim() ?? '';
      final category = record['category']?.trim() ?? '';
      final sku = record['sku']?.trim().replaceAll(' ', '') ?? '';
      if (name.isEmpty || sku.isEmpty) continue;

      final stockRaw =
          record['stock_qty']?.trim().isNotEmpty == true
              ? record['stock_qty']!.trim()
              : (record['qty']?.trim() ?? '');
      final itemTypeRaw = record['item_type']?.trim() ?? '';
      final resolvedType = itemTypeRaw.isNotEmpty ? itemTypeRaw : _itemType;
      final unitPriceRaw = record['unit_price']?.trim() ?? '';
      final double unitPrice =
          unitPriceRaw.isNotEmpty
              ? (double.tryParse(
                    unitPriceRaw.replaceAll(RegExp(r'[^0-9.]'), ''),
                  ) ??
                  0.0)
              : (resolvedType == 'sample' ? 0.0 : 0.0);

      items.add(
        CatalogItemModel(
          name: name,
          category: category.isEmpty ? 'General' : category,
          sku: sku,
          itemType: resolvedType,
          unitPrice: unitPrice,
          stockQty: int.tryParse(stockRaw) ?? 0,
          description: record['description']?.trim(),
          isActive:
              (record['is_active']?.trim().toLowerCase() ?? 'true') != 'false',
        ),
      );
    }

    // Intelligent Sorting: Arrange items by Category then by Name
    // This matches the database logical order for better manageability.
    items.sort((a, b) {
      final catComp = a.category.toLowerCase().compareTo(
        b.category.toLowerCase(),
      );
      if (catComp != 0) return catComp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  Future<void> _importCsv() async {
    final items = _itemsFromCsv(_csvController.text);
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No valid CSV rows found.')));
      return;
    }

    setState(() => _importing = true);
    try {
      await _dbService.upsertCatalogItems(items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${items.length} catalog items.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      setState(() {
        _csvController.clear();
        _pickedFileName = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _downloadTemplate(String type) async {
    final fileName =
        type == 'sample'
            ? 'sample_books_template.csv'
            : 'sales_books_template.csv';
    try {
      await downloadCsvTemplate(fileName, _template(type));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template download started: $fileName'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template download is not supported on this device. Use Load Template and copy it.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('Import Catalog CSV'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload or Paste CSV',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select a CSV file to upload or paste the content below.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Pick CSV File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_pickedFileName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selected: $_pickedFileName',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.blue,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _itemType,
                  decoration: const InputDecoration(
                    labelText: 'Default item type (if not in CSV)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'sale', child: Text('Sale Books')),
                    DropdownMenuItem(
                      value: 'sample',
                      child: Text('Sample Books'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _itemType = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _csvController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'CSV Preview / Manual Paste',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    hintText: 'name,category,sku,unit_price,stock_qty...',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _csvController.text = _template(_itemType);
                          _pickedFileName = null;
                        });
                      },
                      icon: const Icon(Icons.format_align_left, size: 18),
                      label: const Text('Load Template'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _csvController.clear();
                          _pickedFileName = null;
                        });
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Templates:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Download Sales Template',
                          onPressed: () => _downloadTemplate('sale'),
                          icon: const Icon(Icons.download),
                        ),
                        IconButton(
                          tooltip: 'Download Sample Template',
                          onPressed: () => _downloadTemplate('sample'),
                          icon: const Icon(Icons.download),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _importing ? null : _importCsv,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon:
                        _importing
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.save),
                    label: Text(
                      _importing ? 'Importing...' : 'Confirm & Import Catalog',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Use the CSV format specified in the templates.'),
                  Text('• Unit Price is required for Sale Books.'),
                  Text('• Stock Quantity defaults to 0 if not provided.'),
                  Text('• Duplicates (by SKU) will be updated.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
