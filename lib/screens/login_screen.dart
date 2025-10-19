import 'package:flutter/material.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  void _login() async {
    setState(() {
      _errorMessage = '';
    });

    // Basit bir klavye kapama
    FocusScope.of(context).unfocus();

    final user = await _authService.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (user == null) {
      setState(() {
        _errorMessage =
            'Giriş yapılamadı. E-posta veya şifrenizi kontrol edin.';
      });
    }
    // Giriş başarılıysa, AuthWrapper bizi otomatik olarak MainScreen'e yönlendirecek.
  }

  void _loginWithGoogle() async {
    final user = await _authService.signInWithGoogle();
    // Başarılıysa AuthWrapper yönlendirir.
    // Hata varsa AuthService'de print ile konsola yazdırdık.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş Yap')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-posta'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton(onPressed: _login, child: const Text('Giriş Yap')),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                  ),
                );
              },
              child: const Text('Hesabın yok mu? Kayıt Ol'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loginWithGoogle,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white70),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Not: Bu logoyu eklemeniz gerek (assets/google_logo.png)
                  // Image.asset('assets/google_logo.png', height: 20),
                  const Icon(
                    Icons.g_mobiledata,
                    color: Colors.black,
                  ), // Logo yerine ikon
                  const SizedBox(width: 10),
                  const Text(
                    'Google ile Giriş Yap',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
