import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  final TextEditingController _usernameController = TextEditingController();

  String _email = '';
  String _kullaniciAdi = '';
  int _toplamPuan = 0;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          _email = data['email'] ?? 'E-posta bulunamadı';
          _kullaniciAdi = data['kullaniciAdi'] ?? '';
          _toplamPuan = (data['toplamPuan'] as num? ?? 0)
              .toInt(); // num -> int DÖNÜŞÜMÜ
          _usernameController.text = _kullaniciAdi;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Profil verisi yüklenirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil verileri yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı boş olamaz!')),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'kullaniciAdi': newUsername,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Profil güncellenemedi. $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _kullaniciAdi = newUsername;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        // 'Çıkış Yap' butonu eklendi
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () {
              _authService.signOut();
              // AuthWrapper gerisini halledecek ve bizi LoginScreen'e atacak
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-posta (Değiştirilemez)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(_email, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Text(
                    'Toplam Puan',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Chip(
                    label: Text(
                      '$_toplamPuan Puan',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    avatar: const Icon(Icons.star, color: Colors.amber),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Değişiklikleri Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
