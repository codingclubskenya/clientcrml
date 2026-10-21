import 'package:workmanager/workmanager.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/api_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await ApiService().init();

    await Hive.initFlutter();
    final box = await Hive.openBox('school_box');

    final api = ApiService();
    final unsynced = box.values.where(
      (f) => f['isSynced'] == false || f['isSynced'] == 0 || f['is_synced'] == false || f['is_synced'] == 0,
    );

    for (var school in unsynced) {
      try {
        final schoolData = Map<String, dynamic>.from(school);
        final schoolId = schoolData['id']?.toString();
        if (schoolId == null || schoolId.isEmpty) {
          await api.create('schools', schoolData);
        } else {
          try { await api.update('schools', schoolId, schoolData); }
          catch (_) { await api.create('schools', schoolData); }
        }

        school['isSynced'] = true;
        school['is_synced'] = true;
        await box.put(school['id'], school);
      } catch (_) {
        return Future.value(false);
      }
    }

    return Future.value(true);
  });
}
