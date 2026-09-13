import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'package:schooldesk1/core/desktop/desktop_platform.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';

const schoolDeskOfflineSyncTask = 'schooldesk.offline.sync';
const _schoolDeskOfflineSyncUniqueName = 'schooldesk-periodic-offline-sync';

/// WorkManager entrypoint. Mobile operating systems decide whether and when
/// this runs, so foreground/resume/network triggers remain authoritative too.
@pragma('vm:entry-point')
void schoolDeskBackgroundCallback() {
  Workmanager().executeTask((task, inputData) async {
    if (task != schoolDeskOfflineSyncTask) return true;
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final sync = await OfflineSyncEngine.initialize();
      BackendApiClient.instance.attachOfflineSync(sync);
      await BackendApiClient.initialize();
      await sync.start();
      await sync.syncNow();
      sync.dispose();
      return true;
    } on Object {
      return false;
    }
  });
}

class OfflineBackgroundSyncScheduler {
  OfflineBackgroundSyncScheduler._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb || DesktopPlatform.isWindows) return;
    try {
      await Workmanager().initialize(schoolDeskBackgroundCallback);
      await Workmanager().registerPeriodicTask(
        _schoolDeskOfflineSyncUniqueName,
        schoolDeskOfflineSyncTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );
      _initialized = true;
    } on Object {
      // Background scheduling is best effort. The app remains correct through
      // foreground, resume, connectivity, and explicit refresh sync triggers.
    }
  }
}
