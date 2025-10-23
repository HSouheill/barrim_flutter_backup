import UIKit
import Flutter
import GoogleMaps
import flutter_local_notifications
import UserNotifications
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Firebase will be configured in Dart code
    print("AppDelegate: Skipping Firebase configuration - will be handled in Dart")

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
    
    // Configure FCM
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()

    // Set FCM messaging delegate
    Messaging.messaging().delegate = self

    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
       GeneratedPluginRegistrant.register(with: registry)
      }
    GeneratedPluginRegistrant.register(with: self)
    
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

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}

// MARK: - UNUserNotificationCenterDelegate
@available(iOS 10, *)
extension AppDelegate {
  // Receive displayed notifications for iOS 10 devices.
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo

    // Print message ID.
    if let messageID = userInfo["gcm.message_id"] {
      print("Message ID: \(messageID)")
    }

    // Print full message.
    print(userInfo)

    // Change this to your preferred presentation option
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo

    // Print message ID.
    if let messageID = userInfo["gcm.message_id"] {
      print("Message ID: \(messageID)")
    }

    // Print full message.
    print(userInfo)

    completionHandler()
  }
}
