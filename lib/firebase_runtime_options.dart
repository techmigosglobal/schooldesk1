import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:schooldesk1/core/config/env_config.dart';

class FirebaseRuntimeOptions {
  FirebaseRuntimeOptions._();

  static bool get hasDartDefineConfig =>
      EnvConfig.firebaseApiKey.isNotEmpty &&
      EnvConfig.firebaseProjectId.isNotEmpty &&
      EnvConfig.firebaseMessagingSenderId.isNotEmpty;

  static FirebaseOptions? get currentPlatform {
    if (!hasDartDefineConfig) return null;
    final appId = _platformAppId;
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: EnvConfig.firebaseApiKey,
      appId: appId,
      messagingSenderId: EnvConfig.firebaseMessagingSenderId,
      projectId: EnvConfig.firebaseProjectId,
      authDomain: EnvConfig.firebaseAuthDomain.isEmpty
          ? null
          : EnvConfig.firebaseAuthDomain,
      storageBucket: EnvConfig.firebaseStorageBucket.isEmpty
          ? null
          : EnvConfig.firebaseStorageBucket,
      measurementId: EnvConfig.firebaseMeasurementId.isEmpty
          ? null
          : EnvConfig.firebaseMeasurementId,
    );
  }

  static String get _platformAppId {
    if (kIsWeb) return EnvConfig.firebaseWebAppId;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return EnvConfig.firebaseAndroidAppId;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return EnvConfig.firebaseIosAppId;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return EnvConfig.firebaseWebAppId;
    }
  }
}
