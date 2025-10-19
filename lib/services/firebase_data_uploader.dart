import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDataUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadDataFromJson() async {
    // ❗ ÖNEMLİ KONTROL 1: pubspec.yaml dosyanızda assets klasörünün tanımlı olduğundan emin olun:
    // flutter:
    //   uses-material-design: true
    //   assets:
    //     - assets/
    // ❗ ÖNEMLİ KONTROL 2: Projenizin ana dizininde 'assets' adında bir klasör
    //    ve içinde 'sorular.json' dosyasının bulunduğundan emin olun.

    try {
      print("--- Veri Yükleme Başlatılıyor (FirebaseDataUploader) ---");
      String jsonString = await rootBundle.loadString('assets/sorular.json');
      final data = json.decode(jsonString);

      // --- Kategorileri Yükle (Doğru Koleksiyon Adıyla) ---
      List kategoriler = data['kategoriler'] ?? [];
      if (kategoriler.isNotEmpty) {
        print("Kategoriler yükleniyor...");
        WriteBatch batch = _firestore
            .batch(); // Tek seferde yazmak için Batch kullanmak daha verimli
        for (var kategori in kategoriler) {
          // ❗ DÜZELTME: Koleksiyon adı 'categories' olarak değiştirildi
          DocumentReference docRef = _firestore
              .collection('categories')
              .doc(kategori['id']);
          batch.set(docRef, {'ad': kategori['ad'], 'sira': kategori['sira']});
        }
        await batch.commit(); // Tüm kategorileri tek seferde yaz
        print("  -> ${kategoriler.length} kategori yüklendi.");
      } else {
        print("JSON dosyasında 'kategoriler' bulunamadı veya boş.");
      }

      // --- Quizleri ve Soruları Yükle (Doğru Soru Yapısıyla) ---
      List quizzes = data['quizzes'] ?? [];
      if (quizzes.isNotEmpty) {
        print("Quizler ve Sorular yükleniyor...");
        for (var quiz in quizzes) {
          // 1. Quizi 'quizzes' koleksiyonuna ekle
          DocumentReference quizRef = await _firestore
              .collection('quizzes')
              .add({
                'baslik': quiz['baslik'],
                'kategoriId': quiz['kategoriId'],
                'soruSayisi': quiz['soruSayisi'],
                'sureDakika': quiz['sureDakika'],
              });
          final newQuizId = quizRef.id; // Yeni eklenen quiz'in ID'si
          print("  -> Quiz eklendi: ${quiz['baslik']} (ID: $newQuizId)");

          // 2. Soruları ANA 'questions' koleksiyonuna ekle
          List sorular = quiz['sorular'] ?? [];
          if (sorular.isNotEmpty) {
            WriteBatch questionBatch = _firestore.batch();
            int soruSayaci = 0;
            for (var soru in sorular) {
              // ❗ DÜZELTME: Soruları ana 'questions' koleksiyonuna ekle
              DocumentReference questionRef = _firestore
                  .collection('questions')
                  .doc(); // Otomatik ID al
              questionBatch.set(questionRef, {
                'quizId':
                    newQuizId, // ❗ DÜZELTME: Hangi quiz'e ait olduğunu belirt
                'soruMetni': soru['soruMetni'],
                'dogruCevapIndex': soru['dogruCevapIndex'],
                'secenekler': List<String>.from(soru['secenekler'] ?? []),
              });
              soruSayaci++;
            }
            await questionBatch
                .commit(); // Bu quiz'in tüm sorularını tek seferde yaz
            print(
              "     -> $soruSayaci soru 'questions' koleksiyonuna eklendi.",
            );
          }
        }
      } else {
        print("JSON dosyasında 'quizzes' bulunamadı veya boş.");
      }

      print("✅ Veriler Firestore’a başarıyla yüklendi!");
    } catch (e, st) {
      print("❌ Veri yükleme hatası: $e");
      print(
        "❌ Stack Trace: $st",
      ); // Hatanın nerede olduğunu görmek için Stack Trace
    }
  }
}
