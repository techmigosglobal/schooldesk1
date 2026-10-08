import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "schooldesk-periodic-offline-sync",
      frequency: NSNumber(value: 15 * 60)
    )
    // Firebase is initialized once from Dart in main.dart. Calling
    // FirebaseApp.configure() here as well can configure a second default app
    // before firebase_core starts, and crashes on launch when the native plist
    // and --dart-define values differ. firebase_core reads the bundled
    // GoogleService-Info.plist when no explicit Dart options are supplied.
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
