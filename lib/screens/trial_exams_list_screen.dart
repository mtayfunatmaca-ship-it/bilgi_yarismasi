import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_screen.dart';
import 'package:bilgi_yarismasi/widgets/time_display.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_leaderboard_screen.dart';

// Yeni enum dosyasını import et
import 'package:bilgi_yarismasi/utils/exam_status.dart';

class TrialExamsListScreen extends StatefulWidget {
  const TrialExamsListScreen({super.key});

  @override
  State<TrialExamsListScreen> createState() => _TrialExamsListScreenState();
}

class _TrialExamsListScreenState extends State<TrialExamsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  Map<String, DocumentSnapshot> _userResults =
      {}; // Kullanıcının çözdüğü sınav sonuçları
  bool _isLoadingResults = true;
  // Timer kaldırılmıştı

  @override
  void initState() {
    super.initState();
    _loadUserResults();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserResults() async {
    if (!mounted) return;
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingResults = false);
      return;
    }
    if (mounted) setState(() => _isLoadingResults = true);
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trialExamResults')
          .get();
      Map<String, DocumentSnapshot> resultsMap = {};
      for (var doc in snapshot.docs) {
        resultsMap[doc.id] = doc;
      }
      if (!mounted) return;
      setState(() {
        _userResults = resultsMap;
        _isLoadingResults = false;
      });
    } catch (e) {
      print("Deneme sınavı sonuçları yüklenirken hata: $e");
      if (mounted) setState(() => _isLoadingResults = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Deneme Sınavları')),
      body: _isLoadingResults
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('trialExams')
                  .orderBy('startTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Sınav listesi hatası: ${snapshot.error}");
                  return Center(
                    child: Text(
                      'Sınavlar yüklenemedi.',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aktif deneme sınavı bulunmuyor.'),
                  );
                }

                var examDocs = snapshot.data!.docs;

                return RefreshIndicator(
                  onRefresh: _loadUserResults,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: examDocs.length,
                    itemBuilder: (context, index) {
                      var exam = examDocs[index];
                      var examId = exam.id;
                      var examData = exam.data() as Map<String, dynamic>? ?? {};

                      final String title =
                          examData['title'] ?? 'Başlıksız Sınav';
                      final Timestamp? startTimeTs = examData['startTime'];
                      final Timestamp? endTimeTs = examData['endTime'];
                      final DateTime? startTime = startTimeTs?.toDate();
                      final DateTime? endTime = endTimeTs?.toDate();
                      final int durationMinutes =
                          (examData['durationMinutes'] as num? ?? 30).toInt();
                      final int questionCount =
                          (examData['questionCount'] as num? ?? 0).toInt();

                      // Sınavın durumunu hesapla
                      ExamStatus status = ExamStatus.upcoming;
                      if (startTime != null && now.isBefore(startTime)) {
                        status = ExamStatus.upcoming;
                      } else if (endTime != null && now.isAfter(endTime)) {
                        status = ExamStatus.finished;
                      } else if (startTime != null &&
                          endTime != null &&
                          now.isAfter(startTime) &&
                          now.isBefore(endTime)) {
                        status = ExamStatus.active;
                      } else {
                        status = ExamStatus.unknown;
                      }

                      final bool hasTaken = _userResults.containsKey(examId);
                      final userResultData = hasTaken
                          ? _userResults[examId]?.data()
                                as Map<String, dynamic>?
                          : null;
                      final int? userScore = hasTaken
                          ? (userResultData?['score'] as num?)?.toInt()
                          : null;

                      Widget trailingWidget;
                      VoidCallback? listTileOnTap;

                      if (hasTaken) {
                        trailingWidget = Chip(
                          label: Text(
                            'Girdin ($userScore P)',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.green.shade100,
                          visualDensity: VisualDensity.compact,
                        );
                        listTileOnTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TrialExamLeaderboardScreen(
                                trialExamId: examId,
                                title: title,
                              ),
                            ),
                          );
                        };
                      } else if (status == ExamStatus.active) {
                        startExamCallback() {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TrialExamScreen(
                                trialExamId: examId,
                                title: title,
                                durationMinutes: durationMinutes,
                                questionCount: questionCount,
                              ),
                            ),
                          ).then((value) {
                            if (value == true && mounted) {
                              _loadUserResults();
                            }
                          });
                        }

                        ;
                        trailingWidget = ElevatedButton(
                          onPressed: startExamCallback,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          child: const Text('Başla'),
                        );
                        listTileOnTap = startExamCallback;
                      } else if (status == ExamStatus.finished) {
                        trailingWidget = Chip(
                          label: Text(
                            'Bitti',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.red.shade100,
                          visualDensity: VisualDensity.compact,
                        );
                        listTileOnTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TrialExamLeaderboardScreen(
                                trialExamId: examId,
                                title: title,
                              ),
                            ),
                          );
                        };
                      } else if (status == ExamStatus.upcoming) {
                        trailingWidget = Chip(
                          label: Text(
                            'Yakında',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.orange.shade100,
                          visualDensity: VisualDensity.compact,
                        );
                        listTileOnTap = () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bu sınav henüz başlamadı.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        };
                      } else {
                        trailingWidget = const Icon(
                          Icons.help_outline,
                          color: Colors.grey,
                        );
                        listTileOnTap = null;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: (status == ExamStatus.active && !hasTaken)
                            ? 2
                            : 0.8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: Icon(
                            status == ExamStatus.active
                                ? Icons.play_circle_fill_rounded
                                : status == ExamStatus.upcoming
                                ? Icons.timer_outlined
                                : status == ExamStatus.finished
                                ? Icons.history_edu_rounded
                                : Icons.help_outline,
                            color: status == ExamStatus.active
                                ? (hasTaken
                                      ? Colors.green.shade700
                                      : colorScheme.primary)
                                : status == ExamStatus.upcoming
                                ? Colors.orange.shade700
                                : status == ExamStatus.finished
                                ? (hasTaken
                                      ? Colors.green.shade700
                                      : Colors.red.shade700)
                                : Colors.grey,
                            size: 28,
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: TimeDifferenceDisplay(
                            // Göz kırpmayı önleyen widget
                            startTime: startTime,
                            endTime: endTime,
                            status: status, // <<< Artık doğru tipi kullanıyor
                          ),
                          trailing: trailingWidget,
                          onTap: listTileOnTap,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoadingResults ? null : _loadUserResults,
        tooltip: 'Sonuçları Yenile',
        icon: const Icon(Icons.refresh),
        label: const Text('Yenile'),
      ),
    );
  }
}

// enum ExamStatus tanımı buradan SİLİNDİ.
