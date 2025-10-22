import 'package:bilgi_yarismasi/screens/batch_upload.dart';
import 'package:bilgi_yarismasi/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:bilgi_yarismasi/screens/auth_wrapper.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart'; // <<< YENİ IMPORT
import 'package:bilgi_yarismasi/services/theme_notifier.dart'; // <<< YENİ IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('tr_TR', null);

  // Yorum satırları (doğru)
  //final uploader = FirebaseDataUploader();
  //await uploader.uploadDataFromJson();

  // --- DEĞİŞİKLİK: Uygulamayı ThemeNotifier ile sarmala ---
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeNotifier(), // ThemeNotifier'ı oluştur
      child: const MyApp(), // Uygulamanı onun içine yerleştir
    ),
  );
  // --- DEĞİŞİKLİK BİTTİ ---
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- DEĞİŞİKLİK: Rengi ThemeNotifier'dan dinle ---
    // Consumer widget'ı, ThemeNotifier'daki değişiklikleri dinler
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        // themeNotifier.seedColor, o anki seçili rengi verir
        return MaterialApp(
          title: 'Bilgi Yarışması',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            // seedColor'u artık hardcoded değil, notifier'dan alıyoruz
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeNotifier.seedColor, // <<< DİNAMİK RENK
            ),
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // AuthWrapper'ı ConnectivityBanner ile sarmalamak (önceki kodunuzdaki gibi)
          home: const ConnectivityBanner(child: AuthWrapper()),
        );
      },
    );
    // --- DEĞİŞİKLİK BİTTİ ---
  }
}
