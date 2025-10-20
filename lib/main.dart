import 'package:bilgi_yarismasi/services/firebase_data_uploader.dart';
import 'package:bilgi_yarismasi/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:bilgi_yarismasi/screens/auth_wrapper.dart';
import 'package:intl/date_symbol_data_local.dart'; // <<< YENİ IMPORT EKLENDİ

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- YENİ EKLENEN KISIM: 'intl' paketini başlat ---
  // Uygulamanızda tarih formatlaması kullanmak için bu gereklidir.
  // 'tr_TR' Türkçe formatlama içindir.
  await initializeDateFormatting('tr_TR', null);
  // --- YENİ EKLENEN KISIM BİTTİ ---

  // FirebaseDataUploader yorumda kalmalı, bu doğru.
  //final uploader = FirebaseDataUploader();
  //await uploader.uploadDataFromJson();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bilgi Yarışması',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Ekstra İyileştirme: Modern Flutter için colorScheme kullanmak daha iyidir.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // Modern Material 3 tasarımını etkinleştirir.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ConnectivityBanner(child: AuthWrapper()),
    );
  }
}
