import UIKit
import Flutter
import Firebase // <<< Firebase import'u eklendi

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // KRİTİK 1: Firebase Servislerini Başlatma
    // Bu, Firebase Core'un tüm servislerini (FCM dahil) başlatır.
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
    
    GeneratedPluginRegistrant.register(with: self)
    
    // iOS 10+ Bildirim İşleyicisi
    // Bu, FCM token'ı almak ve bildirimleri işlemek için paketin ihtiyacı olan delegate'i ayarlar.
    if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}