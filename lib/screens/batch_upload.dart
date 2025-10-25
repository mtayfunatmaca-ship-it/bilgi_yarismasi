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
      print("Tarih formatı hatası: $dateString. Hata: $e");
      return null;
    }
  }

  // --- BU FONKSİYON GÜNCELLENDİ (kategoriId ve sira eklendi) ---
  Future<void> _updateQuestionsForQuiz(String id, List sorular, {required bool isTrial}) async {
    final String idField = isTrial ? 'trialExamId' : 'quizId';
    
    // 1. ESKİ SORULARI SİLME
    print('   -> Önceki sorular siliniyor ($idField: $id)...');
    final questionsToDeleteQuery = await _firestore.collection('questions').where(idField, isEqualTo: id).get();
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
      
      // --- YENİ ALANLARI OKU ---
      final String? kategoriId = soru['kategoriId'] as String?;
      final int? sira = (soru['sira'] as num?)?.toInt();
      // --- BİTTİ ---

      if (soruMetni != null && dogruCevapIndex != null && secenekler != null && secenekler.length >= 2) {
        final docRef = _firestore.collection('questions').doc();
        
        final Map<String, dynamic> soruData = {
          idField: id, 
          'soruMetni': soruMetni,
          'dogruCevapIndex': dogruCevapIndex,
          'secenekler': List<String>.from(secenekler.map((s) => s.toString())),
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          
          // --- YENİ ALANLARI EKLE ---
          // Eğer bu bir deneme sınavıysa (isTrial), kategori ve sıra bilgilerini de ekle
          if (isTrial && kategoriId != null && kategoriId.isNotEmpty)
             'kategoriId': kategoriId,
          if (isTrial && sira != null)
             'sira': sira,
          // --- BİTTİ ---
        };
        
        questionBatch.set(docRef, soruData);
        buQuizSoruSayac++;
      } else {
        print("     >> Uyarı: '$id' için eksik alanlı soru bulundu, atlanıyor.");
      }
    }
    await questionBatch.commit();
    print('   -> $buQuizSoruSayac adet yeni soru eklendi.');
  }
  // --- GÜNCELLEME BİTTİ ---


  // Ana Yükleme Fonksiyonu (Tamamı)
  Future<void> uploadDataFromJson() async {
    print('--- Veri Yükleme Başlatılıyor (FirebaseDataUploader) ---');
    try {
      final String jsonString = await rootBundle.loadString('assets/sorular.json');
      final data = json.decode(jsonString);

      // Kategoriler
      if (data['kategoriler'] != null && data['kategoriler'] is List) {
        print('Kategoriler işleniyor...');
        WriteBatch kategoriBatch = _firestore.batch();
        int kategoriSayac = 0;
        for (var kategori in data['kategoriler']) {
          final kategoriId = kategori['id'];
          if (kategoriId != null && kategoriId is String) {
            final docRef = _firestore.collection('categories').doc(kategoriId);
            kategoriBatch.set(docRef, { 'ad': kategori['ad'], 'sira': kategori['sira'] }, SetOptions(merge: true));
            kategoriSayac++;
          }
        }
        await kategoriBatch.commit();
        print('-> $kategoriSayac kategori işlendi.');
      } else { print("JSON'da 'kategoriler' bulunamadı."); }

      // Normal Quizler
      if (data['quizzes'] != null && data['quizzes'] is List) {
        print('Normal Quizler işleniyor...');
        int quizSayac = 0;
        for (var quiz in data['quizzes']) {
          final String? quizId = quiz['id'];
          if (quizId == null || quiz['baslik'] == null || quiz['kategoriId'] == null || quiz['sorular'] == null) continue;
          print(' > İşleniyor (Quiz): ${quiz['baslik']} ($quizId)');
          quizSayac++;
          final quizRef = _firestore.collection('quizzes').doc(quizId);
          final quizData = { 'baslik': quiz['baslik'], 'kategoriId': quiz['kategoriId'], 'soruSayisi': quiz['soruSayisi'], 'sureDakika': quiz['sureDakika'] };
          await quizRef.set(quizData, SetOptions(merge: true));
          await _updateQuestionsForQuiz(quizId, quiz['sorular'] ?? [], isTrial: false);
        }
        print('-> Toplam $quizSayac normal quiz işlendi.');
      } else { print("JSON'da 'quizzes' bulunamadı."); }

      // Deneme Sınavları
      if (data['trialExams'] != null && data['trialExams'] is List) {
        print('Deneme Sınavları işleniyor...');
        int examSayac = 0;
        for (var exam in data['trialExams']) {
          final String? examId = exam['id'];
          if (examId == null || exam['title'] == null || exam['sorular'] == null) continue;
          print(' > İşleniyor (Deneme): ${exam['title']} ($examId)');
          examSayac++;
          final examRef = _firestore.collection('trialExams').doc(examId);
          final Timestamp? startTime = _parseDate(exam['startTime']);
          final Timestamp? endTime = _parseDate(exam['endTime']);
          if (startTime == null || endTime == null) {
              print("   >> HATA: '$examId' için tarih formatı yanlış. Atlanıyor.");
              continue;
          }
          await examRef.set({
            'title': exam['title'], 'description': exam['description'],
            'startTime': startTime, 'endTime': endTime,
            'durationMinutes': exam['durationMinutes'], 'questionCount': exam['questionCount'],
            'isMixedCategory': exam['isMixedCategory'] ?? false,
          }, SetOptions(merge: true));
          
          // _updateQuestionsForQuiz fonksiyonu artık 'kategoriId' ve 'sira'yı da yüklüyor
          await _updateQuestionsForQuiz(examId, exam['sorular'] ?? [], isTrial: true);
        }
        print('-> Toplam $examSayac deneme sınavı işlendi.');
      } else { print("JSON'da 'trialExams' bulunamadı."); }

      // Başarılar (Achievements)
      if (data['achievements'] != null && data['achievements'] is List) {
        print('Başarılar (Achievements) işleniyor...');
        WriteBatch achievementBatch = _firestore.batch();
        int achievementSayac = 0;
        for (var ach in data['achievements']) {
          final String? achId = ach['id'];
          if (achId == null || achId.isEmpty) { print(">> Uyarı: ID'si olmayan başarı bulundu, atlanıyor."); continue; }
          final docRef = _firestore.collection('achievements').doc(achId);
          Map<String, dynamic> achData = {
             'name': ach['name'], 'description': ach['description'], 'emoji': ach['emoji'],
             'criteria_type': ach['criteria_type'], 'criteria_value': ach['criteria_value'],
             if (ach['criteria_category'] != null) 'criteria_category': ach['criteria_category'],
          };
          achievementBatch.set(docRef, achData, SetOptions(merge: true)); 
          achievementSayac++;
        }
        await achievementBatch.commit();
        print('-> $achievementSayac başarı (achievement) işlendi.');
      } else { print("JSON'da 'achievements' listesi bulunamadı."); }

      print('✅ Veriler Firestore’a başarıyla yüklendi!');
    } catch (e, st) {
      print('❌ Veri yükleme hatası: $e');
      print('❌ STACK TRACE: $st');
    }
  }
}