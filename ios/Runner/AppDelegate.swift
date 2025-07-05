import UIKit
import Flutter
import FirebaseCore
import GoogleMaps
import flutter_local_notifications

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyD8LfG_dswX7RwHlfSCf-Qc0qFpEVm-XrM")
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
       GeneratedPluginRegistrant.register(with: registry)
      }
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
   if  #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
