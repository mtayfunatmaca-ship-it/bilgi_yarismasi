import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_screen.dart';
import 'package:bilgi_yarismasi/widgets/time_display.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_leaderboard_screen.dart';
import 'package:bilgi_yarismasi/utils/exam_status.dart'; // Paylaşılan enum importu

class TrialExamsListScreen extends StatefulWidget {
  const TrialExamsListScreen({super.key});

  @override
  State<TrialExamsListScreen> createState() => _TrialExamsListScreenState();
}

class _TrialExamsListScreenState extends State<TrialExamsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  Map<String, DocumentSnapshot> _userResults = {};
  bool _isLoadingResults = true;

  @override
  void initState() {
    super.initState();
    _loadUserResults();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Kullanıcının deneme sınavı sonuçlarını yükler
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deneme Sınavları'),
        centerTitle: true,
        elevation: 1,
        backgroundColor: colorScheme.surface,
      ),
      backgroundColor: colorScheme.background,
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
                  color: colorScheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: examDocs.length,
                    itemBuilder: (context, index) {
                      var exam = examDocs[index];
                      var examId = exam.id;
                      var examData = exam.data() as Map<String, dynamic>? ?? {};

                      // Sınav verilerini al
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

                      // Durumu hesapla
                      ExamStatus status = ExamStatus.upcoming;
                      if (startTime != null && now.isBefore(startTime))
                        status = ExamStatus.upcoming;
                      else if (endTime != null && now.isAfter(endTime))
                        status = ExamStatus.finished;
                      else if (startTime != null &&
                          endTime != null &&
                          now.isAfter(startTime) &&
                          now.isBefore(endTime))
                        status = ExamStatus.active;
                      else
                        status = ExamStatus.unknown;

                      // Kullanıcı girmiş mi?
                      final bool hasTaken = _userResults.containsKey(examId);
                      final userResultData = hasTaken
                          ? _userResults[examId]?.data()
                                as Map<String, dynamic>?
                          : null;
                      final int? userScore = hasTaken
                          ? (userResultData?['score'] as num?)?.toInt()
                          : null;

                      // --- YENİ RENK, İKON VE İÇERİK MANTIĞI ---
                      Color statusColor;
                      Color cardBackgroundColor;
                      Color contentColor;
                      IconData leadingIcon;
                      Widget trailingWidget;
                      VoidCallback? listTileOnTap;
                      String subtitleText = '';

                      // 1. GİRİLMİŞ (hasTaken == true) -> İsteğin üzerine KIRMIZI
                      if (hasTaken) {
                        statusColor = Colors.red.shade700;
                        cardBackgroundColor = Colors.red.shade50.withOpacity(
                          0.6,
                        );
                        contentColor = Colors.red.shade900;
                        leadingIcon =
                            Icons.history_edu_rounded; // 'Geçmiş' ikonu
                        subtitleText =
                            'Girdin | Puan: $userScore | Sıralamayı Gör';

                        listTileOnTap = () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrialExamLeaderboardScreen(
                              trialExamId: examId,
                              title: title,
                            ),
                          ),
                        );
                      }
                      // 2. AKTİF (girilmemiş) -> İsteğin üzerine YEŞİL
                      else if (status == ExamStatus.active) {
                        statusColor = Colors.green.shade600;
                        cardBackgroundColor = Colors.green.shade50;
                        contentColor = Colors.green.shade800;
                        leadingIcon = Icons.play_circle_fill_rounded;
                        subtitleText = 'SINAV ŞİMDİ AKTİF!';

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
                            if (value == true && mounted) _loadUserResults();
                          });
                        }

                        trailingWidget = ElevatedButton(
                          onPressed: startExamCallback,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: statusColor, // Yeşil buton
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Başla'),
                        );
                        listTileOnTap = startExamCallback;
                      }
                      // 3. YAKINDA -> İsteğin üzerine TURUNCU
                      else if (status == ExamStatus.upcoming) {
                        statusColor = Colors.orange.shade700;
                        cardBackgroundColor = Colors.orange.shade50;
                        contentColor = Colors.orange.shade900;
                        leadingIcon = Icons.timer_outlined; // Zamanlayıcı ikonu

                        trailingWidget = Chip(
                          label: Text(
                            'Yakında',
                            style: TextStyle(
                              color: contentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: contentColor.withOpacity(0.1),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        );
                        listTileOnTap = () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bu sınav henüz başlamadı.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                      }
                      // 4. BİTMİŞ (girilmemiş) -> İsteğin üzerine KIRMIZI
                      else if (status == ExamStatus.finished) {
                        statusColor = Colors.red.shade700;
                        cardBackgroundColor = Colors.red.shade50.withOpacity(
                          0.6,
                        );
                        contentColor = Colors.red.shade900;
                        leadingIcon = Icons.cancel_rounded; // Kaçırıldı ikonu
                        subtitleText =
                            'Bu sınav bitti (Kaçırdın). Sıralamaya bak.';

                        trailingWidget = OutlinedButton(
                          onPressed: () {}, // onTap halledecek
                          style: OutlinedButton.styleFrom(
                            foregroundColor: contentColor,
                            side: BorderSide(
                              color: contentColor.withOpacity(0.4),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Sıralama'),
                        );
                        listTileOnTap = () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrialExamLeaderboardScreen(
                              trialExamId: examId,
                              title: title,
                            ),
                          ),
                        );
                      }
                      // 5. BİLİNMEYEN (Gri)
                      else {
                        statusColor = Colors.grey;
                        cardBackgroundColor = colorScheme.surfaceVariant
                            .withOpacity(0.5);
                        contentColor = colorScheme.onSurfaceVariant;
                        leadingIcon = Icons.help_outline;
                        subtitleText = 'Sınav tarihi belirsiz.';
                        trailingWidget = const Icon(
                          Icons.help_outline,
                          color: Colors.grey,
                        );
                        listTileOnTap = null;
                      }
                      // --- MANTIK BİTTİ ---

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: (status == ExamStatus.active && !hasTaken)
                            ? 3
                            : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: statusColor.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: listTileOnTap,
                          borderRadius: BorderRadius.circular(
                            15,
                          ), // Kenarlığa uysun
                          child: Container(
                            color:
                                cardBackgroundColor, // Kartın arka plan rengi
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Sol İkon
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      leadingIcon,
                                      color: statusColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Orta Alan (Başlık ve Zaman/Durum)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Aktif veya Yakında ise Zamanlayıcıyı,
                                        // Bitmiş veya Girilmiş ise Durum Metnini göster
                                        (status == ExamStatus.active &&
                                                    !hasTaken) ||
                                                (status == ExamStatus.upcoming)
                                            ? TimeDifferenceDisplay(
                                                startTime: startTime,
                                                endTime: endTime,
                                                status: status,
                                              )
                                            : Text(
                                                subtitleText,
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: contentColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ),
                          ),
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
