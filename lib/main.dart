// main.dart

import 'package:bilgi_yarismasi/screens/batch_upload.dart';
import 'package:bilgi_yarismasi/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('tr_TR', null);
  await MobileAds.instance.initialize();

  // Servisleri başlat
  final AuthService authService = AuthService();
  final AdService adService = AdService();
  adService.loadInterstitialAd();
  final PurchaseService purchaseService = PurchaseService();

  final NotificationService notificationService = NotificationService();
  await notificationService.initializeNotifications();
  await notificationService.requestPermissions();
  // -------------------------------------------------------------------

  // Veri yükleyici (Yorumda olduğundan emin ol)
  final uploader = FirebaseDataUploader();
  await uploader.uploadDataFromJson();

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

        Provider<NotificationService>(create: (_) => notificationService),
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
          title: 'Bilgi Yarışması',
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
