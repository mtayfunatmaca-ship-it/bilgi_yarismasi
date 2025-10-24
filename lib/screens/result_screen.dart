import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// YENİ İMPORT:
import 'package:bilgi_yarismasi/screens/trial_exam_review_screen.dart';

class ResultScreen extends StatelessWidget {
  // Eski parametreler (normal quizler için)
  final String? quizId;
  final int? puan;
  final int? dogruSayisi;
  final int? soruSayisi;

  // Sadece geçmişten gelenler için
  final bool fromHistory;
  final Map<String, dynamic>? solvedData;

  // --- YENİ PARAMETRELER (Deneme Sınavı İncelemesi için) ---
  final List<DocumentSnapshot>? questions; // Soruların tam listesi
  final Map<int, int>?
  userAnswers; // Kullanıcının cevapları (Index, SeçenekIndex)
  final Map<int, int>? correctAnswers; // Doğru cevaplar (Index, DoğruIndex)
  // --- YENİ PARAMETRELER BİTTİ ---

  const ResultScreen({
    super.key,
    this.quizId,
    this.puan,
    this.dogruSayisi,
    this.soruSayisi,
    required this.fromHistory,
    this.solvedData,
    this.questions, // Opsiyonel
    this.userAnswers, // Opsiyonel
    this.correctAnswers, // Opsiyonel
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Veriyi belirle (Yeni çözüldüyse parametreden, geçmişse solvedData'dan)
    final int finalPuan = puan ?? (solvedData?['puan'] as num? ?? 0).toInt();
    final int finalDogru =
        dogruSayisi ?? (solvedData?['dogruSayisi'] as num? ?? 0).toInt();
    final int finalToplamSoru =
        soruSayisi ??
        (solvedData?['totalQuestions'] as num? ?? 0)
            .toInt(); // Denemeden geleni de kontrol et
    final String finalBaslik =
        solvedData?['quizBaslik'] ?? solvedData?['title'] ?? 'Sonuç';

    final bool canReview =
        (questions != null &&
        userAnswers != null &&
        correctAnswers != null); // İnceleme yapılabilir mi?

    return PopScope(
      // Bu ekrandan geri tuşuyla çıkıldığında (pop) 'true' döndür
      // (Böylece TrialExamsListScreen kendini yenileyebilir)
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(fromHistory ? 'Geçmiş Sonuç' : 'Test Bitti!'),
          centerTitle: true,
          // Geri tuşuna da 'true' değerini ekle
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, true),
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
                  Icons.emoji_events,
                  color: Colors.amber.shade700,
                  size: 100,
                ),
                const SizedBox(height: 24),
                Text(
                  'Tebrikler!',
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
                const SizedBox(height: 24),
                // Skor detay kartı
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

                // --- YENİ BUTON: Cevapları İncele ---
                if (canReview) // Sadece deneme sınavından gelindiyse göster
                  ElevatedButton.icon(
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Cevapları İncele'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrialExamReviewScreen(
                            questions: questions!,
                            userAnswers: userAnswers!,
                            correctAnswers: correctAnswers!,
                          ),
                        ),
                      );
                    },
                  ),

                // --- YENİ BUTON BİTTİ ---
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // 'true' değeriyle geri dön
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  // Statü sütunu
  Widget _buildStatColumn(String label, String value, Color color) {
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
