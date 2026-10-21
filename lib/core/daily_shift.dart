import '../services/api_service.dart';

/// Field-shift rules for daily check-in.
///
/// Manual check-out stays locked for [minDurationBeforeManualCheckout].
/// After that, agents can keep working. Auto check-out only runs at local
/// midnight so a new calendar day can start.
class DailyShift {
  static const Duration minDurationBeforeManualCheckout = Duration(hours: 5);

  /// Local 12:00 AM that starts the calendar day after [checkInTime].
  static DateTime newDayStart(DateTime checkInTime) {
    final local = checkInTime.toLocal();
    return DateTime(local.year, local.month, local.day + 1);
  }

  static Duration timeUntilNewDay(DateTime checkInTime, [DateTime? now]) {
    final remaining = newDayStart(
      checkInTime,
    ).difference((now ?? DateTime.now()).toLocal());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static bool shouldAutoCheckout(DateTime checkInTime, [DateTime? now]) {
    return !(now ?? DateTime.now()).toLocal().isBefore(newDayStart(checkInTime));
  }

  static bool canManualCheckout(DateTime checkInTime, [DateTime? now]) {
    return (now ?? DateTime.now()).difference(checkInTime) >=
        minDurationBeforeManualCheckout;
  }

  /// Closes an open check-in once the calendar day has rolled over.
  /// Returns true when a check-out was written.
  static Future<bool> autoCheckoutIfNewDay({required String userId}) async {
    final api = ApiService();
    final rows = await api.getAll('visit_checkins',
        filter: {'agent_id': userId, 'checkout_at': {'is': null}},
        orderBy: 'checkin_at', orderDir: 'DESC', limit: 1);
    final response = rows.isEmpty ? null : rows.first;
    if (response == null) return false;

    final checkInTime = DateTime.parse(
      response['checkin_at'] as String,
    ).toLocal();
    if (!shouldAutoCheckout(checkInTime)) return false;

    final checkoutTime = DateTime.now();
    await api.patch('visit_checkins', response['id'].toString(), {
          'checkout_at': checkoutTime.toUtc().toIso8601String(),
          'duration_seconds': checkoutTime.difference(checkInTime).inSeconds,
          'auto_checkout': true,
          'notes': 'Auto check-out at midnight to start a new day',
        });
    return true;
  }
}
