import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_list_screen.dart';
// Leaderboard ve Profile importları kaldırıldı

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;
    final String currentUserEmail =
        _authService.currentUser?.email ?? 'Kullanıcı';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriler'),
        // 'actions' bölümü kaldırıldı
      ),
      body: currentUserId == null
          ? const Center(child: Text('Kullanıcı bulunamadı.'))
          : StreamBuilder<DocumentSnapshot>(
              // Kullanıcının belgesini dinle
              stream: _firestore
                  .collection('users')
                  .doc(currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                String welcomeMessage = 'Hoş Geldiniz!';
                if (snapshot.connectionState == ConnectionState.active &&
                    snapshot.hasData) {
                  // Veri geldiyse
                  var userData = snapshot.data!.data() as Map<String, dynamic>;
                  var username = userData['kullaniciAdi'] ?? currentUserEmail;
                  welcomeMessage = 'Hoş Geldiniz, $username!';
                } else if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  // Veri yükleniyorsa
                  welcomeMessage = 'Yükleniyor...';
                }

                return Column(
                  children: [
                    // GÜNCELLENMİŞ "Hoş Geldiniz" MESAJI
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        welcomeMessage,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(),

                    // Kategori Listesi
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('categories')
                            .orderBy('sira')
                            .snapshots(),
                        builder: (context, catSnapshot) {
                          if (catSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (catSnapshot.hasError) {
                            return const Center(
                              child: Text('Bir hata oluştu.'),
                            );
                          }
                          if (!catSnapshot.hasData ||
                              catSnapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('Gösterilecek kategori bulunamadı.'),
                            );
                          }

                          var documents = catSnapshot.data!.docs;

                          return ListView.builder(
                            itemCount: documents.length,
                            itemBuilder: (context, index) {
                              var data =
                                  documents[index].data()
                                      as Map<String, dynamic>;
                              var docId = documents[index].id;
                              var kategoriAdi = data.containsKey('ad')
                                  ? data['ad']
                                  : 'İsimsiz Kategori';

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.category_outlined),
                                  title: Text(kategoriAdi),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuizListScreen(
                                          kategoriId: docId,
                                          kategoriAd: kategoriAdi,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
