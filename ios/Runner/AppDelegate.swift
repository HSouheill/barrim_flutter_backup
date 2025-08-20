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
            // Load API key from secure configuration
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let apiKey = config["GoogleMapsAPIKey"] as? String {
            GMSServices.provideAPIKey(apiKey)
        } else {
            print("Warning: Google Maps API key not found in configuration")
        }
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
