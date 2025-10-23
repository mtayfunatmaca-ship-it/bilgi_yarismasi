import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı durumunu dinler (giriş/çıkış)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Mevcut kullanıcıyı anlık alır
  User? get currentUser => _auth.currentUser;

  /**
   * E-POSTA VE ŞİFRE İLE YENİ KULLANICI KAYDI
   * 'ad', 'soyad' ve 'username' alır.
   * 'kullaniciAdi'nı kontrol eder.
   */
  Future<String?> createUserWithEmailAndPassword(
    String email,
    String password, {
    required String ad,
    required String soyad,
    required String username,
  }) async {
    // Alan kontrolleri
    if (ad.trim().isEmpty) return 'Ad alanı boş olamaz.';
    if (soyad.trim().isEmpty) return 'Soyad alanı boş olamaz.';
    if (username.trim().isEmpty) return 'Kullanıcı adı boş olamaz.';

    try {
      // 1. Kullanıcı adının müsait olup olmadığını kontrol et
      final existingUser = await _firestore
          .collection('users')
          .where('kullaniciAdi', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        return 'Bu kullanıcı adı zaten alınmış.';
      }

      // 2. Firebase Auth ile kullanıcıyı oluştur
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      User? user = result.user;

      // 3. Firestore'a kullanıcı belgesini oluştur
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'kullaniciAdi': username.trim(),
          'ad': ad.trim(), // Ad
          'soyad': soyad.trim(), // Soyad
          'profilFotoUrl': '',
          'emoji': '🙂',
          'toplamPuan': 0,
          'kayitTarihi': FieldValue.serverTimestamp(),
        });
      }

      return null; // Başarılı, hata yok
    } on FirebaseAuthException catch (e) {
      print('Kayıt Hatası: ${e.code} - ${e.message}');
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

  /**
   * E-POSTA VE ŞİFRE İLE GİRİŞ
   */
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // Başarılı, hata yok
    } on FirebaseAuthException catch (e) {
      print('Giriş Hatası: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        return 'E-posta veya şifre hatalı.';
      } else if (e.code == 'invalid-email') {
        return 'Geçersiz e-posta adresi formatı.';
      } else if (e.code == 'user-disabled') {
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';
      } else if (e.code == 'network-request-failed') {
        return 'İnternet bağlantınızı kontrol edin.';
      }
      return 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
    } catch (e) {
      print('Bilinmeyen Giriş Hatası: $e');
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  /**
   * GOOGLE İLE GİRİŞ
   * İlk girişte 'ad' ve 'soyad' oluşturur.
   */
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
          // Google adını 'ad' ve 'soyad' olarak ayır
          String ad = 'Google Kullanıcısı';
          String soyad = '';
          String kullaniciAdi =
              user.email?.split('@').first ??
              'kullanici_${user.uid.substring(0, 5)}';

          if (user.displayName != null && user.displayName!.isNotEmpty) {
            final parts = user.displayName!.split(' ');
            if (parts.isNotEmpty) {
              ad = parts.first;
              if (parts.length > 1) {
                soyad = parts.sublist(1).join(' ');
              }
            }
          }

          // Kullanıcı adı çakışmasını önle
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
          });
        }
      }
      return null; // Başarılı
    } on FirebaseAuthException catch (e) {
      print('Google Giriş Hatası: ${e.code} - ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        return 'Bu e-posta ile farklı bir yöntemle (örn: şifre) hesap oluşturulmuş. Lütfen o yöntemle giriş yapın.';
      } else if (e.code == 'network-request-failed') {
        return 'İnternet bağlantınızı kontrol edin.';
      } else if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return 'Google giriş penceresi kapatıldı.';
      }
      return 'Google ile giriş sırasında bir hata oluştu.';
    } catch (e) {
      print('Bilinmeyen Google Giriş Hatası: $e');
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  /**
   * ÇIKIŞ YAP
   */
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Çıkış yaparken hata: $e");
    }
  }

  /**
   * ŞİFRE SIFIRLAMA LİNKİ GÖNDER (Şifremi Unuttum için)
   */
  Future<String?> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) return "E-posta alanı boş olamaz.";
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // Başarılı
    } on FirebaseAuthException catch (e) {
      print('Şifre Sıfırlama Hatası: ${e.code}');
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return 'Bu e-posta adresi ile kayıtlı bir kullanıcı bulunamadı.';
      } else if (e.code == 'network-request-failed') {
        return 'İnternet bağlantınızı kontrol edin.';
      }
      return 'Bir hata oluştu, lütfen tekrar deneyin.';
    } catch (e) {
      print('Bilinmeyen Şifre Sıfırlama Hatası: $e');
      return 'Beklenmedik bir hata oluştu.';
    }
  }

  /**
   * ŞİFRE DEĞİŞTİR (Profil Ekranı için)
   * Önce mevcut şifreyi doğrular.
   */
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
      // 1. Kullanıcının kimliğini doğrula
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Şifreyi güncelle
      await user.updatePassword(newPassword);

      print("Şifre başarıyla güncellendi.");
      return null; // Başarılı
    } on FirebaseAuthException catch (e) {
      print("Şifre değiştirme hatası: ${e.code}");
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return "Mevcut şifreniz hatalı.";
      } else if (e.code == 'weak-password') {
        return "Yeni şifre çok zayıf.";
      } else if (e.code == 'network-request-failed') {
        return 'İnternet bağlantınızı kontrol edin.';
      }
      return "Bir hata oluştu: ${e.message}";
    } catch (e) {
      print("Bilinmeyen şifre değiştirme hatası: $e");
      return "Beklenmedik bir hata oluştu.";
    }
  }
}
