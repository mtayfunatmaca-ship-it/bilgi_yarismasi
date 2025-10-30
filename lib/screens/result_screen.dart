import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Future.delayed için

// --- YENİ IMPORTLAR (Reklam ve PRO Kontrolü için) ---
import 'package:provider/provider.dart';
import 'package:bilgi_yarismasi/services/user_data_provider.dart';
import 'package:bilgi_yarismasi/services/ad_service.dart';
// --- BİTTİ ---

// --- YENİ IMPORTLAR (Cevap İnceleme için) ---
import 'package:bilgi_yarismasi/screens/trial_exam_review_screen.dart';
import 'package:bilgi_yarismasi/screens/purchase_screen.dart';
// --- BİTTİ ---

class ResultScreen extends StatefulWidget {
  // Normal quizler için
  final String? quizId;
  final int? puan;
  final int? dogruSayisi;
  final int? soruSayisi;

  // Geçmişten gelenler için
  final bool fromHistory;
  final Map<String, dynamic>? solvedData;

  final bool isReplay;

  // Başarı popup'ı için
  final List<Map<String, dynamic>>? newAchievements;

  // --- YENİ PARAMETRELER (Cevap İnceleme için QuizScreen'den geldi) ---
  final List<DocumentSnapshot>? questions;
  final Map<int, int>? userAnswers;
  final Map<int, int>? correctAnswers;
  final String? trialExamTitle; // (QuizScreen'deki 'quizBaslik' buraya gelecek)
  // --- BİTTİ ---

