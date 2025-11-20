// main.dart

import 'package:bilgi_yarismasi/screens/batch_upload.dart';
import 'package:bilgi_yarismasi/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:bilgi_yarismasi/screens/auth_wrapper.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:bilgi_yarismasi/services/theme_notifier.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/services/user_data_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:bilgi_yarismasi/services/ad_service.dart';
import 'package:bilgi_yarismasi/services/purchase_service.dart';
import 'package:bilgi_yarismasi/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Arka plan mesaj işleyicisi. Uygulama kapalıyken veya arka plandayken bildirim geldiğinde tetiklenir.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Arka plan mesajı alındı (messageId): ${message.messageId}");
  // Not: Arka planda UI güncellemesi yapılamaz.
}

void main() async {
  // Flutter binding'in başlatıldığından emin ol
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i başlat
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM arka plan işleyicisini tanıt
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Tarih formatlaması için Türkçe yerel ayarları başlat
  await initializeDateFormatting('tr_TR', null);

  // Google Mobile Ads'i başlat
  await MobileAds.instance.initialize();

  // Gerekli servislerin örneklerini oluştur
  final AuthService authService = AuthService();
  final AdService adService = AdService();
  adService.loadInterstitialAd();
  final PurchaseService purchaseService = PurchaseService();

  // --- BİLDİRİM SERVİSİ BAŞLATMA ---
  final NotificationService notificationService = NotificationService();
  await notificationService.initializeNotifications();
  await notificationService
      .requestPermissions(); // Tüm izinleri (yerel ve FCM) tek yerden iste
  // ---------------------------------

  // --- FCM KURULUMU ---
  // 1. Cihaz Token'ını Al
  final String? fcmToken = await FirebaseMessaging.instance.getToken();
  print("Firebase Cihaz Token: $fcmToken");
  // TODO: Bu token'ı, kullanıcı giriş yaptığında UserDataProvider'ınız aracılığıyla Firestore'daki kullanıcı belgesine kaydedin.

  // 2. Uygulama ÖN PLANDA iken gelen bildirimleri dinle
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('FCM: Ön planda bir mesaj alındı!');

    // Gelen mesajda bildirim verisi varsa, bunu yerel bildirim olarak göster
    if (message.notification != null) {
      print(
        'Mesajın bildirimi de var: ${message.notification?.title}, ${message.notification?.body}',
      );

      // ÖNEMLİ: Uygulama ön plandayken FCM bildirimi görünmez.
      // Bu yüzden bizim yerel bildirim servisimizi kullanarak manuel olarak gösteriyoruz.
      notificationService.showNotificationNow(
        id: DateTime.now().millisecondsSinceEpoch.remainder(
          100000,
        ), // Benzersiz bir ID oluştur
        title: message.notification?.title ?? 'Yeni Bildirim',
        body: message.notification?.body ?? '',
        payload: message.data.toString(), // Veriyi payload olarak ekle
      );
    }
  });

  // 3. Bildirime TIKLAYIP uygulama AÇILDIĞINDA (Arka plan veya kapalı durumdan)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('FCM: Bildirimden uygulama açıldı:');
    print('Mesaj Verisi: ${message.data}');
    // TODO: Gelen veriye ('data') göre kullanıcıyı ilgili sayfaya yönlendirin.
    // Örn: message.data['page'] == 'leaderboard' ise lider tablosu sayfasına git.
  });
  // --------------------

  // Veri yükleyici (Geliştirme aşamasında kullanılır, production'da yorum satırında olmalı)
  //final uploader = FirebaseDataUploader();
  //await uploader.uploadDataFromJson();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeNotifier()),
        ChangeNotifierProvider(
          create: (context) => UserDataProvider(authService),
        ),
        Provider<AuthService>(create: (_) => authService),
        ChangeNotifierProvider<AdService>(create: (_) => adService),
        ChangeNotifierProvider<PurchaseService>(create: (_) => purchaseService),
        Provider<NotificationService>(
          create: (_) => notificationService,
        ), // Servisi sağla
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'KPSS Sınav Arenası',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeNotifier.seedColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
          locale: const Locale('tr', 'TR'),
          home: const ConnectivityBanner(child: AuthWrapper()),
        );
      },
    );
  }
}
