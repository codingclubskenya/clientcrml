class EventDateFormat {
  static String format(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      final dt = DateTime.tryParse(date.toString());
      if (dt == null) return date.toString();
      final local = dt.toLocal();
      final months = [
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
      final month = months[local.month - 1];
      final day = local.day.toString().padLeft(2, '0');
      final year = local.year;
      final hour = local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$day $month $year, ${hour12.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return date.toString();
    }
  }

  static String formatShort(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      final dt = DateTime.tryParse(date.toString());
      if (dt == null) return date.toString();
      final local = dt.toLocal();
      final months = [
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
      final month = months[local.month - 1];
      final day = local.day.toString().padLeft(2, '0');
      final year = local.year;
      return '$day $month $year';
    } catch (_) {
      return date.toString();
    }
  }

  static String formatTime(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      final dt = DateTime.tryParse(date.toString());
      if (dt == null) return date.toString();
      final local = dt.toLocal();
      final hour = local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${hour12.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return date.toString();
    }
  }

  static String formatRelative(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      final dt = DateTime.tryParse(date.toString());
      if (dt == null) return date.toString();
      final local = dt.toLocal();
      final now = DateTime.now();
      final diff = now.difference(local);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          if (diff.inMinutes == 0) return 'Just now';
          return '${diff.inMinutes} min ago';
        }
        return '${diff.inHours} hr ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return formatShort(date);
      }
    } catch (_) {
      return date.toString();
    }
  }
}
