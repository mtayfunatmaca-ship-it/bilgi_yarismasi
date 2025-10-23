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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false; // Yüklenme durumu

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- E-posta/Şifre ile Giriş ---
  void _login() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });
    FocusScope.of(context).unfocus(); // Klavyeyi kapat

    final error = await _authService.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    }
    // Başarılıysa AuthWrapper yönlendirecek
    setState(() {
      _isLoading = false;
    });
  }

  // --- Google ile Giriş ---
  void _loginWithGoogle() async {
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
    // Başarılıysa AuthWrapper yönlendirecek
    setState(() {
      _isLoading = false;
    });
  }

  // --- Şifre Sıfırlama Dialog'u ---
  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    final GlobalKey<FormState> resetFormKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        // Dialogun kendi state'ini yönetmesi için StatefulBuilder
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? dialogError; // Hata mesajı (String? olmalı)

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Şifremi Unuttum'),
              content: Form(
                key: resetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kayıtlı e-posta adresinizi girin. Size bir sıfırlama linki göndereceğiz.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resetEmailController,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                          return 'Lütfen geçerli bir e-posta girin.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (dialogError != null)
                          setDialogState(() => dialogError = null);
                      },
                    ),
                    if (dialogError != null && dialogError!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          dialogError!,
                          style: TextStyle(
                            color: dialogError!.contains('Hata')
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          if (resetFormKey.currentState?.validate() ?? false) {
                            setDialogState(() {
                              isSending = true;
                              dialogError = null;
                            });

                            final error = await _authService
                                .sendPasswordResetEmail(
                                  resetEmailController.text.trim(),
                                );

                            if (!mounted) return;
                            if (error == null) {
                              // Başarılı
                              setDialogState(() {
                                isSending = false;
                                dialogError =
                                    'Link gönderildi! E-postanızı kontrol edin.';
                              });
                              // 2 saniye sonra dialog'u kapat
                              Future.delayed(const Duration(seconds: 3), () {
                                if (mounted && Navigator.of(context).canPop()) {
                                  Navigator.pop(context);
                                }
                              });
                            } else {
                              // Hatalı
                              setDialogState(() {
                                isSending = false;
                                dialogError = 'Hata: $error';
                              });
                            }
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- Şifre Sıfırlama Bitti ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Giriş Yap')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo veya karşılama mesajı için boşluk
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              Icon(Icons.quiz_rounded, size: 80, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Tekrar Hoş Geldin!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Giriş yaparak yarışmaya devam et.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),

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
                    return 'Lütfen geçerli bir e-posta girin.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                obscureText: true,
                autovalidateMode: AutovalidateMode
                    .onUserInteraction, // Yazarken kontrol etmesin
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Şifre boş olamaz.';
                  return null;
                },
              ),

              // Şifremi Unuttum Butonu
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _showForgotPasswordDialog,
                  child: const Text('Şifremi Unuttum?'),
                ),
              ),

              // Hata mesajı alanı
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Giriş Yap Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
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
                    : const Text('Giriş Yap'),
              ),
              const SizedBox(height: 10),

              // Kayıt Ol Butonu
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                child: const Text('Hesabın yok mu? Kayıt Ol'),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'VEYA',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Google ile Giriş Butonu (Image.asset ile)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loginWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                  side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                ),
                icon: _isLoading
                    ? Container(
                        width: 22,
                        height: 22,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                    : Image.asset(
                        'assets/google_logo.png', // pubspec.yaml'da tanımlı olmalı
                        height: 22.0,
                        width: 22.0,
                      ),
                label: const Text('Google ile Giriş Yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
