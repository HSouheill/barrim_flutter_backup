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

    if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
      let config = NSDictionary(contentsOfFile: path),
      let apiKey = config["GoogleMapsAPIKey"] as? String, 
      !apiKey.isEmpty {
        GMSServices.provideAPIKey(apiKey)
        print("Google Maps API key provided successfully")
      } else {
        print("Warning: Invalid Google Maps API key format")
      }

      GMSServices.provideAPIKey("AIzaSyD8LfG_dswX7RwHlfSCf-Qc0qFpEVm-XrM")

    
    // Initialize Google Maps services with proper error handling
    initializeGoogleMaps()
    
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
  
  private func initializeGoogleMaps() {
    // Load API key from secure configuration
    if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
       let config = NSDictionary(contentsOfFile: path),
       let apiKey = config["GoogleMapsAPIKey"] as? String {
      
      // Validate API key format (basic validation)
      if apiKey.count > 10 && apiKey.hasPrefix("AIza") {
        do {
          print("Providing Google Maps API key...")
          GMSServices.provideAPIKey(apiKey)
          print("Google Maps API key provided successfully")
          
          // Add a small delay to ensure services are fully initialized
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("Google Maps services initialization completed")
          }
        } catch {
          print("Error initializing Google Maps: \(error)")
        }
      } else {
        print("Warning: Invalid Google Maps API key format")
      }
    } else {
      print("Warning: Google Maps API key not found in configuration")
    }
  }
}
