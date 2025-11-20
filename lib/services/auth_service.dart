import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // -------------------------------------------------------
  // 🔐 NONCE OLUŞTURMA (APPLE İÇİN GEREKLİ)
  // -------------------------------------------------------

  String _generateNonce([int length = 32]) {
    final charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // -------------------------------------------------------
  // 📌 E-POSTA İLE KAYIT
  // -------------------------------------------------------

  Future<String?> createUserWithEmailAndPassword(
    String email,
    String password, {
    required String ad,
    required String soyad,
    required String username,
  }) async {
    if (username.trim().isEmpty) return 'Kullanıcı adı boş olamaz.';
    if (ad.trim().isEmpty) return 'Ad alanı boş olamaz.';
    if (soyad.trim().isEmpty) return 'Soyad alanı boş olamaz.';

    try {
      final existingUser = await _firestore
          .collection('users')
          .where('kullaniciAdi', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        return 'Bu kullanıcı adı zaten alınmış.';
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'kullaniciAdi': username.trim(),
          'ad': ad.trim(),
          'soyad': soyad.trim(),
          'profilFotoUrl': '',
          'emoji': '🙂',
          'toplamPuan': 0,
          'kayitTarihi': FieldValue.serverTimestamp(),
          'isPro': false,
        });
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password')
        return 'Şifre çok zayıf. En az 6 karakter olmalıdır.';
      if (e.code == 'email-already-in-use')
        return 'Bu e-posta adresi zaten kullanılıyor.';
      if (e.code == 'invalid-email') return 'Geçersiz e-posta adresi formatı.';

      return 'Kayıt sırasında bir hata oluştu.';
    } catch (e) {
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  // -------------------------------------------------------
  // 📌 E-POSTA İLE GİRİŞ
  // -------------------------------------------------------

  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        return 'E-posta veya şifre hatalı.';
      }
      return 'Giriş yapılamadı.';
    } catch (e) {
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  // -------------------------------------------------------
  // 🔵 GOOGLE İLE GİRİŞ
  // -------------------------------------------------------

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google ile giriş iptal edildi.';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();

        if (!doc.exists) {
          String ad = 'Google';
          String soyad = 'Kullanıcısı';
          String kullaniciAdi =
              user.email?.split('@').first ?? 'kullanici_${user.uid}';

          if (user.displayName != null) {
            final parts = user.displayName!.split(' ');
            ad = parts.first;
            if (parts.length > 1) soyad = parts.sublist(1).join(' ');
          }

          await docRef.set({
            'email': user.email,
            'kullaniciAdi': kullaniciAdi,
            'ad': ad,
            'soyad': soyad,
            'profilFotoUrl': user.photoURL ?? '',
            'emoji': '🙂',
            'toplamPuan': 0,
            'kayitTarihi': FieldValue.serverTimestamp(),
            'isPro': false,
          });
        }
      }

      return null;
    } catch (e) {
      return 'Google ile giriş sırasında bir hata oluştu.';
    }
  }

  // -------------------------------------------------------
  // 🍎 APPLE İLE GİRİŞ — GÜNCEL, HATASIZ
  // -------------------------------------------------------

  // -------------------------------------------------------
  // 🍎 APPLE İLE GİRİŞ — 2025 GÜNCEL, accessToken EKLi
  // -------------------------------------------------------

  Future<String?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(
        rawNonce,
      ); // Hashed nonce Apple'a gönderilir

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Token kontrolleri
      if (appleCredential.identityToken == null) {
        return "Apple ID token alınamadı. Lütfen tekrar deneyin.";
      }
      if (appleCredential.authorizationCode == null) {
        return "Apple authorization code alınamadı. Lütfen tekrar deneyin.";
      }

      // Firebase credential: accessToken'ı authorizationCode olarak EKLE (kritik!)
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken!,
        rawNonce: rawNonce, // Raw (hashlenmemiş) nonce
        accessToken: appleCredential.authorizationCode!, // BU SATIR EKSİKTİ!
      );

      // Firebase sign-in
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(oauthCredential);
      final User? user = userCredential.user;
      if (user == null) return "Kullanıcı oluşturulamadı.";

      // Firestore kullanıcı kontrolü ve oluşturma (önceki kodundan kopyala)
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        String ad = "Apple";
        String soyad = "Kullanıcısı";
        String kullaniciAdi =
            user.email?.split('@').first ?? "apple_${user.uid.substring(0, 8)}";

        if (appleCredential.givenName != null &&
            appleCredential.familyName != null) {
          ad = appleCredential.givenName!;
          soyad = appleCredential.familyName!;
        } else if (user.displayName != null && user.displayName!.isNotEmpty) {
          final parts = user.displayName!.split(' ');
          ad = parts.first;
          if (parts.length > 1) soyad = parts.sublist(1).join(' ');
        }

        await docRef.set({
          'email': user.email ?? '',
          'kullaniciAdi': kullaniciAdi,
          'ad': ad,
          'soyad': soyad,
          'profilFotoUrl': user.photoURL ?? '',
          'emoji': '🙂',
          'toplamPuan': 0,
          'kayitTarihi': FieldValue.serverTimestamp(),
          'isPro': false,
          'provider': 'apple',
        });
      }

      return null; // Başarı
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return "Giriş iptal edildi.";
      }
      print("Apple Hatası: $e");
      return "Apple giriş hatası: ${e.message}";
    } on FirebaseAuthException catch (e) {
      print("Firebase Hatası: ${e.code} - ${e.message}");
      if (e.code == 'invalid-credential') {
        return "Geçersiz kimlik bilgisi. Config'i kontrol edin.";
      }
      return "Firebase hatası: ${e.message}";
    } catch (e) {
      print("Beklenmedik Hata: $e");
      return "Apple ile giriş yapılamadı.";
    }
  }
  // -------------------------------------------------------
  // 🚪 ÇIKIŞ
  // -------------------------------------------------------

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Çıkış hatası: $e");
    }
  }

  // -------------------------------------------------------
  // 🔄 ŞİFRE SIFIRLAMA
  // -------------------------------------------------------

  Future<String?> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) return "E-posta alanı boş olamaz.";

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return "Bu e-posta ile kayıtlı kullanıcı yok.";
      }
      return "Bir hata oluştu.";
    }
  }

  // -------------------------------------------------------
  // 🔐 ŞİFRE DEĞİŞTİRME
  // -------------------------------------------------------

  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentPassword.isEmpty || newPassword.isEmpty)
      return "Alanlar boş olamaz.";
    if (newPassword.length < 6) return "Yeni şifre en az 6 karakter olmalı.";

    User? user = _auth.currentUser;
    if (user == null || user.email == null) return "Kullanıcı bulunamadı.";

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential')
        return "Mevcut şifreniz hatalı.";
      return "Bir hata oluştu: ${e.message}";
    }
  }
}
