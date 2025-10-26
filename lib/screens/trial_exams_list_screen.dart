import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_screen.dart';
import 'package:bilgi_yarismasi/widgets/time_display.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_leaderboard_screen.dart';
import 'package:bilgi_yarismasi/utils/exam_status.dart';
// --- YENİ IMPORTLAR ---
import 'package:provider/provider.dart';
import 'package:bilgi_yarismasi/services/user_data_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// --- BİTTİ ---

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

  ExamStatus _getExamStatus(Map<String, dynamic> examData, DateTime now) {
    final Timestamp? startTimeTs = examData['startTime'];
    final Timestamp? endTimeTs = examData['endTime'];
    final DateTime? startTime = startTimeTs?.toDate();
    final DateTime? endTime = endTimeTs?.toDate();

    if (startTime != null && now.isBefore(startTime)) {
      return ExamStatus.upcoming;
    } else if (endTime != null && now.isAfter(endTime)) {
      return ExamStatus.finished;
    } else if (startTime != null &&
        endTime != null &&
        now.isAfter(startTime) &&
        now.isBefore(endTime)) {
      return ExamStatus.active;
    }
    return ExamStatus.unknown;
  }

  int _getStatusPriority(ExamStatus status, bool hasTaken) {
    if (hasTaken) return 3; // Çözülenler
    switch (status) {
      case ExamStatus.active: return 1; // Aktif
      case ExamStatus.upcoming: return 2; // Yakında
      case ExamStatus.finished: return 4; // Biten
      case ExamStatus.unknown: default: return 5;
    }
  }

  // --- YENİ FONKSİYON: PRO Uyarı Dialog'u ---
  void _showProFeatureDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
         return AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           icon: Icon(Icons.lock_person_rounded, color: colorScheme.primary, size: 48),
           title: const Text('PRO Özellik', style: TextStyle(fontWeight: FontWeight.bold)),
           content: const Text('Bu deneme sınavı PRO üyelere özeldir. Tüm sınavlara erişmek için PRO üyeliğe geçiş yapın.'),
           actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
              ElevatedButton(
                onPressed: () {
                   Navigator.pop(context);
                   // TODO: Satın alma ekranını aç
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Satın alma ekranı yakında eklenecek!'))
                   );
                },
                child: const Text('PRO\'ya Geç'),
              ),
           ],
         );
      },
    );
  }
  // --- YENİ FONKSİYON BİTTİ ---

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // --- YENİ KOD: isPro durumunu Provider'dan oku ---
    final bool isPro = context.watch<UserDataProvider>().isPro;
    // --- BİTTİ ---

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
              // --- GÜNCELLEME: Sorguya 'isPublished' eklendi ---
              stream: _firestore
                  .collection('trialExams')
                  .where('isPublished', isEqualTo: true) // Sadece yayınlananları göster
                  .orderBy('startTime', descending: true)
                  .snapshots(),
              // --- SORGU GÜNCELLENDİ ---
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Sınav listesi hatası: ${snapshot.error}");
                  return Center(
                    child: Text('Sınavlar yüklenemedi.', style: TextStyle(color: colorScheme.error)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aktif deneme sınavı bulunmuyor.'),
                  );
                }

                var examDocs = snapshot.data!.docs;

                // --- SIRALAMA MANTIĞI (Aynı) ---
                final nowForSorting = DateTime.now();
                examDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>? ?? {};
                  final bData = b.data() as Map<String, dynamic>? ?? {};
                  final aHasTaken = _userResults.containsKey(a.id);
                  final bHasTaken = _userResults.containsKey(b.id);
                  final aStatus = _getExamStatus(aData, nowForSorting);
                  final bStatus = _getExamStatus(bData, nowForSorting);
                  final aPriority = _getStatusPriority(aStatus, aHasTaken);
                  final bPriority = _getStatusPriority(bStatus, bHasTaken);
                  if (aPriority != bPriority) {
                    return aPriority.compareTo(bPriority);
                  }
                  // ... (İkincil sıralama mantığı aynı) ...
                  final aStartTime = (aData['startTime'] as Timestamp?)?.toDate();
                  final bStartTime = (bData['startTime'] as Timestamp?)?.toDate();
                  final aEndTime = (aData['endTime'] as Timestamp?)?.toDate();
                  final bEndTime = (bData['endTime'] as Timestamp?)?.toDate();
                  final defaultPast = DateTime(1970);
                  final defaultFuture = DateTime(2099);
                  switch (aPriority) {
                    case 1: return (aEndTime ?? defaultFuture).compareTo(bEndTime ?? defaultFuture);
                    case 2: return (aStartTime ?? defaultFuture).compareTo(bStartTime ?? defaultFuture);
                    case 3:
                      final aResult = _userResults[a.id]?.data() as Map<String, dynamic>?;
                      final bResult = _userResults[b.id]?.data() as Map<String, dynamic>?;
                      final aCompTime = (aResult?['completionTime'] as Timestamp?)?.toDate();
                      final bCompTime = (bResult?['completionTime'] as Timestamp?)?.toDate();
                      return (bCompTime ?? defaultPast).compareTo(aCompTime ?? defaultPast);
                    case 4: return (bEndTime ?? defaultPast).compareTo(aEndTime ?? defaultPast);
                    default: return 0;
                  }
                });
                // --- SIRALAMA MANTIĞI SONU ---

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

                      final String title = examData['title'] ?? 'Başlıksız Sınav';
                      final DateTime? startTime = (examData['startTime'] as Timestamp?)?.toDate();
                      final DateTime? endTime = (examData['endTime'] as Timestamp?)?.toDate();
                      final int durationMinutes = (examData['durationMinutes'] as num? ?? 30).toInt();
                      final int questionCount = (examData['questionCount'] as num? ?? 0).toInt();
                      
                      // --- YENİ ALANLAR: isPro ve isPublished ---
                      final bool isProExam = examData['isPro'] ?? false;
                      // (isPublished zaten 'true' olmalı, sorgu yaptık)
                      // --- BİTTİ ---

                      final ExamStatus status = _getExamStatus(examData, now);
                      final bool hasTaken = _userResults.containsKey(examId);
                      final userResultData = hasTaken ? _userResults[examId]?.data() as Map<String, dynamic>? : null;
                      final int? userScore = hasTaken ? (userResultData?['score'] as num?)?.toInt() : null;

                      Color statusColor;
                      Color cardBackgroundColor;
                      Color contentColor;
                      IconData leadingIcon;
                      Widget? trailingWidget;
                      VoidCallback? listTileOnTap;
                      String subtitleText = '';
                      double elevation = 1;
                      BorderSide borderSide = BorderSide.none;

                      // --- GÜNCELLEME: PRO KİLİDİ MANTIĞI EKLENDİ ---
                      
                      // 1. GİRİLMİŞ
                      if (hasTaken) {
                        statusColor = Colors.red.shade700;
                        cardBackgroundColor = Colors.red.shade50.withOpacity(0.6);
                        contentColor = Colors.red.shade900;
                        leadingIcon = Icons.history_edu_rounded;
                        subtitleText = 'Girdin | Puan: $userScore | Sıralamayı Gör';
                        elevation = 0;
                        borderSide = BorderSide(color: statusColor.withOpacity(0.4), width: 1);
                        trailingWidget = Icon(Icons.arrow_forward_ios_rounded, color: contentColor, size: 18);
                        listTileOnTap = () => Navigator.push(context, MaterialPageRoute(
                              builder: (context) => TrialExamLeaderboardScreen(trialExamId: examId, title: title),
                            ));
                      } 
                      // 2. AKTİF (girilmemiş)
                      else if (status == ExamStatus.active) {
                        
                        // PRO SINAV, KULLANICI PRO DEĞİL
                        if (isProExam && !isPro) {
                           statusColor = Colors.orange.shade700; // Kilit rengi
                           cardBackgroundColor = Colors.orange.shade50;
                           contentColor = Colors.orange.shade900;
                           leadingIcon = Icons.lock_person_rounded; // Kilit ikonu
                           subtitleText = 'BU SINAV PRO ÜYELERE ÖZELDİR';
                           elevation = 2;
                           borderSide = BorderSide(color: statusColor.withOpacity(0.5), width: 1.5);
                           trailingWidget = ElevatedButton.icon(
                             icon: const Icon(Icons.workspace_premium, size: 16),
                             label: const Text('PRO'),
                             onPressed: () => _showProFeatureDialog(context),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: statusColor,
                               foregroundColor: Colors.white,
                             ),
                           );
                           listTileOnTap = () => _showProFeatureDialog(context);
                        } 
                        // PRO SINAV (KULLANICI PRO) veya NORMAL SINAV
                        else {
                           statusColor = Colors.green.shade600;
                           cardBackgroundColor = Colors.green.shade50;
                           contentColor = Colors.green.shade800;
                           leadingIcon = Icons.play_circle_fill_rounded;
                           subtitleText = 'SINAV ŞİMDİ AKTİF!';
                           elevation = 6;
                           borderSide = BorderSide(color: statusColor, width: 2.0);

                           startExamCallback() {
                               Navigator.push(context, MaterialPageRoute(
                                   builder: (context) => TrialExamScreen(
                                       trialExamId: examId, title: title, durationMinutes: durationMinutes, questionCount: questionCount,
                                   ),
                               )).then((value) { if (value == true && mounted) _loadUserResults(); });
                           }
                           trailingWidget = ElevatedButton(
                             onPressed: startExamCallback,
                             style: ElevatedButton.styleFrom(backgroundColor: statusColor, foregroundColor: Colors.white),
                             child: const Text('Başla'),
                           );
                           listTileOnTap = startExamCallback;
                        }
                      } 
                      // 3. YAKINDA
                      else if (status == ExamStatus.upcoming) {
                        statusColor = Colors.orange.shade700;
                        cardBackgroundColor = Colors.orange.shade50;
                        contentColor = Colors.orange.shade900;
                        leadingIcon = Icons.timer_outlined;
                        borderSide = BorderSide(color: statusColor.withOpacity(0.5), width: 1.5);
                        
                        trailingWidget = Chip(
                          label: Row( // PRO ise ikon ekle
                             children: [
                               if (isProExam) Icon(Icons.workspace_premium, size: 14, color: contentColor.withOpacity(0.7)),
                               if (isProExam) const SizedBox(width: 4),
                               Text('Yakında', style: TextStyle(color: contentColor, fontSize: 12, fontWeight: FontWeight.w500)),
                             ],
                          ),
                          backgroundColor: contentColor.withOpacity(0.1),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        );
                        listTileOnTap = () => ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Bu sınav henüz başlamadı.'), duration: Duration(seconds: 2))
                        );
                      } 
                      // 4. BİTMİŞ (girilmemiş/KAÇIRILMIŞ)
                      else if (status == ExamStatus.finished) {
                         statusColor = Colors.red.shade700;
                         cardBackgroundColor = Colors.red.shade50.withOpacity(0.6);
                         contentColor = Colors.red.shade900;
                         leadingIcon = Icons.cancel_rounded;
                         subtitleText = 'Bu sınav bitti (Kaçırdın)';
                         elevation = 0;
                         borderSide = BorderSide(color: statusColor.withOpacity(0.4), width: 1);
                         trailingWidget = OutlinedButton(
                           onPressed: () {
                             Navigator.push(context, MaterialPageRoute(
                                 builder: (context) => TrialExamLeaderboardScreen(trialExamId: examId, title: title),
                             ));
                           },
                           style: OutlinedButton.styleFrom(
                             foregroundColor: contentColor,
                             side: BorderSide(color: contentColor.withOpacity(0.4)),
                             visualDensity: VisualDensity.compact,
                           ),
                           child: const Text('Sıralama'),
                         );
                         listTileOnTap = () => Navigator.push(context, MaterialPageRoute(
                               builder: (context) => TrialExamLeaderboardScreen(trialExamId: examId, title: title),
                         ));
                      } 
                      // 5. BİLİNMEYEN
                      else {
                         statusColor = Colors.grey;
                         cardBackgroundColor = colorScheme.surfaceVariant.withOpacity(0.5);
                         contentColor = colorScheme.onSurfaceVariant;
                         leadingIcon = Icons.help_outline;
                         subtitleText = 'Sınav tarihi belirsiz.';
                         trailingWidget = const Icon(Icons.help_outline, color: Colors.grey);
                         listTileOnTap = null;
                         borderSide = BorderSide(color: statusColor.withOpacity(0.3), width: 1);
                      }
                      // --- MANTIK BİTTİ ---

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: elevation,
                        shadowColor: status == ExamStatus.active && !hasTaken ? Colors.green.withOpacity(0.5) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: borderSide,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: listTileOnTap,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            color: cardBackgroundColor,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(leadingIcon, color: statusColor, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        (status == ExamStatus.active && !hasTaken) || (status == ExamStatus.upcoming)
                                        ? TimeDifferenceDisplay(
                                            startTime: startTime,
                                            endTime: endTime,
                                            status: status,
                                          )
                                        : Text(
                                            subtitleText,
                                            style: textTheme.bodySmall?.copyWith(
                                              color: contentColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (trailingWidget != null) trailingWidget,
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