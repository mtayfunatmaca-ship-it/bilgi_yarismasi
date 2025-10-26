// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String kullaniciAdi;
  final String ad;
  final String soyad;
  final String emoji;
  final int toplamPuan;
  final bool isPro;

  // Adı veya Ad Soyadı birleşik gösteren yardımcı bir 'getter'
  String get displayName => (ad.isNotEmpty) ? ad : kullaniciAdi;
  String get fullName => (ad.isNotEmpty || soyad.isNotEmpty) ? '$ad $soyad' : kullaniciAdi;


  UserModel({
    required this.uid,
    required this.email,
    required this.kullaniciAdi,
    required this.ad,
    required this.soyad,
    required this.emoji,
    required this.toplamPuan,
    required this.isPro,
  });

  // Firestore belgesini (DocumentSnapshot) UserModel nesnesine dönüştürür
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      kullaniciAdi: data['kullaniciAdi'] ?? '',
      ad: data['ad'] ?? '',
      soyad: data['soyad'] ?? '',
      emoji: data['emoji'] ?? '🙂',
      toplamPuan: (data['toplamPuan'] as num? ?? 0).toInt(),
      isPro: data['isPro'] ?? false, // <<< ÖNEMLİ
    );
  }
}