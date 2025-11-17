import 'package:bilgi_yarismasi/screens/purchase_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_review_screen.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_leaderboard_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:bilgi_yarismasi/services/user_data_provider.dart';
// --- YENİ IMPORT (Reklam Servisi) ---
import 'package:bilgi_yarismasi/services/ad_service.dart';
// --- BİTTİ ---

class TrialExamResultScreen extends StatefulWidget {
  // ... (parametreler aynı) ...
  final String title;
  final double kpssPuan;
  final double netSayisi;
  final int dogruSayisi;
  final int yanlisSayisi;
  final int bosSayisi;
  final int soruSayisi;
  final Map<String, Map<String, int>> statsByCategory;
  final Map<String, String> categoryNameMap;
  final List<DocumentSnapshot> questions;
  final Map<int, int> userAnswers;
  final Map<int, int> correctAnswers;
  final String trialExamId;
  final String trialExamTitle;
  final List<Map<String, dynamic>>? newAchievements;

  const TrialExamResultScreen({
    super.key,
    required this.title,
    required this.kpssPuan,
    required this.netSayisi,
    required this.dogruSayisi,
    required this.yanlisSayisi,
    required this.bosSayisi,
    required this.soruSayisi,
    required this.statsByCategory,
    required this.categoryNameMap,
    required this.questions,
    required this.userAnswers,
    required this.correctAnswers,
    required this.trialExamId,
    required this.trialExamTitle,
    this.newAchievements,
  });

  @override
  State<TrialExamResultScreen> createState() => _TrialExamResultScreenState();
}

class _TrialExamResultScreenState extends State<TrialExamResultScreen> {
  // (Bu ekranda Banner Ad yok, o yüzden o kodlar kaldırıldı)

  @override
  void initState() {
    super.initState();

    // --- YENİ KOD: Başarımları gösterdikten sonra reklamı göster ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.newAchievements != null &&
          widget.newAchievements!.isNotEmpty) {
        _showEarnedAchievements(widget.newAchievements!).then((_) {
          _showInterstitialAd();
        });
      } else {
        _showInterstitialAd();
      }
    });
    // --- BİTTİ ---
  }

  // --- YENİ FONKSİYON: Reklamı gösterme mantığı ---
  void _showInterstitialAd() {
    // initState içinde context kullanılabilmesi için bu yöntem tercih edilir.
    final adService = context.read<AdService>();
    final isPro = context.read<UserDataProvider>().isPro;

    if (!isPro) {
      // PRO kullanıcı değilse reklamı göster
      adService.showTrialExamInterstitialAd(
        isProUser: isPro,
        onAdDismissed: () {
          // Reklam kapatıldıktan sonra yapılacak özel bir işlem yok.
          // Ekranın akışı devam edecek.
        },
      );
    }
  }
  // --- BİTTİ ---

  // --- Kalan fonksiyonlar (showAchievements, showProDialog, buildStatColumn) aynı ---
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

  void _showProFeatureDialog(BuildContext context) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
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
            'Deneme sınavı cevaplarınızı detaylı incelemek için PRO üyeliğe geçiş yapmanız gerekmektedir.',
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

  Widget _buildStatColumn(String label, String value, Color color) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- YENİ KOD: Provider'ları oku ---
    final bool isPro = context.watch<UserDataProvider>().isPro;
    // final adService = context.read<AdService>(); // Artık burada kullanmayacağız
    // --- BİTTİ ---

    final double finalPuan = widget.kpssPuan > 100.0 ? 100.0 : widget.kpssPuan;
    // final bool isSuccessful = finalPuan >= 70; // Kullanılmadığı için kaldırılabilir

    final sortedCategories = widget.statsByCategory.entries.toList()
      ..sort((a, b) {
        final nameA = widget.categoryNameMap[a.key] ?? a.key;
        final nameB = widget.categoryNameMap[b.key] ?? b.key;
        return nameA.compareTo(nameB);
      });

    // --- GÜNCELLEME: closeScreenAction artık reklam göstermeyecek ---
    void closeScreenAction() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true); // Sadece ekranı kapat
      }
    }
    // --- GÜNCELLEME BİTTİ ---

    return PopScope(
      canPop: false, // Manuel yöneteceğiz
      onPopInvoked: (didPop) {
        if (didPop) return;
        closeScreenAction(); // <<< Geri tuşu artık sadece ekranı kapatır
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Deneme Sonucu'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed:
                closeScreenAction, // <<< AppBar geri tuşu artık sadece ekranı kapatır
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ... (İçeriğin kalanı aynı) ...
              Text(
                widget.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 8),
              Text(
                'KPSS Puanınız:',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                finalPuan.toStringAsFixed(3),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
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
                        'Doğru',
                        widget.dogruSayisi.toString(),
                        Colors.green.shade700,
                      ),
                      _buildStatColumn(
                        'Yanlış',
                        widget.yanlisSayisi.toString(),
                        Colors.red.shade700,
                      ),
                      _buildStatColumn(
                        'Boş',
                        widget.bosSayisi.toString(),
                        Colors.grey.shade700,
                      ),
                      _buildStatColumn(
                        'TOPLAM NET',
                        widget.netSayisi.toStringAsFixed(2),
                        colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Derslere Göre Döküm',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Ders Adı',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'D',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Y',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'B',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Net',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedCategories.length,
                      itemBuilder: (context, index) {
                        final katEntry = sortedCategories[index];
                        final katId = katEntry.key;
                        final data = katEntry.value;
                        final katAdi = widget.categoryNameMap[katId] ?? 'Diğer';
                        final double katNet =
                            (data['correct'] ?? 0) -
                            ((data['wrong'] ?? 0) * 0.25);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? colorScheme.surface.withOpacity(0.5)
                                : Colors.transparent,
                            borderRadius: index == sortedCategories.length - 1
                                ? const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  katAdi,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${data['correct']}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${data['wrong']}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${data['empty']}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  katNet.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // "Cevapları İncele" (PRO Korumalı)
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
                  elevation: isPro ? 2 : 0,
                ),
                onPressed: () {
                  if (isPro) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrialExamReviewScreen(
                          questions: widget.questions,
                          userAnswers: widget.userAnswers,
                          correctAnswers: widget.correctAnswers,
                          trialExamId: widget.trialExamId,
                          trialExamTitle: widget.trialExamTitle,
                        ),
                      ),
                    );
                  } else {
                    _showProFeatureDialog(context);
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const FaIcon(FontAwesomeIcons.trophy, size: 18),
                label: const Text('Sıralamanı Gör'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrialExamLeaderboardScreen(
                        trialExamId: widget.trialExamId,
                        title: widget.trialExamTitle,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed:
                    closeScreenAction, // <<< Kapat butonu artık sadece ekranı kapatır
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: colorScheme.surfaceVariant,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ),
        // (Banner reklam bu ekrandan kaldırıldı, isteğin üzerine)
        // bottomNavigationBar: null,
      ),
    );
  }
}
