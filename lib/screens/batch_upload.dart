import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDataUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timestamp? _parseDate(String? dateString) {
    if (dateString == null) return null;
    try {
      DateTime parsedDate = DateTime.parse(dateString);
      return Timestamp.fromDate(parsedDate);
    } catch (e) {
      // Hata raporlamasını daha belirgin hale getirdik
      print("Tarih formatı hatası: $dateString. Hata: $e");
      return null;
    }
  }

  Future<void> _updateQuestionsForQuiz(
    String id,
    List sorular, {
    required bool isTrial,
  }) async {
    final String idField = isTrial ? 'trialExamId' : 'quizId';

    // 1. ESKİ SORULARI SİLME
    print('   -> Önceki sorular siliniyor ($idField: $id)...');
    try {
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
    } catch (e) {
      print('   -> HATA: Eski sorular silinirken sorun oluştu: $e');
    }

    // 2. YENİ SORULARI EKLEME
    print('   -> Yeni sorular ekleniyor...');
    WriteBatch questionBatch = _firestore.batch();
    int buQuizSoruSayac = 0;
    try {
      for (var soru in sorular) {
        // Güvenli tip dönüşümleri eklendi
        final String? soruMetni = soru['soruMetni'] as String?;
        final int? dogruCevapIndex = (soru['dogruCevapIndex'] as num?)?.toInt();
        final List? secenekler = soru['secenekler'] as List?;
        final String? imageUrl = soru['imageUrl'] as String?;
        final String? kategoriId = soru['kategoriId'] as String?;
        final int? sira = (soru['sira'] as num?)?.toInt();

        if (soruMetni != null &&
            dogruCevapIndex != null &&
            secenekler != null &&
            secenekler.length >= 2) {
          final docRef = _firestore.collection('questions').doc();

          final Map<String, dynamic> soruData = {
            idField: id,
            'soruMetni': soruMetni,
            'dogruCevapIndex': dogruCevapIndex,
            // Seçeneklerin String listesi olduğundan emin ol
            'secenekler': List<String>.from(
              secenekler.map((s) => s.toString()),
            ),
            if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,

            if (isTrial && kategoriId != null && kategoriId.isNotEmpty)
              'kategoriId': kategoriId,
            if (isTrial && sira != null) 'sira': sira,
          };

          questionBatch.set(docRef, soruData);
          buQuizSoruSayac++;
        } else {
          print(
            "     >> Uyarı: '$id' için eksik alanlı soru bulundu, atlanıyor. Soru: ${soruMetni?.substring(0, 20)}...",
          );
        }
      }
      await questionBatch.commit();
      print('   -> $buQuizSoruSayac adet yeni soru eklendi.');
    } catch (e) {
      print(
        '   -> HATA: Yeni sorular eklenirken toplu işlemde sorun oluştu: $e',
      );
    }
  }

  // Ana Yükleme Fonksiyonu
  Future<void> uploadDataFromJson() async {
    print('--- Veri Yükleme Başlatılıyor (FirebaseDataUploader) ---');
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/sorular.json',
      );
      final data = json.decode(jsonString);

      // Kategoriler
      if (data['kategoriler'] is List) {
        print('Kategoriler işleniyor...');
        WriteBatch kategoriBatch = _firestore.batch();
        int kategoriSayac = 0;
        for (var kategori in data['kategoriler']) {
          final kategoriId = kategori['id'] as String?;
          if (kategoriId != null && kategoriId.isNotEmpty) {
            final docRef = _firestore.collection('categories').doc(kategoriId);
            kategoriBatch.set(docRef, {
              'ad': kategori['ad'] as String?,
              'sira': kategori['sira'] as num?,
            }, SetOptions(merge: true));
            kategoriSayac++;
          }
        }
        await kategoriBatch.commit();
        print('-> $kategoriSayac kategori işlendi.');
      } else {
        print("JSON'da 'kategoriler' bulunamadı veya liste değil.");
      }

      // Konu Başlıkları (Topics)
      if (data['konuBasliklari'] is List) {
        print('Konu Başlıkları (Topics) işleniyor...');
        WriteBatch topicBatch = _firestore.batch();
        int topicSayac = 0;
        for (var topic in data['konuBasliklari']) {
          final topicId = topic['id'] as String?;
          if (topicId != null && topicId.isNotEmpty) {
            final docRef = _firestore.collection('topics').doc(topicId);
            topicBatch.set(docRef, {
              'ad': topic['ad'] as String?,
              'kategoriId': topic['kategoriId'] as String?,
              'sira': topic['sira'] as num?,
            }, SetOptions(merge: true));
            topicSayac++;
          }
        }
        await topicBatch.commit();
        print('-> $topicSayac konu başlığı işlendi.');
      } else {
        print("JSON'da 'konuBasliklari' bulunamadı veya liste değil.");
      }

      // Normal Quizler (konuId ve isNew eklendi)
      if (data['quizzes'] is List) {
        print('Normal Quizler işleniyor...');
        int quizSayac = 0;
        for (var quiz in data['quizzes']) {
          final String? quizId = quiz['id'] as String?;
          final String? baslik = quiz['baslik'] as String?;
          final String? kategoriId = quiz['kategoriId'] as String?;
          final List? sorular = quiz['sorular'] as List?;

          if (quizId == null ||
              quizId.isEmpty ||
              baslik == null ||
              kategoriId == null ||
              sorular == null)
            continue;

          print(' > İşleniyor (Quiz): $baslik ($quizId)');
          quizSayac++;

          final quizRef = _firestore.collection('quizzes').doc(quizId);

          // Yeni alanları JSON'dan oku
          final String? konuId = quiz['konuId'] as String?;
          final bool isNew = quiz['isNew'] as bool? ?? false;

          final quizData = {
            'baslik': baslik,
            'kategoriId': kategoriId,
            'soruSayisi': quiz['soruSayisi'] as num?,
            'sureDakika': quiz['sureDakika'] as num?,
            'konuId': konuId,
            'isNew': isNew,
          };

          await quizRef.set(quizData, SetOptions(merge: true));
          await _updateQuestionsForQuiz(quizId, sorular, isTrial: false);
        }
        print('-> Toplam $quizSayac normal quiz işlendi.');
      } else {
        print("JSON'da 'quizzes' bulunamadı veya liste değil.");
      }

      // Deneme Sınavları
      if (data['trialExams'] is List) {
        print('Deneme Sınavları işleniyor...');
        int examSayac = 0;
        for (var exam in data['trialExams']) {
          final String? examId = exam['id'] as String?;
          final String? title = exam['title'] as String?;
          final List? sorular = exam['sorular'] as List?;

          if (examId == null ||
              examId.isEmpty ||
              title == null ||
              sorular == null)
            continue;

          print(' > İşleniyor (Deneme): $title ($examId)');
          examSayac++;
          final examRef = _firestore.collection('trialExams').doc(examId);

          // Null kontrolü ile güvenli hale getirildi
          final Timestamp? startTime = _parseDate(exam['startTime'] as String?);
          final Timestamp? endTime = _parseDate(exam['endTime'] as String?);

          if (startTime == null || endTime == null) {
            print(
              "   >> HATA: '$examId' için tarih formatı yanlış veya eksik. Atlanıyor.",
            );
            continue;
          }
          final bool isPro = exam['isPro'] as bool? ?? false;
          final bool isPublished = exam['isPublished'] as bool? ?? true;

          await examRef.set({
            'title': title,
            'description': exam['description'] as String?,
            'startTime': startTime,
            'endTime': endTime,
            'durationMinutes': exam['durationMinutes'] as num?,
            'questionCount': exam['questionCount'] as num?,
            'isMixedCategory': exam['isMixedCategory'] as bool? ?? false,
            'isPro': isPro,
            'isPublished': isPublished,
          }, SetOptions(merge: true));

          await _updateQuestionsForQuiz(examId, sorular, isTrial: true);
        }
        print('-> Toplam $examSayac deneme sınavı işlendi.');
      } else {
        print("JSON'da 'trialExams' bulunamadı veya liste değil.");
      }

      // Başarılar (Achievements)
      if (data['achievements'] is List) {
        print('Başarılar (Achievements) işleniyor...');
        WriteBatch achievementBatch = _firestore.batch();
        int achievementSayac = 0;
        for (var ach in data['achievements']) {
          final String? achId = ach['id'] as String?;
          if (achId == null || achId.isEmpty) {
            print(">> Uyarı: ID'si olmayan başarı bulundu, atlanıyor.");
            continue;
          }
          final docRef = _firestore.collection('achievements').doc(achId);
          Map<String, dynamic> achData = {
            'name': ach['name'] as String?,
            'description': ach['description'] as String?,
            'emoji': ach['emoji'] as String?,
            'criteria_type': ach['criteria_type'] as String?,
            'criteria_value': ach['criteria_value'] as num?,
            if (ach['criteria_category'] != null)
              'criteria_category': ach['criteria_category'] as String?,
          };
          achievementBatch.set(docRef, achData, SetOptions(merge: true));
          achievementSayac++;
        }
        await achievementBatch.commit();
        print('-> $achievementSayac başarı (achievement) işlendi.');
      } else {
        print("JSON'da 'achievements' listesi bulunamadı veya liste değil.");
      }

      print('✅ Veriler Firestore’a başarıyla yüklendi!');
    } catch (e, st) {
      print('❌ Veri yükleme hatası: $e');
      print('❌ STACK TRACE: $st');
    }
  }
}
