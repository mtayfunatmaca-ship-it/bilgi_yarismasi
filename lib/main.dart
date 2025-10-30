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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('tr_TR', null);
  await MobileAds.instance.initialize();

  // Servisleri başlat
  final AuthService authService = AuthService();
  final AdService adService = AdService();
  adService.loadInterstitialAd(); // İlk reklamı yükle
  final PurchaseService purchaseService = PurchaseService();

  // Veri yükleyici (Yorumda olduğundan emin ol)
  //final uploader = FirebaseDataUploader();
 // await uploader.uploadDataFromJson();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeNotifier()),
        ChangeNotifierProvider(
          create: (context) => UserDataProvider(authService),
        ),
        Provider<AuthService>(
          // AuthService 'ChangeNotifier' değil, o yüzden 'Provider' kalmalı
          create: (_) => authService,
        ),

        // --- DÜZELTME BURADA ---
        // 'dispose:' parametresi kaldırıldı, çünkü ChangeNotifierProvider bunu otomatik yapar.
        ChangeNotifierProvider<AdService>(
          create: (_) => adService,
          // dispose: (_, adService) => adService.dispose(), // <<< BU SATIR HATA VERİYORDU, KALDIRILDI
        ),

        // 'dispose:' parametresi kaldırıldı
        ChangeNotifierProvider<PurchaseService>(
          create: (_) => purchaseService,
          // dispose: (_, purchaseService) => purchaseService.dispose(), // <<< BU SATIR HATA VERİYORDU, KALDIRILDI
        ),
        // --- DÜZELTME BİTTİ ---
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
          home: const ConnectivityBanner(child: AuthWrapper()),
        );
      },
    );
  }
}
