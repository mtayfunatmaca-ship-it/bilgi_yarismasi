import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/result_screen.dart';
import 'package:intl/intl.dart';

class SolvedQuizzesScreen extends StatelessWidget {
  SolvedQuizzesScreen({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Timestamp'i "19 Ekim 2025, 14:30" gibi bir formata çevirir
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih yok';
    // 'intl' paketinin düzgün çalışması için 'tr_TR' (Türkçe) ayarını kullanabiliriz
    return DateFormat.yMMMMd('tr_TR').add_Hm().format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Geçmişim')),
        body: const Center(
          child: Text('Geçmişi görmek için giriş yapmalısınız.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Test Geçmişim')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('solvedQuizzes')
            .orderBy('tarih', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Geçmiş yüklenirken bir hata oluştu.'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz hiç test çözmemişsiniz.'));
          }

          var solvedDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: solvedDocs.length,
            itemBuilder: (context, index) {
              var solvedData = solvedDocs[index].data() as Map<String, dynamic>;
              final String quizBaslik =
                  solvedData['quizBaslik'] ?? 'Başlıksız Test';
              final int puan = (solvedData['puan'] as num? ?? 0).toInt();
              final String tarih = _formatTimestamp(
                solvedData['tarih'] as Timestamp?,
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(quizBaslik),
                  subtitle: Text('Puan: $puan - Tarih: $tarih'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Tıpkı QuizListScreen'deki gibi, geçmiş sonuç ekranına git
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResultScreen(
                          fromHistory: true,
                          solvedData: solvedData,
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
    );
  }
}
