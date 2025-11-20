import 'package:flutter/material.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
// FontAwesome import'u kaldırıldı

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _soyadController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordRepeatController =
      TextEditingController();

  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _adController.dispose();
    _soyadController.dispose();
    _passwordController.dispose();
    _passwordRepeatController.dispose();
    super.dispose();
  }

  // E-posta ile Kayıt
  void _register() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });
    FocusScope.of(context).unfocus();

    final error = await _authService.createUserWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text,
      username: _usernameController.text.trim(),
      ad: _adController.text.trim(),
      soyad: _soyadController.text.trim(),
    );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _errorMessage = error;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  // Google ile Kayıt/Giriş
  void _registerWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    final error = await _authService.signInWithGoogle();

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    }
    if (error == null && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // E-posta
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
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

              // Ad Soyad
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _adController,
                      decoration: const InputDecoration(
                        labelText: 'Ad',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Ad boş olamaz.';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _soyadController,
                      decoration: const InputDecoration(
                        labelText: 'Soyad',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Soyad boş olamaz.';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Kullanıcı Adı
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  helperText: 'Maksimum 15 karakter',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  counterText: "",
                ),
                maxLength: 15,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Kullanıcı adı boş olamaz.';
                  if (value.length > 15)
                    return 'Maksimum 15 karakter olabilir.';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Şifre
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                obscureText: true,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Şifre boş olamaz.';
                  if (value.length < 6)
                    return 'Şifre en az 6 karakter olmalıdır.';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Şifre Tekrar
              TextFormField(
                controller: _passwordRepeatController,
                decoration: const InputDecoration(
                  labelText: 'Şifre Tekrar',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                obscureText: true,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Şifre tekrarı boş olamaz.';
                  if (value != _passwordController.text)
                    return 'Şifreler eşleşmiyor.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Hata Mesajı
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Kayıt Ol Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Kayıt Ol'),
              ),

              // "VEYA" Ayıracı
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    /* Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'VEYA',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),*/
                    Expanded(
                      child: Divider(
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // --- GOOGLE BUTONU (Image.asset ile GÜNCELLENDİ) ---
              /*ElevatedButton.icon(
                onPressed: _isLoading ? null : _registerWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // Google standardı beyaz
                  foregroundColor: Colors.black.withOpacity(0.7), // Siyah yazı
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                  side: BorderSide(
                    color: colorScheme.outline.withOpacity(0.3),
                  ), // Hafif kenarlık
                ),
                // --- YENİ İKON (Image.asset) ---
                icon: Image.asset(
                  'assets/images/google_logo.png', // <<< Asset'ten okur
                  height: 22.0, // Boyut ayarlandı
                  width: 22.0,
                ),
                // --- İKON BİTTİ ---
                label: const Text('Google ile Kayıt Ol'),
              ),*/
              // --- GOOGLE BUTONU BİTTİ ---
            ],
          ),
        ),
      ),
    );
  }
}
