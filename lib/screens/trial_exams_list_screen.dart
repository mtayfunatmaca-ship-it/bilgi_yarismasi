import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_screen.dart';
// import 'package:intl/intl.dart'; // Artık burada değil, TimeDifferenceDisplay içinde
// import 'dart:async'; // Timer kaldırıldı

// TimeDifferenceDisplay widget'ını import et
import 'package:bilgi_yarismasi/widgets/time_display.dart';

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
  // Timer? _timer; // <<< KALDIRILDI

  @override
  void initState() {
    super.initState();
    _loadUserResults();
    // Timer başlatma kodu <<< KALDIRILDI
  }

  @override
  void dispose() {
    // _timer?.cancel(); // <<< KALDIRILDI
    super.dispose();
  }

  Future<void> _loadUserResults() async {
    // Bu fonksiyon aynı kaldı
    if (!mounted) return;
    final user = _authService.currentUser;
    if (user == null) {
      setState(() => _isLoadingResults = false);
      return;
    }
    setState(() => _isLoadingResults = true);
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

  // Tarih formatlama fonksiyonu artık burada gerekli değil (_formatTimestamp kaldırıldı)
  // Süre formatlama fonksiyonu artık burada gerekli değil (_formatDuration kaldırıldı)

  @override
  Widget build(BuildContext context) {
    final now =
        DateTime.now(); // Şimdiki zamanı al (sadece status hesaplamak için)

    return Scaffold(
      appBar: AppBar(title: const Text('Deneme Sınavları')),
      body: _isLoadingResults
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('trialExams')
                  .orderBy('startTime')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Sınav listesi hatası: ${snapshot.error}"); // Hata logu
                  return const Center(child: Text('Sınavlar yüklenemedi.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aktif deneme sınavı bulunmuyor.'),
                  );
                }

                var examDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: examDocs.length,
                  itemBuilder: (context, index) {
                    var exam = examDocs[index];
                    var examId = exam.id;
                    var examData =
                        exam.data() as Map<String, dynamic>? ??
                        {}; // Null check

                    final String title = examData['title'] ?? 'Başlıksız Sınav';
                    final Timestamp? startTimeTs = examData['startTime'];
                    final Timestamp? endTimeTs = examData['endTime'];
                    final DateTime? startTime = startTimeTs?.toDate();
                    final DateTime? endTime = endTimeTs?.toDate();
                    final int durationMinutes =
                        (examData['durationMinutes'] as num? ?? 30).toInt();
                    final int questionCount =
                        (examData['questionCount'] as num? ?? 0).toInt();

                    // Sınavın durumu
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

                    // Kullanıcı girmiş mi?
                    final bool hasTaken = _userResults.containsKey(examId);
                    final userResultData = hasTaken
                        ? _userResults[examId]?.data() as Map<String, dynamic>?
                        : null;
                    final int? userScore = hasTaken
                        ? (userResultData?['score'] as num?)?.toInt()
                        : null;

                    Widget trailingWidget;
                    VoidCallback? startExamCallback; // Başlatma fonksiyonu

                    if (hasTaken) {
                      trailingWidget = Chip(
                        label: Text(
                          'Girdin ($userScore P)',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 12,
                          ),
                        ), // Boyut küçültüldü
                        backgroundColor: Colors.green.shade100,
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ), // Padding ayarlandı
                        visualDensity:
                            VisualDensity.compact, // Daha kompakt görünüm
                      );
                    } else if (status == ExamStatus.active) {
                      startExamCallback = () {
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
                      };
                      trailingWidget = ElevatedButton(
                        onPressed: startExamCallback,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ), // Padding
                          textStyle: TextStyle(fontSize: 13), // Yazı boyutu
                        ),
                        child: const Text('Başla'),
                      );
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                      );
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    } else {
                      // Unknown
                      trailingWidget = const Icon(
                        Icons.help_outline,
                        color: Colors.grey,
                      );
                    }

                    // ListTile onTap callback'i
                    VoidCallback? listTileOnTap =
                        (status == ExamStatus.active && !hasTaken)
                        ? startExamCallback
                        : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: status == ExamStatus.active && !hasTaken
                          ? 2
                          : 0.8, // Gölge ayarlandı
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ), // Köşe yuvarlatıldı
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ), // İç boşluk
                        leading: Icon(
                          status == ExamStatus.active
                              ? Icons.play_circle_fill_rounded
                              : status == ExamStatus.upcoming
                              ? Icons.timer_outlined
                              : status == ExamStatus.finished
                              ? Icons
                                    .history_edu_rounded // Biten ikon değişti
                              : Icons.help_outline,
                          color: status == ExamStatus.active
                              ? (hasTaken
                                    ? Colors.green.shade700
                                    : Theme.of(context)
                                          .colorScheme
                                          .primary) // Renkler ayarlandı
                              : status == ExamStatus.upcoming
                              ? Colors.orange.shade700
                              : status == ExamStatus.finished
                              ? (hasTaken
                                    ? Colors.green.shade700
                                    : Colors.red.shade700)
                              : Colors.grey,
                          size: 28, // İkon boyutu
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: TimeDifferenceDisplay(
                          // <<< YENİ WIDGET KULLANILDI
                          startTime: startTime,
                          endTime: endTime,
                          status: status,
                        ),
                        trailing: trailingWidget,
                        onTap:
                            listTileOnTap, // Aktif ve çözülmemişse tıklanabilir
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        // Extended FAB
        onPressed: _isLoadingResults ? null : _loadUserResults,
        tooltip: 'Sonuçları Yenile',
        icon: const Icon(Icons.refresh),
        label: const Text('Yenile'), // Etiket eklendi
        isExtended: true, // Başta açık olsun
        // shrinkWrap: true, // Kaydırınca küçülsün mü? - Gerek yok
      ),
    );
  }
}

// ExamStatus enum'ı burada veya time_display.dart içinde tanımlı olmalı
// enum ExamStatus { upcoming, active, finished, unknown }
