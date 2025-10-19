import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_screen.dart';

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

class _QuizListScreenState extends State<QuizListScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kategoriAd),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Çözmediklerim'),
            Tab(text: 'Çözdüklerim'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('quizzes')
            .where('kategoriId', isEqualTo: widget.kategoriId)
            .snapshots(),
        builder: (context, allSnapshot) {
          if (!allSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allQuizzes = allSnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(userId)
                .collection('solvedQuizzes')
                .snapshots(),
            builder: (context, solvedSnapshot) {
              if (!solvedSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final solvedIds = solvedSnapshot.data!.docs
                  .map((d) => d.id)
                  .toSet();

              final unsolvedQuizzes = allQuizzes
                  .where((q) => !solvedIds.contains(q.id))
                  .toList();
              final solvedQuizzes = allQuizzes
                  .where((q) => solvedIds.contains(q.id))
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildQuizListView(
                    quizzes: unsolvedQuizzes,
                    isSolvedTab: false,
                    userId: userId,
                  ),
                  _buildQuizListView(
                    quizzes: solvedQuizzes,
                    isSolvedTab: true,
                    userId: userId,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildQuizListView({
    required List<DocumentSnapshot> quizzes,
    required bool isSolvedTab,
    required String? userId,
  }) {
    if (quizzes.isEmpty) {
      return Center(
        child: Text(
          isSolvedTab
              ? 'Bu kategoride henüz çözdüğünüz test yok.'
              : 'Bu kategorideki tüm testleri çözmüşsünüz!',
        ),
      );
    }

    return ListView.builder(
      itemCount: quizzes.length,
      itemBuilder: (context, index) {
        var quiz = quizzes[index];
        var quizId = quiz.id;
        var quizData = quiz.data() as Map<String, dynamic>;
        var quizBaslik = quizData['baslik'] ?? 'Başlıksız Test';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: isSolvedTab
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.remove_circle_outline, color: Colors.grey),
            title: Text(quizBaslik),
            subtitle: Text(
              "Soru: ${quizData['soruSayisi'] ?? '?'} - Süre: ${quizData['sureDakika'] ?? '?'} dk",
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizScreen(
                    quizId: quizId,
                    quizBaslik: quizBaslik,
                    soruSayisi: quizData['soruSayisi'] ?? 0,
                    sureDakika: quizData['sureDakika'] ?? 10,
                    kategoriId: widget.kategoriId,
                  ),
                ),
              );

              if (result == true && mounted) {
                // StreamBuilder zaten canlı güncelliyor, ekstra yükleme gerek yok
                setState(() {});
              }
            },
          ),
        );
      },
    );
  }
}
