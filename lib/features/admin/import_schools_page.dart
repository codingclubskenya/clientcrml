import 'package:flutter/material.dart';
import '../../models/farmer_model.dart';
import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../services/api_service.dart';

class ImportSchoolsPage extends StatefulWidget {
  const ImportSchoolsPage({super.key});

  @override
  State<ImportSchoolsPage> createState() => _ImportSchoolsPageState();
}

class _ImportSchoolsPageState extends State<ImportSchoolsPage> {
  final _csvController = TextEditingController();
  final _dbService = DatabaseService();
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _csvController.text =
        'name,phone,county,book_category\nNairobi Academy,0712345678,Nairobi,Primary\nCoast High School,0722000000,Mombasa,Secondary';
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
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

  Future<void> _importCsv() async {
    final rows = _parseCsv(_csvController.text);
    if (rows.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No valid CSV rows found.')));
      return;
    }

    setState(() => _importing = true);
    try {
      final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
      final currentUserId = ApiService().currentUserId;
      final schools = <SchoolModel>[];

      for (final row in rows.skip(1)) {
        final record = <String, String>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          record[headers[i]] = row[i];
        }

        final name = record['name']?.trim() ?? '';
        final phone = record['phone']?.trim() ?? '';
        final county = record['county']?.trim() ?? 'Unknown';

        // Skip rows without the required name or phone
        if (name.isEmpty || phone.isEmpty) continue;

        schools.add(
          SchoolModel(
            name: name,
            phone: phone,
            county: county,
            focusAreas: const [],
            bookCategory: record['book_category']?.trim(),
            capturedBy: currentUserId,
            capturedAt: DateTime.now(),
            captureStatus: 'Imported via CSV',
            isSynced: false,
          ),
        );
      }

      if (schools.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid items to import (missing name/phone).'),
          ),
        );
        return;
      }

      for (final school in schools) {
        await _dbService.saveSchoolProfile(school);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${schools.length} schools (synced or queued offline).',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('Import Schools CSV'),
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bulk Onboard Schools',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paste a CSV with columns: name,phone,county,book_category',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _csvController,
                  maxLines: 15,
                  decoration: const InputDecoration(
                    labelText: 'CSV content',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _importing ? null : _importCsv,
                  icon:
                      _importing
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.upload_file),
                  label: const Text('Import CSV'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
