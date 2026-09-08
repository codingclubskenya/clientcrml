import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../models/farmer_model.dart';

class OnboardedListSection extends StatelessWidget {
  const OnboardedListSection({
    super.key,
    required this.items,
    required this.emptyLabel,
    required this.color,
  });

  final List<SchoolModel> items;
  final String emptyLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  emptyLabel,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: items
          .map(
            (s) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.store, color: color, size: 20),
                ),
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (s.county.trim().isNotEmpty) s.county,
                    if (s.phone.trim().isNotEmpty) s.phone,
                    if (s.createdAt != null)
                      'Added ${s.createdAt!.toLocal().toString().split(' ')[0]}',
                  ].join(' • '),
                ),
                trailing: Text(
                  s.isSynced ? 'Synced' : 'Pending',
                  style: TextStyle(
                    color: s.isSynced ? AppColors.primaryGreen : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
