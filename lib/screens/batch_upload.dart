import 'dart:io';
import 'dart:convert';
import 'package:bilgi_yarismasi/firebase_options.dart';
import 'package:flutter/material.dart'; // Sadece WidgetsFlutterBinding için
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Bu, Flutter uygulamasını değil, sadece bir Dart scriptini çalıştırır.
Future<void> main() async {
  // --- Firebase'i Başlatma (main.dart'taki gibi) ---
  // Bu satır, 'dart run' ile çalışmak için gerekli
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // --- Başlatma Bitti ---

  final firestore = FirebaseFirestore.instance;

  print('Batch yükleme scripti başladı...');

  try {
    // 1. JSON dosyasını oku
    final file = File('sorular.json');
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);

    // --- Kategorileri Yükle ---
    // (Elle girdiklerinizi silip bununla yüklemek daha temiz olur)
    if (data['kategoriler'] != null) {
      print('Kategoriler yükleniyor...');
      for (var kategori in data['kategoriler']) {
        final kategoriId = kategori['id'];
        await firestore.collection('categories').doc(kategoriId).set({
          'ad': kategori['ad'],
          'sira': kategori['sira'],
        });
      }
      print('Kategoriler başarıyla yüklendi.');
    }

    // --- Quizleri ve Soruları Yükle ---
    if (data['quizzes'] != null) {
      print('Quizler ve Sorular yükleniyor...');
      for (var quiz in data['quizzes']) {
        // 2. Quiz verisini hazırla (sorular hariç)
        final quizData = {
          'baslik': quiz['baslik'],
          'kategoriId': quiz['kategoriId'],
          'soruSayisi': quiz['soruSayisi'],
          'sureDakika': quiz['sureDakika'],
        };

        // 3. Quizi 'quizzes' koleksiyonuna ekle (add kullanarak)
        final quizRef = await firestore.collection('quizzes').add(quizData);
        final newQuizId = quizRef.id; // Firestore'un verdiği yeni ID

        // Düzeltilmiş print satırı (Hata vermeyen doğru format)
        print(' > Quiz eklendi: ${quiz['baslik']} (ID: $newQuizId)');

        // 4. Bu quize ait soruları 'questions' koleksiyonuna ekle
        if (quiz['sorular'] != null) {
          for (var soru in quiz['sorular']) {
            final soruData = {
              'quizId': newQuizId, // Burası çok önemli: Quiz ID'sini bağlıyoruz
              'soruMetni': soru['soruMetni'],
              'dogruCevapIndex': soru['dogruCevapIndex'],
              'secenekler': List<String>.from(soru['secenekler']),
            };

            // Soruyu 'questions' koleksiyonuna ekle
            await firestore.collection('questions').add(soruData);
          }
          // Düzeltilmiş print satırı (Hata vermeyen doğru format)
          print('   >> ${quiz['sorular'].length} adet soru eklendi.');
        }
      }
      print('Quizler ve Sorular başarıyla yüklendi.');
    }

    print('Tüm işlemler tamamlandı! Scripti durdurabilirsiniz (Ctrl+C).');
  } catch (e) {
    print('HATA OLUŞTU: $e');
  }
}
