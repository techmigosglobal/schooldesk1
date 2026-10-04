import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android-only, once-per-local-day Google Play update check.
///
/// The Play Core API only works for an app installed from Google Play. Debug,
/// sideloaded, iOS, web, and desktop runs are therefore treated as a normal
/// no-op after the check is safely ignored.
class AndroidUpdateService {
  AndroidUpdateService._();

  static final AndroidUpdateService instance = AndroidUpdateService._();

  static const _lastCheckedDateKey =
      'schooldesk.android_update.last_checked_date';

  Future<AppUpdateInfo?> checkOncePerDay() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final preferences = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (preferences.getString(_lastCheckedDateKey) == today) return null;

    // Record the attempt before calling Play. A missing Play Store, offline
    // device, or sideloaded build must not cause a request on every launch.
    await preferences.setString(_lastCheckedDateKey, today);
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return null;
      }
      return info;
    } on Object catch (error, stackTrace) {
      developer.log(
        'Android update check unavailable: $error',
        name: 'AndroidUpdateService',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> startUpdate(AppUpdateInfo info) async {
    try {
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Android update could not be started: $error',
        name: 'AndroidUpdateService',
        stackTrace: stackTrace,
      );
    }
  }

  @visibleForTesting
  static String dateKey(DateTime value) => _dateKey(value);

  static String _dateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
