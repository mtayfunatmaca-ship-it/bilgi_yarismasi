import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Bu kısımlar aynı kalıyor
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // --- E-POSTA VE ŞİFRE İLE KAYIT OLMA (Güncellendi: String? döndürüyor) ---
  Future<String?> createUserWithEmailAndPassword(
    String email,
    String password, {
    required String username,
  }) async {
    // Kullanıcı adı boş olamaz kontrolü
    if (username.trim().isEmpty) {
      return 'Kullanıcı adı boş olamaz.';
    }
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), // E-postadaki boşlukları temizle
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Profil oluşturma (aynı)
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'kullaniciAdi': username
              .trim(), // Kullanıcı adındaki boşlukları temizle
          'profilFotoUrl': '',
          'emoji': '🙂', // Varsayılan emoji ekleyelim
          'toplamPuan': 0,
          'kayitTarihi': FieldValue.serverTimestamp(),
        });
      }

      return null; // Başarılı, hata yok
    } on FirebaseAuthException catch (e) {
      print(
        'Kayıt Hatası: ${e.code} - ${e.message}',
      ); // Kodu da loglamak iyi olur
      // Kullanıcıya gösterilebilecek daha basit mesajlar
      if (e.code == 'weak-password') {
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      } else if (e.code == 'email-already-in-use') {
        return 'Bu e-posta adresi zaten başka bir hesap tarafından kullanılıyor.';
      } else if (e.code == 'invalid-email') {
        return 'Geçersiz e-posta adresi formatı.';
      }
      // Diğer olası hatalar için genel mesaj
      return 'Kayıt sırasında bir hata oluştu. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
    } catch (e) {
      print('Bilinmeyen Kayıt Hatası: $e');
      return 'Beklenmedik bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
    }
  }

  // --- E-POSTA VE ŞİFRE İLE GİRİŞ (Güncellendi: String? döndürüyor) ---
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(), // E-postadaki boşlukları temizle
        password: password,
      );
      return null; // Başarılı, hata yok
    } on FirebaseAuthException catch (e) {
      print('Giriş Hatası: ${e.code} - ${e.message}');
      // Yeni hata kodu 'invalid-credential' genellikle yanlış e-posta/şifre için kullanılır
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
      // Diğer olası hatalar için genel mesaj
      return 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
    } catch (e) {
      print('Bilinmeyen Giriş Hatası: $e');
      return 'Beklenmedik bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
    }
  }

  // --- GOOGLE İLE GİRİŞ (Güncellendi: String? döndürüyor) ---
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      // Kullanıcı seçimi iptal ettiyse
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
        // Profil oluşturma/kontrol (aynı)
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();
        if (!doc.exists) {
          await docRef.set({
            'email': user.email,
            'kullaniciAdi':
                user.displayName ?? user.email?.split('@').first ?? 'Kullanici',
            'profilFotoUrl': user.photoURL ?? '',
            'emoji': '🙂', // Varsayılan emoji ekleyelim
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
      // Diğer olası hatalar için genel mesaj
      return 'Google ile giriş sırasında bir hata oluştu. Lütfen tekrar deneyin.';
    } catch (e) {
      print('Bilinmeyen Google Giriş Hatası: $e');
      return 'Beklenmedik bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
    }
  }

  // Çıkış yapma fonksiyonu aynı kalıyor
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Çıkış yaparken hata: $e");
      // İsteğe bağlı: Kullanıcıya çıkış yaparken hata olduğunu bildirebilirsiniz
    }
  }
}
