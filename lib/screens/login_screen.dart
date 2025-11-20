import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:bilgi_yarismasi/screens/register_screen.dart';
// --- YENİ IMPORT ---
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io'; // Platform kontrolü için
// --- BİTTİ ---

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
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Fonksiyonlar ---
  void _login() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });
    FocusScope.of(context).unfocus();
    final error = await _authService.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (error != null)
      setState(() {
        _errorMessage = error;
      });
    setState(() {
      _isLoading = false;
    });
  }

  void _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });
    final error = await _authService.signInWithGoogle();
    if (!mounted) return;
    if (error != null)
      setState(() {
        _errorMessage = error;
      });
    setState(() {
      _isLoading = false;
    });
  }

  // --- YENİ FONKSİYON: Apple ile Giriş ---
  void _loginWithApple() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });
    final error = await _authService.signInWithApple();
    if (!mounted) return;
    if (error != null)
      setState(() {
        _errorMessage = error;
      });
    setState(() {
      _isLoading = false;
    });
  }
  // --- BİTTİ ---

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    final GlobalKey<FormState> resetFormKey = GlobalKey<FormState>();
    bool isSending = false;
    String? dialogMessage;
    bool isSuccess = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      validator: (value) =>
                          (value == null ||
                              value.isEmpty ||
                              !RegExp(r'\S+@\S+\.\S+').hasMatch(value))
                          ? 'Lütfen geçerli bir e-posta girin.'
                          : null,
                      onChanged: (_) {
                        if (dialogMessage != null)
                          setDialogState(() => dialogMessage = null);
                      },
                    ),
                    if (dialogMessage != null && dialogMessage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          dialogMessage!,
                          style: TextStyle(
                            color: isSuccess
                                ? Colors.green.shade700
                                : Colors.red.shade700,
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
                              dialogMessage = null;
                            });
                            final error = await _authService
                                .sendPasswordResetEmail(
                                  resetEmailController.text.trim(),
                                );
                            if (!mounted) return;
                            if (error == null) {
                              setDialogState(() {
                                isSending = false;
                                isSuccess = true;
                                dialogMessage =
                                    'Link gönderildi! E-postanızı kontrol edin.';
                              });
                              Future.delayed(const Duration(seconds: 3), () {
                                if (mounted && Navigator.of(context).canPop())
                                  Navigator.pop(context);
                              });
                            } else {
                              setDialogState(() {
                                isSending = false;
                                isSuccess = false;
                                dialogMessage = 'Hata: $error';
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

  // Yardımcı widget (TextFormField için)
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 12,
            ),
          ),
          obscureText: obscureText,
          keyboardType: keyboardType,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
        ),
      ],
    );
  }

  // === build METODU (APPLE BUTONU EKLENDİ) ===
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    // iOS'ta Sign in with Apple butonunun görünmesi için kontrol
    final bool isIOS = Platform.isIOS;

    return Scaffold(
      backgroundColor: colorScheme.background, // Beyaz arka plan
      body: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: screenSize.height, // En az ekran yüksekliği kadar
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. MAVİ BAŞLIK VE GÖRSEL ALANI
              Container(
                height: screenSize.height * 0.5, // Yükseklik ayarlandı
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: SafeArea(
                  bottom: false, // Alt SafeArea'yı form alanı halledecek
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- YENİ GÖRSEL ---
                      Expanded(
                        child: Center(
                          child: Image.asset(
                            'assets/images/login_background.png', // <<< SENİN GÖRSELİNİN YOLU
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print("Giriş ekranı resmi yüklenemedi: $error");
                              return Center(
                                child: Icon(
                                  Icons.quiz_rounded,
                                  color: colorScheme.onPrimary.withOpacity(0.5),
                                  size: 80,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // --- GÖRSEL BİTTİ ---
                      const SizedBox(height: 12),
                      Text(
                        'Tekrar Hoş Geldin!',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Giriş yap ve devam et',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onPrimary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. BEYAZ FORM ALANI
              Transform.translate(
                offset: const Offset(0, -10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: BoxDecoration(
                    color: colorScheme.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(
                          controller: _emailController,
                          label: 'E-posta',
                          hint: 'E-postanızı girin',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'E-posta boş olamaz.';
                            }
                            if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                              return 'Lütfen geçerli bir e-posta girin.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Şifre',
                          hint: 'Şifrenizi girin',
                          icon: Icons.lock_outline,
                          obscureText: !_isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Şifre boş olamaz.';
                            }
                            if (value.length < 6) {
                              return 'Şifre en az 6 karakter olmalıdır.';
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: colorScheme.onSurfaceVariant.withOpacity(
                                0.7,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : _showForgotPasswordDialog,
                            child: const Text('Şifremi Unuttum?'),
                          ),
                        ),

                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 10.0,
                              top: 5.0,
                            ),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 10),

                        // 3. E-posta Giriş Butonu (Aynı)
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
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
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center, // Ortala
                                  children: [
                                    const Text(
                                      'GİRİŞ YAP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                        ),

                        // "VEYA" Ayıracı
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outline.withOpacity(0.5),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
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

                        // 4. APPLE İLE GİRİŞ BUTONU (Sadece iOS'ta görünür)
                        /* if (isIOS)
                          Container(
                            height: 50,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: SignInWithAppleButton(
                              style: SignInWithAppleButtonStyle
                                  .black, // Apple'ın yönergelerine uygun
                              onPressed: _isLoading ? null : _loginWithApple,
                              borderRadius: BorderRadius.circular(12),
                              height: 50,
                            ),
                          ),

                        // 5. Google ile Giriş Butonu
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _loginWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                colorScheme.surfaceVariant, // Temaya uygun
                            foregroundColor:
                                colorScheme.onSurfaceVariant, // Temaya uygun
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: _isLoading
                              ? Container(
                                  width: 22,
                                  height: 22,
                                  padding: const EdgeInsets.all(2.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 22.0,
                                  width: 22.0,
                                ),
                          label: const Text('Google ile Giriş Yap'),
                        ),*/

                        // Kayıt Ol Butonu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Hesabın yok mu?",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                              child: Text(
                                'Kayıt Ol',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Yardımcı widget (TextFormField için)
}
