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
      // Arka plan rengini biraz değiştirerek kartların öne çıkmasını sağlayabiliriz
      backgroundColor: Colors.grey[100],
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
            padding: const EdgeInsets.all(12), // Liste için genel bir dolgu
            itemCount: solvedDocs.length,
            itemBuilder: (context, index) {
              var solvedData = solvedDocs[index].data() as Map<String, dynamic>;
              final String quizBaslik =
                  solvedData['quizBaslik'] ?? 'Başlıksız Test';
              final int puan = (solvedData['puan'] as num? ?? 0).toInt();
              final String tarih = _formatTimestamp(
                solvedData['tarih'] as Timestamp?,
              );

              // --- YENİ TASARIM ---
              // ListTile yerine özel Card tasarımı
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 6, // "Kabarık" görünüm için gölge
                shadowColor: Colors.blueGrey.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    20,
                  ), // Görseldeki gibi yuvarlak köşeler
                ),
                clipBehavior:
                    Clip.antiAlias, // İçeriğin köşelerden taşmasını engeller
                child: InkWell(
                  // Tıklanma efekti ve olayı için
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
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Sol Taraf: Renkli Arka Planlı İkon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[100], // Renkli arka plan
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green[800], // Renkli ikon
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Orta Kısım: Başlık, Puan ve Tarih
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quizBaslik,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Puan: $puan',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tarih,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Sağ Taraf: Görseldeki gibi "Oynat" butonu (Burada "İleri" ikonu)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Colors.orange[400], // Görseldeki gibi turuncu
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
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
