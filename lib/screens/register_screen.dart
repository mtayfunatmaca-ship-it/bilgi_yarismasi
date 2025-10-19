import 'package:flutter/material.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>(); // <<< Form kontrolü için key
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordRepeatController =
      TextEditingController();

  String _errorMessage = '';
  bool _isLoading = false; // <<< Yüklenme durumu

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordRepeatController.dispose();
    super.dispose();
  }

  // --- Kayıt Fonksiyonu (Güncellendi) ---
  void _register() async {
    // Form geçerli değilse veya zaten yükleniyorsa devam etme
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    setState(() {
      _errorMessage = '';
      _isLoading = true;
    }); // Yükleniyor...
    FocusScope.of(context).unfocus(); // Klavyeyi kapat

    // AuthService'den hata mesajını al
    final error = await _authService.createUserWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text, // Şifrede trim() genellikle yapılmaz
      username: _usernameController.text.trim(), // Kullanıcı adını gönder
    );

    // İşlem bittikten sonra ekran hala aktif mi kontrol et
    if (!mounted) return;

    if (error == null) {
      // Başarılıysa (hata yoksa)
      Navigator.of(context).pop(); // Geri dön (AuthWrapper yönlendirir)
    } else {
      // Hata varsa
      setState(() {
        _errorMessage = error;
      }); // AuthService'den gelen hatayı göster
    }

    setState(() {
      _isLoading = false;
    }); // Yükleme bitti
  }
  // --- Kayıt Fonksiyonu Bitti ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      // Klavye açıldığında taşmayı engellemek için SingleChildScrollView
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          // <<< Form widget'ı eklendi
          key: _formKey,
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center, // SingleChildScrollView içinde gereksiz
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Butonları genişletmek için
            children: [
              // Ekranın üst kısmında boşluk bırakmak için (isteğe bağlı)
              const SizedBox(height: 30),

              TextFormField(
                // <<< TextField yerine TextFormField
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'E-posta boş olamaz.';
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value))
                    return 'Geçerli bir e-posta girin.';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                // <<< TextField yerine TextFormField
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  helperText: 'Maksimum 10 karakter', // Helper text daha iyi
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  counterText: "", // maxLength sayacını gizle
                ),
                maxLength: 10, // Karakter sınırı
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Kullanıcı adı boş olamaz.';
                  if (value.length > 10)
                    return 'Maksimum 10 karakter olabilir.';
                  // İsteğe bağlı: Boşluk kontrolü, özel karakter kontrolü eklenebilir
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                // <<< TextField yerine TextFormField
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Şifre boş olamaz.';
                  if (value.length < 6)
                    return 'Şifre en az 6 karakter olmalıdır.';
                  // İsteğe bağlı: Karmaşıklık kontrolü eklenebilir
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                // <<< TextField yerine TextFormField
                controller: _passwordRepeatController,
                decoration: const InputDecoration(
                  labelText: 'Şifre Tekrar',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  // <<< Şifre eşleşme kontrolü
                  if (value == null || value.isEmpty)
                    return 'Şifre tekrarı boş olamaz.';
                  if (value != _passwordController.text)
                    return 'Şifreler eşleşmiyor.';
                  return null;
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
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Kayıt Ol Butonu
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : _register, // Yükleniyorsa devre dışı
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                    : const Text('Kayıt Ol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
