import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:bilgi_yarismasi/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>(); // <<< Form kontrolü için key
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false; // <<< Yüklenme durumu

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- E-posta/Şifre ile Giriş (Güncellendi) ---
  void _login() async {
    // Form geçerli değilse veya zaten yükleniyorsa devam etme
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });
    FocusScope.of(context).unfocus(); // Klavyeyi kapat

    // AuthService'den hata mesajını al
    final error = await _authService.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text, // Şifrede trim() genellikle yapılmaz
    );

    // İşlem bittikten sonra ekran hala aktif mi kontrol et
    if (!mounted) return;

    if (error != null) {
      // Hata varsa göster
      setState(() {
        _errorMessage = error;
      });
    }
    // Başarılıysa AuthWrapper yönlendirecek

    setState(() {
      _isLoading = false;
    }); // Yükleme bitti
  }

  // --- Google ile Giriş (Güncellendi) ---
  void _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    // AuthService'den hata mesajını al
    final error = await _authService.signInWithGoogle();

    if (!mounted) return;

    if (error != null) {
      // Hata varsa göster
      setState(() {
        _errorMessage = error;
      });
    }
    // Başarılıysa AuthWrapper yönlendirecek

    setState(() {
      _isLoading = false;
    }); // Yükleme bitti
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş Yap')),
      // Klavye açıldığında taşmayı engellemek için SingleChildScrollView
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          // <<< Form widget'ı eklendi
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Ortalamak için
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Butonları genişletmek için
            children: [
              // Ekranın üst kısmında boşluk bırakmak için (isteğe bağlı)
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),

              TextFormField(
                // <<< TextField yerine TextFormField
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.email_outlined), // İkon eklendi
                  border: OutlineInputBorder(), // Kenarlık eklendi
                ),
                keyboardType: TextInputType.emailAddress,
                autovalidateMode:
                    AutovalidateMode.onUserInteraction, // Yazarken kontrol et
                validator: (value) {
                  // <<< E-posta format kontrolü
                  if (value == null || value.isEmpty) {
                    return 'E-posta boş olamaz.';
                  }
                  // Basit bir e-posta format kontrolü
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                    return 'Lütfen geçerli bir e-posta girin.';
                  }
                  return null; // Geçerli
                },
              ),
              const SizedBox(height: 12), // Boşluk ayarlandı
              TextFormField(
                // <<< TextField yerine TextFormField
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: Icon(Icons.lock_outline), // İkon eklendi
                  border: OutlineInputBorder(), // Kenarlık eklendi
                ),
                obscureText: true,
                validator: (value) {
                  // <<< Şifre boş kontrolü
                  if (value == null || value.isEmpty) {
                    return 'Şifre boş olamaz.';
                  }
                  // İsteğe bağlı: Minimum karakter kontrolü eklenebilir
                  // if (value.length < 6) {
                  //   return 'Şifre en az 6 karakter olmalı.';
                  // }
                  return null; // Geçerli
                },
              ),
              const SizedBox(height: 20),

              // Hata mesajı alanı
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ), // Tema rengi
                    textAlign: TextAlign.center,
                  ),
                ),

              // Giriş Yap Butonu
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : _login, // Yükleniyorsa devre dışı
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ), // Dikey padding
                ),
                child: _isLoading
                    ? const SizedBox(
                        // <<< Yüklenme göstergesi
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Giriş Yap'),
              ),
              const SizedBox(height: 10),

              // Kayıt Ol Butonu
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        // Yükleniyorsa devre dışı
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                child: const Text('Hesabın yok mu? Kayıt Ol'),
              ),
              const SizedBox(height: 20),

              // Google ile Giriş Butonu
              ElevatedButton.icon(
                // <<< ElevatedButton.icon kullanıldı
                onPressed: _isLoading
                    ? null
                    : _loginWithGoogle, // Yükleniyorsa devre dışı
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // Arka plan
                  foregroundColor: Colors.black87, // Yazı/İkon rengi
                  padding: const EdgeInsets.symmetric(vertical: 12), // Padding
                  side: BorderSide(color: Colors.grey.shade300), // Kenarlık
                ),
                icon: _isLoading
                    ? Container(
                        // <<< Yüklenme göstergesi
                        width: 20,
                        height: 20,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                    : const Icon(Icons.g_mobiledata, size: 24), // Google ikonu
                label: const Text('Google ile Giriş Yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
