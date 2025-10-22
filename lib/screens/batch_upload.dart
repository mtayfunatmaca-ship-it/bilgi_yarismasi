import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDataUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- YENİ YARDIMCI FONKSİYON: String tarihi Timestamp'e çevirir ---
  Timestamp? _parseDate(String? dateString) {
    if (dateString == null) return null;
    try {
      // ISO 8601 formatını (örn: "2025-10-23T10:00:00+03:00") parse et
      DateTime parsedDate = DateTime.parse(dateString);
      return Timestamp.fromDate(parsedDate);
    } catch (e) {
      print("Tarih formatı hatası: $dateString. Hata: $e");
      return null;
    }
  }

  // --- YENİ YARDIMCI FONKSİYON: Soruları Silip Yeniden Ekler ---
  // (Hem normal quiz hem de deneme sınavı için çalışır)
  Future<void> _updateQuestionsForQuiz(
    String id,
    List sorular, {
    required bool isTrial,
  }) async {
    // 'isTrial' bayrağına göre hangi alanda arama yapacağımızı seçiyoruz
    final String idField = isTrial ? 'trialExamId' : 'quizId';

    // 1. ESKİ SORULARI SİLME
    print('   -> Önceki sorular siliniyor ($idField: $id)...');
    final questionsToDeleteQuery = await _firestore
        .collection('questions')
        .where(idField, isEqualTo: id)
        .get();

    if (questionsToDeleteQuery.docs.isNotEmpty) {
      WriteBatch deleteBatch = _firestore.batch();
      for (var doc in questionsToDeleteQuery.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
      print('   -> ${questionsToDeleteQuery.docs.length} eski soru silindi.');
    } else {
      print('   -> Silinecek eski soru bulunamadı.');
    }

    // 2. YENİ SORULARI EKLEME
    print('   -> Yeni sorular ekleniyor...');
    WriteBatch questionBatch = _firestore.batch();
    int buQuizSoruSayac = 0;
    for (var soru in sorular) {
      final String? soruMetni = soru['soruMetni'];
      final int? dogruCevapIndex = (soru['dogruCevapIndex'] as num?)?.toInt();
      final List? secenekler = soru['secenekler'];
      final String? imageUrl = soru['imageUrl'] as String?;

      if (soruMetni != null &&
          dogruCevapIndex != null &&
          secenekler != null &&
          secenekler.length >= 2) {
        final docRef = _firestore.collection('questions').doc();

        final Map<String, dynamic> soruData = {
          // 'quizId' veya 'trialExamId' olarak doğru alanı ekle
          idField: id,
          'soruMetni': soruMetni,
          'dogruCevapIndex': dogruCevapIndex,
          'secenekler': List<String>.from(secenekler.map((s) => s.toString())),
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        };

        questionBatch.set(docRef, soruData);
        buQuizSoruSayac++;
      } else {
        print(
          "     >> Uyarı: '$id' için eksik alanlı soru bulundu, atlanıyor.",
        );
      }
    }
    await questionBatch.commit();
    print('   -> $buQuizSoruSayac adet yeni soru eklendi.');
  }
  // --- YARDIMCI FONKSİYONLAR BİTTİ ---

  // Ana Yükleme Fonksiyonu
  Future<void> uploadDataFromJson() async {
    print('--- Veri Yükleme Başlatılıyor (FirebaseDataUploader) ---');

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
            }, SetOptions(merge: true));
            kategoriSayac++;
          }
        }
        await kategoriBatch.commit();
        print('-> $kategoriSayac kategori işlendi.');
      } else {
        print("JSON'da 'kategoriler' bulunamadı.");
      }

      // --- Normal Quizleri Yükle/Güncelle (Custom ID ile) ---
      if (data['quizzes'] != null && data['quizzes'] is List) {
        print('Normal Quizler işleniyor...');
        int quizSayac = 0;
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
              ">> Uyarı: JSON'da ID, başlık veya kategoriId eksik (Quiz), atlanıyor.",
            );
            continue;
          }
          if (sorular == null || sorular.isEmpty) {
            print(
              ">> Uyarı: '$baslik' ($quizId) quizinde soru yok, atlanıyor.",
            );
            continue;
          }

          print(' > İşleniyor (Quiz): $baslik ($quizId)');
          quizSayac++;

          final quizRef = _firestore.collection('quizzes').doc(quizId);
          final quizData = {
            'baslik': baslik,
            'kategoriId': kategoriId,
            'soruSayisi': quiz['soruSayisi'],
            'sureDakika': quiz['sureDakika'],
          };
          await quizRef.set(quizData, SetOptions(merge: true));

          // Sorularını yardımcı fonksiyonla güncelle
          await _updateQuestionsForQuiz(quizId, sorular, isTrial: false);
        } // Quiz döngüsü bitti
        print('-> Toplam $quizSayac normal quiz işlendi.');
      } else {
        print("JSON'da 'quizzes' bulunamadı.");
      }

      // --- YENİ BÖLÜM: Deneme Sınavlarını (TrialExams) Yükle/Güncelle ---
      if (data['trialExams'] != null && data['trialExams'] is List) {
        print('Deneme Sınavları işleniyor...');
        int examSayac = 0;
        for (var exam in data['trialExams']) {
          final String? examId = exam['id'];
          final String? title = exam['title'];
          final List? sorular = exam['sorular'];

          if (examId == null || examId.isEmpty || title == null) {
            print(
              ">> Uyarı: JSON'da ID veya title eksik (Deneme Sınavı), atlanıyor.",
            );
            continue;
          }
          if (sorular == null || sorular.isEmpty) {
            print(
              ">> Uyarı: '$title' ($examId) denemesinde soru yok, atlanıyor.",
            );
            continue;
          }

          print(' > İşleniyor (Deneme): $title ($examId)');
          examSayac++;

          final examRef = _firestore.collection('trialExams').doc(examId);

          // JSON'daki String tarihleri Firestore Timestamp'e çevir
          final Timestamp? startTime = _parseDate(exam['startTime']);
          final Timestamp? endTime = _parseDate(exam['endTime']);

          if (startTime == null || endTime == null) {
            print(
              "   >> HATA: '$examId' için startTime veya endTime formatı yanlış (örn: 2025-10-25T14:00:00+03:00). Atlanıyor.",
            );
            continue;
          }

          await examRef.set({
            'title': title,
            'description': exam['description'],
            'startTime': startTime,
            'endTime': endTime,
            'durationMinutes': exam['durationMinutes'],
            'questionCount': exam['questionCount'],
            'isMixedCategory': exam['isMixedCategory'] ?? false,
          }, SetOptions(merge: true));

          // Sorularını yardımcı fonksiyonla güncelle
          await _updateQuestionsForQuiz(examId, sorular, isTrial: true);
        } // Deneme döngüsü bitti
        print('-> Toplam $examSayac deneme sınavı işlendi.');
      } else {
        print("JSON'da 'trialExams' bulunamadı.");
      }
      // --- YENİ BÖLÜM BİTTİ ---

      print('✅ Veriler Firestore’a başarıyla yüklendi!');
    } catch (e, st) {
      print('❌ Veri yükleme hatası: $e');
      print('❌ STACK TRACE: $st');
    }
  }
}
