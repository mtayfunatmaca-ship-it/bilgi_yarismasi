import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDataUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadDataFromJson() async {
    // JSON dosyasını oku
    String jsonString = await rootBundle.loadString('assets/sorular.json');
    final data = json.decode(jsonString);

    // Kategorileri ekle
    List kategoriler = data['kategoriler'];
    for (var kategori in kategoriler) {
      await _firestore.collection('kategoriler').doc(kategori['id']).set({
        'ad': kategori['ad'],
        'sira': kategori['sira'],
      });
    }

    // Quizleri ekle
    List quizzes = data['quizzes'];
    for (var quiz in quizzes) {
      DocumentReference quizRef = await _firestore.collection('quizzes').add({
        'baslik': quiz['baslik'],
        'kategoriId': quiz['kategoriId'],
        'soruSayisi': quiz['soruSayisi'],
        'sureDakika': quiz['sureDakika'],
      });

      // Soruları alt koleksiyon olarak ekle
      List sorular = quiz['sorular'];
      for (var soru in sorular) {
        await quizRef.collection('sorular').add({
          'soruMetni': soru['soruMetni'],
          'dogruCevapIndex': soru['dogruCevapIndex'],
          'secenekler': soru['secenekler'],
        });
      }
    }

    print("✅ JSON verileri başarıyla Firestore’a aktarıldı!");
  }
}
