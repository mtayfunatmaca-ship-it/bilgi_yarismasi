import 'dart:io';
import 'dart:convert';
import 'package:bilgi_yarismasi/firebase_options.dart';
import 'package:flutter/material.dart'; // WidgetsFlutterBinding için
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  print('Batch yükleme/güncelleme (ID korumalı) scripti başladı...');

  try {
    // 1. JSON dosyasını oku
    final file = File('sorular.json');
    if (!await file.exists()) {
      print("HATA: 'sorular.json' dosyası bulunamadı.");
      return;
    }
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);

    // --- Kategorileri Yükle/Güncelle (SetOptions.merge ile) ---
    // (Bu kısım aynı kalabilir, ID'ler zaten JSON'dan geliyor)
    if (data['kategoriler'] != null && data['kategoriler'] is List) {
      print('Kategoriler işleniyor...');
      WriteBatch kategoriBatch = firestore.batch();
      int kategoriSayac = 0;
      for (var kategori in data['kategoriler']) {
        final kategoriId = kategori['id'];
        if (kategoriId != null && kategoriId is String) {
          final docRef = firestore.collection('categories').doc(kategoriId);
          kategoriBatch.set(docRef, {
            'ad': kategori['ad'],
            'sira': kategori['sira'],
          }, SetOptions(merge: true)); // merge=true ile mevcutları güncelle
          kategoriSayac++;
        }
      }
      await kategoriBatch.commit();
      print('-> $kategoriSayac kategori işlendi.');
    }

    // --- Quizleri ve Soruları Yükle/Güncelle (Custom ID ile) ---
    if (data['quizzes'] != null && data['quizzes'] is List) {
      print('Quizler ve sorular işleniyor...');
      int quizSayac = 0;
      int toplamSoruSayac = 0;

      for (var quiz in data['quizzes']) {
        final String? quizId = quiz['id']; // <<< JSON'dan ID'yi al
        final String? baslik = quiz['baslik'];
        final String? kategoriId = quiz['kategoriId'];
        final List? sorular = quiz['sorular'];

        // Gerekli alanlar var mı kontrol et
        if (quizId == null ||
            quizId.isEmpty ||
            baslik == null ||
            kategoriId == null) {
          print(
            ">> Uyarı: JSON'da ID, başlık veya kategoriId eksik olan quiz bulundu, atlanıyor.",
          );
          continue;
        }
        if (sorular == null || sorular.isEmpty) {
          print(
            ">> Uyarı: '$baslik' ($quizId) quizinde hiç soru yok, atlanıyor.",
          );
          continue;
        }

        print(' > İşleniyor: $baslik ($quizId)');
        quizSayac++;

        // 1. Quizi 'quizzes' koleksiyonuna ekle veya güncelle (set ile)
        final quizRef = firestore
            .collection('quizzes')
            .doc(quizId); // <<< Kendi ID'mizi kullan
        final quizData = {
          'baslik': baslik,
          'kategoriId': kategoriId,
          'soruSayisi': quiz['soruSayisi'], // JSON'daki sayıyı al
          'sureDakika': quiz['sureDakika'],
        };
        // merge: true -> Eğer JSON'da olmayan alanlar varsa (örn: oluşturulma tarihi) onları korur.
        await quizRef.set(quizData, SetOptions(merge: true));

        // --- ESKİ SORULARI SİLME ---
        print('   -> Önceki sorular siliniyor...');
        final questionsToDeleteQuery = await firestore
            .collection('questions')
            .where(
              'quizId',
              isEqualTo: quizId,
            ) // <<< Bu quiz ID'sine ait olanları bul
            .get();

        if (questionsToDeleteQuery.docs.isNotEmpty) {
          WriteBatch deleteBatch = firestore.batch();
          for (var doc in questionsToDeleteQuery.docs) {
            deleteBatch.delete(doc.reference);
          }
          await deleteBatch.commit();
          print(
            '   -> ${questionsToDeleteQuery.docs.length} eski soru silindi.',
          );
        } else {
          print('   -> Silinecek eski soru bulunamadı.');
        }
        // --- ESKİ SORULARI SİLME BİTTİ ---

        // --- YENİ SORULARI EKLEME ---
        print('   -> Yeni sorular ekleniyor...');
        WriteBatch questionBatch = firestore.batch();
        int buQuizSoruSayac = 0;
        for (var soru in sorular) {
          final String? soruMetni = soru['soruMetni'];
          final int? dogruCevapIndex = (soru['dogruCevapIndex'] as num?)
              ?.toInt();
          final List? secenekler = soru['secenekler'];

          if (soruMetni != null &&
              dogruCevapIndex != null &&
              secenekler != null &&
              secenekler.length >= 2) {
            final docRef = firestore
                .collection('questions')
                .doc(); // Sorulara otomatik ID verilebilir
            questionBatch.set(docRef, {
              'quizId': quizId, // <<< Quiz'in kendi ID'si ile bağla
              'soruMetni': soruMetni,
              'dogruCevapIndex': dogruCevapIndex,
              'secenekler': List<String>.from(
                secenekler.map((s) => s.toString()),
              ),
            });
            buQuizSoruSayac++;
          } else {
            print(
              "     >> Uyarı: '$baslik' quizinde eksik alanlı soru bulundu, atlanıyor.",
            );
          }
        }
        await questionBatch.commit();
        print('   -> $buQuizSoruSayac adet yeni soru eklendi.');
        toplamSoruSayac += buQuizSoruSayac;
        // --- YENİ SORULARI EKLEME BİTTİ ---
      } // Quiz döngüsü bitti
      print(
        '-> Toplam $quizSayac quiz ve $toplamSoruSayac soru işlendi (eklendi/güncellendi).',
      );
    } // if data['quizzes']

    print('✅ Tüm işlemler tamamlandı!');
  } catch (e, st) {
    print('❌ HATA OLUŞTU: $e');
    print('❌ STACK TRACE: $st');
  }
}
