import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_screen.dart';
import 'package:bilgi_yarismasi/screens/result_screen.dart'; // ResultScreen'i import et

class QuizListScreen extends StatefulWidget {
  final String kategoriId;
  final String kategoriAd;

  const QuizListScreen({
    super.key,
    required this.kategoriId,
    required this.kategoriAd,
  });

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // 'Set<String>' yerine 'Map<String, dynamic>' tutuyoruz
  Map<String, dynamic> _solvedQuizData = {};
  bool _isLoadingSolvedQuizzes = true;

  @override
  void initState() {
    super.initState();
    _loadSolvedQuizzes();
  }

  // Bu fonksiyon artık tüm 'solvedQuiz' belgelerini haritaya yüklüyor
  Future<void> _loadSolvedQuizzes() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingSolvedQuizzes = false;
      });
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('solvedQuizzes')
          .get();

      // Geçici bir harita oluştur
      Map<String, dynamic> solvedDataMap = {};
      for (var doc in snapshot.docs) {
        solvedDataMap[doc.id] = doc.data();
      }

      setState(() {
        _solvedQuizData = solvedDataMap; // Ana haritayı güncelle
        _isLoadingSolvedQuizzes = false;
      });
    } catch (e) {
      print("Çözülen testleri yüklerken hata: $e");
      setState(() {
        _isLoadingSolvedQuizzes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kategoriAd)),
      body: _isLoadingSolvedQuizzes
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('quizzes')
                  .where('kategoriId', isEqualTo: widget.kategoriId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Testler yüklenemedi.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Bu kategoride hiç test yok.'),
                  );
                }

                var quizDocs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: quizDocs.length,
                  itemBuilder: (context, index) {
                    var quiz = quizDocs[index];
                    var quizId = quiz.id;
                    var quizData = quiz.data() as Map<String, dynamic>;
                    var quizBaslik = quizData['baslik'] ?? 'Başlıksız Test';

                    // 'solvedQuizData' haritasında bu ID var mı?
                    final bool isSolved = _solvedQuizData.containsKey(quizId);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        title: Text(quizBaslik),
                        subtitle: Text(
                          "Soru: ${quizData['soruSayisi'] ?? '?'} - Süre: ${quizData['sureDakika'] ?? '?'} dk",
                        ),

                        // 'trailing' artık 'Çöz' butonu değil, bir ikon.
                        trailing: isSolved
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.arrow_forward_ios),

                        // Tüm 'ListTile' artık tıklanabilir.
                        onTap: () async {
                          // Fonksiyonu 'async' yap

                          if (isSolved) {
                            // DURUM 1: TEST ÇÖZÜLMÜŞSE
                            final solvedData = _solvedQuizData[quizId];

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResultScreen(
                                  fromHistory: true,
                                  solvedData: solvedData,
                                ),
                              ),
                            );
                          } else {
                            // DURUM 2: TEST ÇÖZÜLMEMİŞSE
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizScreen(
                                  quizId: quizId,
                                  quizBaslik: quizBaslik,
                                  soruSayisi: quizData['soruSayisi'] ?? 0,
                                  sureDakika: quizData['sureDakika'] ?? 10,
                                ),
                              ),
                            );

                            // Test çözülüp 'true' sonucuyla geri dönüldüyse
                            if (result == true && mounted) {
                              _loadSolvedQuizzes();
                            }
                          }
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
