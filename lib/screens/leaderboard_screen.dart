import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class LeaderboardScreen extends StatelessWidget {
  LeaderboardScreen({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Genel Sıralama (Top 100)')),
      body: StreamBuilder<QuerySnapshot>(
        // Sorgumuz: 'users' koleksiyonunu 'toplamPuan'a göre azalan sırada sırala, ilk 100'ü al.
        stream: _firestore
            .collection('users')
            .orderBy('toplamPuan', descending: true)
            .limit(100)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Liderlik tablosu yüklenemedi.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz puan alan kimse yok.'));
          }

          var userDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: userDocs.length,
            itemBuilder: (context, index) {
              var user = userDocs[index];
              var userData = user.data() as Map<String, dynamic>;
              var userId = user.id;

              // Kullanıcı adını (varsa) veya e-postayı al
              var kullaniciAdi = userData.containsKey('kullaniciAdi')
                  ? userData['kullaniciAdi']
                  : (userData.containsKey('email')
                        ? userData['email']
                        : 'İsimsiz');

              var puan = (userData['toplamPuan'] as num? ?? 0)
                  .toInt(); // num->int dönüşümü

              // Mevcut kullanıcıyı vurgula
              final bool isCurrentUser = (currentUserId == userId);

              return Card(
                color: isCurrentUser ? Colors.blue.shade100 : null, // Vurgu
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrentUser
                        ? Colors.blueAccent
                        : Colors.grey,
                    child: Text(
                      '${index + 1}', // Sıralama (1, 2, 3...)
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(kullaniciAdi),
                  trailing: Text(
                    '$puan Puan',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
