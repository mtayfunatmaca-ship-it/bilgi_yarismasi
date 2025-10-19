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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordRepeatController =
      TextEditingController();

  String _errorMessage = '';
  bool _isLoading = false;

  void _register() async {
    setState(() {
      _errorMessage = '';
    });

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final passwordRepeat = _passwordRepeatController.text;

    if (username.isEmpty || username.length > 10) {
      setState(() {
        _errorMessage =
            'Kullanıcı adı boş olamaz ve maksimum 10 karakter olabilir.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Şifre en az 6 karakter olmalıdır.';
      });
      return;
    }

    if (password != passwordRepeat) {
      setState(() {
        _errorMessage = 'Şifreler eşleşmiyor.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = await _authService.createUserWithEmailAndPassword(
      email,
      password,
      username: username,
    );

    setState(() {
      _isLoading = false;
    });

    if (user != null) {
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _errorMessage = 'Kayıt başarısız. E-posta zaten kullanılıyor olabilir.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(20),
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
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı Adı (max 10 karakter)',
              ),
              maxLength: 10,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordRepeatController,
              decoration: const InputDecoration(labelText: 'Şifre Tekrar'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
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
          ],
        ),
      ),
    );
  }
}
