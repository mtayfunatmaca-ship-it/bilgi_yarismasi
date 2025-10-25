import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// trial_exam_review_screen import'u kaldırıldı

class ResultScreen extends StatelessWidget {
  // Sadece normal quizler için
  final String? quizId;
  final int? puan;
  final int? dogruSayisi;
  final int? soruSayisi;
  
  // Geçmişten gelenler için
  final bool fromHistory;
  final Map<String, dynamic>? solvedData; // Bu 'null' olabilir
  
  final bool isReplay; // Tekrar çözümü belirtmek için

  const ResultScreen({
    super.key,
    this.quizId,
    this.puan,
    this.dogruSayisi,
    this.soruSayisi,
    required this.fromHistory,
    this.solvedData,
    this.isReplay = false,
    // Deneme sınavı parametreleri kaldırıldı
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- HATA DÜZELTMESİ BURADA ---
    // 'solvedData' null olabileceğinden, '?' ile güvenli erişim yap
    final int finalPuan = puan ?? (solvedData?['puan'] as num? ?? 0).toInt();
    final int finalDogru = dogruSayisi ?? (solvedData?['dogruSayisi'] as num? ?? 0).toInt();
    
    int finalToplamSoru = soruSayisi ?? 0;
    // solvedData null değilse içini kontrol et
    if (finalToplamSoru == 0 && solvedData != null) { 
       finalToplamSoru = (solvedData?['dogruSayisi'] as num? ?? 0).toInt() + (solvedData?['yanlisSayisi'] as num? ?? 0).toInt();
    }
    // Güvenlik için ek kontrol
    if (finalToplamSoru == 0 && dogruSayisi != null && soruSayisi != null) {
       finalToplamSoru = soruSayisi!;
    }
    
    final String finalBaslik = solvedData?['quizBaslik'] ?? 'Sonuç';
    // --- DÜZELTME BİTTİ ---

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(fromHistory ? 'Geçmiş Sonuç' : 'Test Bitti!'),
          centerTitle: true,
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
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Icon(
                  (finalDogru / (finalToplamSoru > 0 ? finalToplamSoru : 1)) >= 0.5 ? Icons.emoji_events : Icons.sentiment_satisfied_alt,
                  color: (finalDogru / (finalToplamSoru > 0 ? finalToplamSoru : 1)) >= 0.5 ? Colors.amber.shade700 : colorScheme.primary,
                  size: 100,
                ),
                const SizedBox(height: 24),
                Text(
                  (finalDogru / (finalToplamSoru > 0 ? finalToplamSoru : 1)) >= 0.5 ? 'Tebrikler!' : 'Güzel Denedin!',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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

                // --- Tekrar Çözüm Uyarı Mesajı ---
                if (isReplay && !fromHistory)
                  Padding(
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
                // --- Mesaj Bitti ---

                const SizedBox(height: 24),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Toplam Soru', finalToplamSoru.toString(), Colors.grey.shade700),
                        _buildStatColumn('Doğru', finalDogru.toString(), Colors.green.shade700),
                        _buildStatColumn('Yanlış', (finalToplamSoru - finalDogru).toString(), Colors.red.shade700),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- Deneme sınavı butonları (İncele, Sıralama) kaldırıldı ---

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // Statü sütunu
  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
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