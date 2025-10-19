import 'package:flutter/material.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  void _register() async {
    setState(() {
      _errorMessage = '';
    });

    FocusScope.of(context).unfocus();

    final user = await _authService.createUserWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (user != null) {
      // Kayıt başarılı, kullanıcı otomatik giriş yaptı.
      // AuthWrapper bunu algılayıp MainScreen'e yönlendirecek.
      // Mevcut register sayfasını kapatıp geri dönüyoruz.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // Hata oluştu
      setState(() {
        _errorMessage =
            'Kayıt başarısız oldu. (Şifre zayıf veya e-posta kullanılıyor olabilir)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
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
            ElevatedButton(onPressed: _register, child: const Text('Kayıt Ol')),
          ],
        ),
      ),
    );
  }
}
