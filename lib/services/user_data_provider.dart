// lib/services/user_data_provider.dart

import 'dart:async';
import 'package:bilgi_yarismasi/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class UserDataProvider with ChangeNotifier {
  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userModel; // O anki giriş yapmış kullanıcının bilgileri
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;

  UserModel? get userModel => _userModel;
  bool get isPro =>
      _userModel?.isPro ?? false; // PRO olup olmadığını hızlıca kontrol et

  UserDataProvider(this._authService) {
    // AuthService'deki değişiklikleri dinlemeye başla
    _authSubscription = _authService.authStateChanges.listen(
      _onAuthStateChanged,
    );
    _onAuthStateChanged(
      _authService.currentUser,
    ); // Başlangıç durumunu kontrol et
  }

  get ad => null;

  // Kullanıcı giriş/çıkış yaptığında tetiklenir
  void _onAuthStateChanged(User? user) {
    if (user != null) {
      // Kullanıcı GİRİŞ YAPTI
      // Firestore'daki belgesini dinlemeye başla
      _firestoreSubscription?.cancel(); // Önceki dinleyiciyi (varsa) iptal et
      _firestoreSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots() // <<< SNAPSHOTS (canlı dinleme)
          .listen((snapshot) {
            if (snapshot.exists) {
              _userModel = UserModel.fromFirestore(snapshot);
            } else {
              _userModel = null;
              print(
                "HATA: Kullanıcı giriş yaptı ama Firestore belgesi bulunamadı!",
              );
              // (AuthService'in belgeyi oluşturması beklenir)
            }
            notifyListeners(); // Değişikliği tüm uygulamaya bildir
          });
    } else {
      // Kullanıcı ÇIKIŞ YAPTI
      _userModel = null;
      _firestoreSubscription?.cancel(); // Firestore dinlemesini durdur
      notifyListeners(); // Değişikliği bildir
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
