import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore eklendi

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // EKLENDİ

  // 1. GİRİŞ DURUMUNU DİNLE (Stream)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 2. MEVCUT KULLANICIYI AL
  User? get currentUser => _auth.currentUser;

  // 3. E-POSTA VE ŞİFRE İLE KAYIT OLMA (GÜNCELLENDİ)
  Future<User?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      // --- YENİ EKLENEN KISIM ---
      if (user != null) {
        // Yeni kullanıcı için Firestore'da hemen bir belge oluştur
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'kullaniciAdi':
              user.email?.split('@').first ??
              'Kullanici', // E-postadan kullanıcı adı türet
          'profilFotoUrl': '', // Varsayılan
          'toplamPuan': 0,
          'kayitTarihi': FieldValue.serverTimestamp(),
        });
      }
      // --- EKLENEN KISIM BİTTİ ---

      return user;
    } on FirebaseAuthException catch (e) {
      print('Kayıt Hatası: ${e.message}');
      return null;
    }
  }

  // 4. E-POSTA VE ŞİFRE İLE GİRİŞ YAPMA (Değişiklik yok)
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Giriş Hatası: ${e.message}');
      return null;
    }
  }

  // 5. GOOGLE İLE GİRİŞ YAPMA (GÜNCELLENDİ)
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Kullanıcı pencereyi kapattı
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      // --- YENİ EKLENEN KISIM ---
      if (user != null) {
        // Firestore'da bu kullanıcı için belge var mı diye kontrol et
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          // Belge yoksa (Google ile ilk giriş, yani kayıt), oluştur
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'kullaniciAdi': user.displayName ?? user.email?.split('@').first,
            'profilFotoUrl': user.photoURL ?? '',
            'toplamPuan': 0,
            'kayitTarihi': FieldValue.serverTimestamp(),
          });
        }
        // Belge varsa (normal giriş) bir şey yapmaya gerek yok
      }
      // --- EKLENEN KISIM BİTTİ ---

      return user;
    } on FirebaseAuthException catch (e) {
      print('Google Giriş Hatası: ${e.message}');
      return null;
    } catch (e) {
      print(e);
      return null;
    }
  }

  // 6. ÇIKIŞ YAPMA
  Future<void> signOut() async {
    await _googleSignIn.signOut(); // Google hesabından da çıkış yap
    await _auth.signOut(); // Firebase'den çıkış yap
  }
}
