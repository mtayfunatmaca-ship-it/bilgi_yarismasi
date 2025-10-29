import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // --- E-POSTA İLE KAYIT (GÜNCELLENDİ) ---
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
          'isPro': false, // <<< YENİ ALAN EKLENDİ
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password')
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      else if (e.code == 'email-already-in-use')
        return 'Bu e-posta adresi zaten kullanılıyor.';
      else if (e.code == 'invalid-email')
        return 'Geçersiz e-posta adresi formatı.';
      return 'Kayıt sırasında bir hata oluştu.';
    } catch (e) {
      print('Bilinmeyen Kayıt Hatası: $e');
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  // --- E-POSTA İLE GİRİŞ (Aynı) ---
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
          e.code == 'invalid-credential')
        return 'E-posta veya şifre hatalı.';
      return 'Giriş yapılamadı.';
    } catch (e) {
      print('Bilinmeyen Giriş Hatası: $e');
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  // --- GOOGLE İLE GİRİŞ (GÜNCELLENDİ) ---
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google ile giriş iptal edildi.';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();
        if (!doc.exists) {
          String ad = 'Google Kullanıcısı';
          String soyad = '';
          String kullaniciAdi =
              user.email?.split('@').first ??
              'kullanici_${user.uid.substring(0, 5)}';

          if (user.displayName != null && user.displayName!.isNotEmpty) {
            final parts = user.displayName!.split(' ');
            if (parts.isNotEmpty) {
              ad = parts.first;
              if (parts.length > 1) soyad = parts.sublist(1).join(' ');
            }
          }

          final existingUser = await _firestore
              .collection('users')
              .where('kullaniciAdi', isEqualTo: kullaniciAdi)
              .limit(1)
              .get();
          if (existingUser.docs.isNotEmpty) {
            kullaniciAdi = '${kullaniciAdi}_${user.uid.substring(0, 4)}';
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
            'isPro': false, // <<< YENİ ALAN EKLENDİ
          });
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential')
        return 'Bu e-posta ile farklı bir yöntemle (örn: şifre) hesap oluşturulmuş.';
      return 'Google ile giriş sırasında bir hata oluştu.';
    } catch (e) {
      print('Bilinmeyen Google Giriş Hatası: $e');
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  // --- ÇIKIŞ YAP (Aynı) ---
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Çıkış yaparken hata: $e");
    }
  }

  // --- ŞİFRE SIFIRLAMA (Aynı) ---
  Future<String?> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) return "E-posta alanı boş olamaz.";
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email')
        return 'Bu e-posta adresi ile kayıtlı bir kullanıcı bulunamadı.';
      return 'Bir hata oluştu, lütfen tekrar deneyin.';
    } catch (e) {
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  // --- ŞİFRE DEĞİŞTİRME (Aynı) ---
  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentPassword.isEmpty || newPassword.isEmpty)
      return "Alanlar boş olamaz.";
    if (newPassword.length < 6) return "Yeni şifre en az 6 karakter olmalıdır.";

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
      else if (e.code == 'weak-password')
        return "Yeni şifre çok zayıf.";
      return "Bir hata oluştu: ${e.message}";
    } catch (e) {
      return "Beklenmedik bir hata oluştu.";
    }
  }
}
