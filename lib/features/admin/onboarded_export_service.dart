import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/farmer_model.dart';
import '../../models/user_model.dart';

class OnboardedExportRow {
  const OnboardedExportRow({
    required this.user,
    required this.items,
  });

  final UserModel user;
  final List<SchoolModel> items;
}

class OnboardedExportService {
  static const _green = PdfColor.fromInt(0xFF2E7D32);
  static const _orange = PdfColor.fromInt(0xFFE65100);
  static const _blue = PdfColor.fromInt(0xFF1565C0);
  static const _dark = PdfColor.fromInt(0xFF1B5E20);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFEEEEEE);

  static String _typeOf(SchoolModel s) {
    final t = (s.dealerType ?? '').toLowerCase();
    if (t == 'bookshop') return 'Bookshop';
    if (t == 'institution') return 'Institution';
    return 'School';
  }

  static PdfColor _typeColor(String type) {
    switch (type) {
      case 'Bookshop':
        return _orange;
      case 'Institution':
        return _blue;
      default:
        return _dark;
    }
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  static String _formatDateTime(DateTime d) {
    return '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> exportPerUserBreakdown({
    required BuildContext context,
    required String reportTitle,
    required String reportSubtitle,
    required int totalItems,
    required List<OnboardedExportRow> rows,
  }) async {
    final generatedAt = DateTime.now();
    final doc = pw.Document(
      title: reportTitle,
      author: 'DeHeus',
    );

    final byType = <String, int>{'School': 0, 'Bookshop': 0, 'Institution': 0};
    for (final row in rows) {
      for (final s in row.items) {
        byType[_typeOf(s)] = (byType[_typeOf(s)] ?? 0) + 1;
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
        header: (ctx) => _buildHeader(reportTitle, reportSubtitle, generatedAt),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _buildSummary(totalItems, rows.length, byType),
          pw.SizedBox(height: 16),
          for (final row in rows) ...[
            _buildUserSection(row),
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: _safeFileName(reportTitle),
    );
  }

  static pw.Widget _buildHeader(
    String title,
    String subtitle,
    DateTime generatedAt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _green, width: 1.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: _green,
                ),
              ),
              pw.Text(
                'Generated ${_formatDateTime(generatedAt)}',
                style: const pw.TextStyle(fontSize: 8, color: _grey),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 10, color: _grey),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _lightGrey, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'DeHeus · User Onboarding Tracker',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummary(
    int totalItems,
    int userCount,
    Map<String, int> byType,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          _summaryTile('Total items', '$totalItems', _green),
          _summaryTile('Users', '$userCount', _dark),
          _summaryTile('Schools', '${byType['School'] ?? 0}', _dark),
          _summaryTile('Bookshops', '${byType['Bookshop'] ?? 0}', _orange),
          _summaryTile(
            'Institutions',
            '${byType['Institution'] ?? 0}',
            _blue,
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryTile(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildUserSection(OnboardedExportRow row) {
    final name = (row.user.fullName?.trim().isNotEmpty ?? false)
        ? row.user.fullName!.trim()
        : row.user.email;
    final typeCounts = <String, int>{};
    for (final s in row.items) {
      final t = _typeOf(s);
      typeCounts[t] = (typeCounts[t] ?? 0) + 1;
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightGrey, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: const pw.BoxDecoration(
              color: _lightGrey,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 18,
                      height: 18,
                      decoration: pw.BoxDecoration(
                        color: _green,
                        borderRadius: pw.BorderRadius.circular(9),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      name,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  '${row.items.length} item${row.items.length == 1 ? '' : 's'} · Role ${row.user.role}',
                  style: const pw.TextStyle(fontSize: 8, color: _grey),
                ),
              ],
            ),
          ),
          if (typeCounts.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              child: pw.Wrap(
                spacing: 6,
                runSpacing: 4,
                children: typeCounts.entries
                    .map(
                      (e) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _lightGrey,
                          borderRadius: pw.BorderRadius.circular(3),
                          border: pw.Border.all(
                            color: _typeColor(e.key),
                            width: 0.5,
                          ),
                        ),
                        child: pw.Text(
                          '${e.value} ${e.key}${e.value == 1 ? '' : 's'}',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: _typeColor(e.key),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: _lightGrey, width: 0.3),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _lightGrey),
                children: [
                  _headerCell('Name'),
                  _headerCell('Type'),
                  _headerCell('County'),
                  _headerCell('Phone'),
                  _headerCell('Status'),
                ],
              ),
              ...row.items.map(
                (s) => pw.TableRow(
                  children: [
                    _bodyCell(s.name),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: pw.Text(
                        _typeOf(s),
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: _typeColor(_typeOf(s)),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    _bodyCell(s.county.isEmpty ? '—' : s.county),
                    _bodyCell(s.phone.isEmpty ? '—' : s.phone),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: pw.Text(
                        s.isSynced ? 'Synced' : 'Pending',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: s.isSynced ? _green : _orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _grey,
        ),
      ),
    );
  }

  static pw.Widget _bodyCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  static String _safeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    return 'dehus_${cleaned.isEmpty ? 'report' : cleaned}_${DateTime.now().millisecondsSinceEpoch}';
  }
}

extension on PdfColor {
  PdfColor shade(double factor) {
    return PdfColor(
      red * factor,
      green * factor,
      blue * factor,
    );
  }
}
