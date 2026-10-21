import 'package:flutter/material.dart';
import 'school_profile_page.dart';
import '../../services/api_service.dart';

class DuplicateDetectionPage extends StatefulWidget {
  const DuplicateDetectionPage({super.key});

  @override
  State<DuplicateDetectionPage> createState() => _DuplicateDetectionPageState();
}

class _DuplicateDetectionPageState extends State<DuplicateDetectionPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _duplicates = [];

  @override
  void initState() {
    super.initState();
    _fetchDuplicates();
  }

  Future<void> _fetchDuplicates() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService().getPotentialSchoolDuplicates();
      _duplicates = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching duplicates: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Quality: Duplicate Schools')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _duplicates.isEmpty
              ? const Center(child: Text('No potential duplicates found!'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _duplicates.length,
                itemBuilder: (context, index) {
                  final item = _duplicates[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Reason: ${item['reason']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          _buildSchoolLink(item['name'], item['id']),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'vs',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          _buildSchoolLink(
                            item['duplicate_name'],
                            item['duplicate_id'],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildSchoolLink(String name, String id) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SchoolProfilePage(schoolId: id),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue),
        ],
      ),
    );
  }
}
