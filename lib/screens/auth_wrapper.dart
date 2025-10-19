import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/login_screen.dart';
import 'package:bilgi_yarismasi/screens/main_screen.dart'; // HomeScreen yerine bunu import et

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges, // Auth durumunu dinle
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Bağlantı bekleniyor
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // Kullanıcı giriş yapmış
          // DEĞİŞİKLİK: HomeScreen() yerine MainScreen() döndür
          return const MainScreen();
        } else {
          // Kullanıcı giriş yapmamış
          return const LoginScreen(); // Burası aynı
        }
      },
    );
  }
}