  const ResultScreen({
    super.key,
    this.quizId,
    this.puan,
    this.dogruSayisi,
    this.soruSayisi,
    required this.fromHistory,
    this.solvedData,
    this.isReplay = false,
    this.newAchievements,
    // Yeni parametreler
    this.questions,
    this.userAnswers,
    this.correctAnswers,
    this.trialExamTitle,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();

    // Başarıları Gösterme Tetikleyicisi
    if (widget.newAchievements != null && widget.newAchievements!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEarnedAchievements(widget.newAchievements!);
      });
    }
  }

  // Başarıları sırayla gösterme
  Future<void> _showEarnedAchievements(
    List<Map<String, dynamic>> achievements,
  ) async {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    for (var achievementData in achievements) {
      if (mounted) {
        await _showAchievementEarnedDialog(achievementData);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  // Başarı Popup'ı (Tam Kod)
  Future<void> _showAchievementEarnedDialog(
    Map<String, dynamic> achievementData,
  ) async {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    if (!mounted) return;
    final emoji = achievementData['emoji'] as String? ?? '🏆';
    final name = achievementData['name'] as String? ?? 'Başarı';
    final description = achievementData['description'] as String? ?? '';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade700, Colors.purple.shade700],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Tebrikler!",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Harika!",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- YENİ FONKSİYON: PRO Uyarı Dialog'u ---
  void _showProFeatureDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            Icons.lock_person_rounded,
            color: colorScheme.primary,
            size: 48,
          ),
          title: const Text(
            'PRO Özellik',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Test cevaplarınızı incelemek için PRO üyeliğe geçiş yapmanız gerekmektedir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PurchaseScreen(),
                  ),
                );
              },
              child: const Text('PRO\'ya Geç'),
            ),
          ],
        );
      },
    );
  }
  // --- BİTTİ ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- Provider'ları oku ---
    final bool isPro = context.watch<UserDataProvider>().isPro;
    final adService = context.read<AdService>();
    // --- BİTTİ ---

    // --- GÜNCELLENDİ: Veri belirleme ---
    final int finalPuan =
        widget.puan ?? (widget.solvedData?['puan'] as num? ?? 0).toInt();
    final int finalDogru =
        widget.dogruSayisi ??
        (widget.solvedData?['dogruSayisi'] as num? ?? 0).toInt();

    int finalToplamSoru = widget.soruSayisi ?? 0;
    if (finalToplamSoru == 0 && widget.solvedData != null) {
      finalToplamSoru = (widget.solvedData?['totalQuestions'] as num? ?? 0)
          .toInt(); // Geçmişten gelen veri
      if (finalToplamSoru == 0) {
        // 'totalQuestions' yoksa eski yöntemi dene
        finalToplamSoru =
            (widget.solvedData?['dogruSayisi'] as num? ?? 0).toInt() +
            (widget.solvedData?['yanlisSayisi'] as num? ?? 0).toInt();
      }
    }

    final String finalBaslik =
        widget.trialExamTitle ?? widget.solvedData?['quizBaslik'] ?? 'Sonuç';

    // "Cevapları İncele" butonu için verilerin gelip gelmediğini kontrol et
    final bool canReview =
        (widget.questions != null &&
        widget.userAnswers != null &&
        widget.correctAnswers != null);
    // --- GÜNCELLEME BİTTİ ---

    // Reklamı tetikleyen kapatma eylemi
    void closeScreenAction() {
      if (!widget.fromHistory) {
        adService.showInterstitialAd(
          isProUser: isPro,
          onAdDismissed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context, true);
            }
          },
        );
      } else {
        Navigator.pop(context, true);
      }
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        closeScreenAction();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fromHistory ? 'Geçmiş Sonuç' : 'Test Bitti!'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: closeScreenAction,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  finalBaslik,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Icon(
                  (finalDogru / (finalToplamSoru > 0 ? finalToplamSoru : 1)) >=
                          0.5
                      ? Icons.emoji_events
                      : Icons.sentiment_satisfied_alt,
                  color:
                      (finalDogru /
                              (finalToplamSoru > 0 ? finalToplamSoru : 1)) >=
                          0.5
                      ? Colors.amber.shade700
                      : colorScheme.primary,
                  size: 100,
                ),
                const SizedBox(height: 24),
                Text(
                  (finalDogru / (finalToplamSoru > 0 ? finalToplamSoru : 1)) >=
                          0.5
                      ? 'Tebrikler!'
                      : 'Güzel Denedin!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Puanınız: $finalPuan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (widget.isReplay && !widget.fromHistory)
                  Padding(
                    // ... (Tekrar çözüm uyarısı) ...
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Bu bir tekrar çözümdür. Puanınız toplam puana eklenmedi.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'Toplam Soru',
                          finalToplamSoru.toString(),
                          Colors.grey.shade700,
                        ),
                        _buildStatColumn(
                          'Doğru',
                          finalDogru.toString(),
                          Colors.green.shade700,
                        ),
                        _buildStatColumn(
                          'Yanlış',
                          (finalToplamSoru - finalDogru).toString(),
                          Colors.red.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- YENİ: "Cevapları İncele" Butonu (PRO Korumalı) ---
                if (canReview) // Sadece veriler geldiyse (yani geçmişten gelmiyorsa)
                  ElevatedButton.icon(
                    icon: Icon(
                      isPro ? Icons.rate_review_outlined : Icons.lock,
                      size: 18,
                    ),
                    label: Text(
                      isPro ? 'Cevapları İncele' : 'Cevapları İncele (PRO)',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: isPro
                          ? colorScheme.secondary
                          : colorScheme.surfaceVariant,
                      foregroundColor: isPro
                          ? colorScheme.onSecondary
                          : colorScheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (isPro) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrialExamReviewScreen(
                              questions: widget.questions!,
                              userAnswers: widget.userAnswers!,
                              correctAnswers: widget.correctAnswers!,
                              // Normal quizler 'trialExamId' kullanmaz, 'quizId' kullanır.
                              // ReviewScreen esnekse bunu 'title' olarak kullanabiliriz.
                              trialExamId: widget.quizId ?? 'quiz',
                              trialExamTitle: finalBaslik,
                            ),
                          ),
                        );
                      } else {
                        _showProFeatureDialog(context);
                      }
                    },
                  ),
                const SizedBox(height: 12),

                // --- BİTTİ ---
                ElevatedButton(
                  onPressed:
                      closeScreenAction, // <<< Reklamı tetikleyen fonksiyon
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
