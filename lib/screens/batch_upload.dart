import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDataUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadDataFromJson() async {
    print('--- Veri Yükleme Başlatılıyor (main.dart üzerinden) ---');

    try {
      // 1. JSON dosyasını 'assets' klasöründen oku
      final String jsonString = await rootBundle.loadString(
        'assets/sorular.json',
      );
      final data = json.decode(jsonString);

      // --- Kategorileri Yükle/Güncelle ---
      if (data['kategoriler'] != null && data['kategoriler'] is List) {
        print('Kategoriler işleniyor...');
        WriteBatch kategoriBatch = _firestore.batch();
        int kategoriSayac = 0;
        for (var kategori in data['kategoriler']) {
          final kategoriId = kategori['id'];
          if (kategoriId != null && kategoriId is String) {
            final docRef = _firestore.collection('categories').doc(kategoriId);
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
          final String? quizId = quiz['id'];
          final String? baslik = quiz['baslik'];
          final String? kategoriId = quiz['kategoriId'];
          final List? sorular = quiz['sorular'];

          if (quizId == null ||
              quizId.isEmpty ||
              baslik == null ||
              kategoriId == null) {
            print(
              ">> Uyarı: JSON'da ID, başlık veya kategoriId eksik, atlanıyor.",
            );
            continue;
          }
          if (sorular == null || sorular.isEmpty) {
            print(
              ">> Uyarı: '$baslik' ($quizId) quizinde soru yok, atlanıyor.",
            );
            continue;
          }

          print(' > İşleniyor: $baslik ($quizId)');
          quizSayac++;

          // 1. Quizi 'quizzes' koleksiyonuna ekle/güncelle
          final quizRef = _firestore.collection('quizzes').doc(quizId);
          final quizData = {
            'baslik': baslik,
            'kategoriId': kategoriId,
            'soruSayisi': quiz['soruSayisi'],
            'sureDakika': quiz['sureDakika'],
          };
          await quizRef.set(quizData, SetOptions(merge: true));

          // 2. ESKİ SORULARI SİLME
          print('   -> Önceki sorular siliniyor...');
          final questionsToDeleteQuery = await _firestore
              .collection('questions')
              .where('quizId', isEqualTo: quizId)
              .get();
          if (questionsToDeleteQuery.docs.isNotEmpty) {
            WriteBatch deleteBatch = _firestore.batch();
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

          // 3. YENİ SORULARI EKLEME
          print('   -> Yeni sorular ekleniyor...');
          WriteBatch questionBatch = _firestore.batch();
          int buQuizSoruSayac = 0;
          for (var soru in sorular) {
            final String? soruMetni = soru['soruMetni'];
            final int? dogruCevapIndex = (soru['dogruCevapIndex'] as num?)
                ?.toInt();
            final List? secenekler = soru['secenekler'];
            final String? imageUrl =
                soru['imageUrl'] as String?; // imageUrl'u oku

            if (soruMetni != null &&
                dogruCevapIndex != null &&
                secenekler != null &&
                secenekler.length >= 2) {
              final docRef = _firestore.collection('questions').doc();
              final Map<String, dynamic> soruData = {
                'quizId': quizId,
                'soruMetni': soruMetni,
                'dogruCevapIndex': dogruCevapIndex,
                'secenekler': List<String>.from(
                  secenekler.map((s) => s.toString()),
                ),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  'imageUrl': imageUrl, // imageUrl'u ekle
              };
              questionBatch.set(docRef, soruData);
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
        }
        print('-> Toplam $quizSayac quiz ve $toplamSoruSayac soru işlendi.');
      }
      print('✅ Veriler Firestore’a başarıyla yüklendi!');
    } catch (e, st) {
      print('❌ Veri yükleme hatası: $e');
      print('❌ STACK TRACE: $st');
    }
  }
}
