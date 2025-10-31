// notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'dart:async';
import 'dart:io';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 1. Bildirim sistemini başlatır
  Future<void> initializeNotifications() async {
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
      android: AndroidInitializationSettings('@drawable/app_notification_icon'),
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // onDidReceiveNotificationResponse (eğer gerekiyorsa) buraya eklenebilir
    );

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul')); 
  }
  
  // 4. İzin İsteklerini Yönetir (Yeni Metot)
  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true, 
              badge: true, 
              sound: true,
            );
    } else if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation = 
            flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
            // Android 13+ için bildirim izni istenir
            await androidImplementation.requestNotificationsPermission();
            
            // Kesin Alarm İzni istenir (AndroidManifest'te izinlerin olması şartıyla)
            try {
                 await androidImplementation.requestExactAlarmsPermission();
            } catch (e) {
                 print("requestExactAlarmsPermission metodu bulunamadı veya hata verdi: $e");
            }
        }
    }
  }
  Future<bool?> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation = 
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        // Bu metodun da eski versiyonlarda olmama ihtimali var. Hata verirse kaldırılmalıdır.
        try {
           final bool? granted = await androidImplementation.requestExactAlarmsPermission();
           return granted;
        } catch (e) {
           print("requestExactAlarmsPermission metodu bulunamadı veya hata verdi: $e");
           // Metot yoksa, izin için AndroidManifest'e güveniyoruz.
           return false;
        }
      }
    }
    return true; 
  }


  // 2. Belirli bir zamanda tetiklenecek bildirim planlar
  Future<void> scheduleExamNotification({
    required String examId,
    required String title,
    required String body,
    required DateTime scheduledTime, 
  }) async {
    final int notificationId = examId.hashCode.abs();
    
    // Gelen DateTime'ı Yerel TZDateTime formatına dönüştür
    final DateTime localTime = scheduledTime.isUtc 
        ? scheduledTime.toLocal()
        : scheduledTime;

    final tz.TZDateTime finalNotificationTime = tz.TZDateTime.from(localTime, tz.local); 
    
    // Geçmiş zaman kontrolü
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    if (finalNotificationTime.isBefore(now.add(const Duration(seconds: 10)))) {
      print("Bildirim zamanı geçmişte veya çok yakında. Planlama iptal edildi.");
      return; 
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'exam_channel_id',
      'Sınav Zamanı Hatırlatıcıları',
      channelDescription: 'Deneme sınavı başlangıç hatırlatmaları',
      importance: Importance.max, 
      priority: Priority.max,   
      ticker: 'Sınav Başladı!',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      finalNotificationTime, 
      platformDetails,
      
      // 🔔 KRİTİK DÜZELTME: Zorunlu olan 'androidScheduleMode' eklendi.
      androidScheduleMode: AndroidScheduleMode.exact, 
      
      payload: examId,
    );
    print("✅ Bildirim planlandı: ID $notificationId, Zaman: ${finalNotificationTime.toLocal()}");
  }
  
  // 3. Planlanmış bir bildirimi iptal eder
  Future<void> cancelExamNotification(String examId) async {
    final int notificationId = examId.hashCode.abs();
    await flutterLocalNotificationsPlugin.cancel(notificationId);
    print("Bildirim iptal edildi: ID $notificationId");
  }
  
  // Kullanılmadığı için requestIOSPermissions kaldırıldı, yerine requestPermissions kullanılıyor.
}