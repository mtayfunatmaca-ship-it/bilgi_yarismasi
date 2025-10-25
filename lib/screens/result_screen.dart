import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Future.delayed için

class ResultScreen extends StatefulWidget { // <<< DEĞİŞİKLİK: StatefulWidget oldu
  // Normal quizler için
  final String? quizId;
  final int? puan;
  final int? dogruSayisi;
  final int? soruSayisi;
  
  // Geçmişten gelenler için
  final bool fromHistory;
  final Map<String, dynamic>? solvedData;
  
  final bool isReplay; // Tekrar çözümü belirtmek için

  // --- YENİ PARAMETRE (Başarı popup'ı için) ---
  final List<Map<String, dynamic>>? newAchievements;
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
    this.newAchievements, // <<< Eklendi
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> { // <<< DEĞİŞİKLİK: State sınıfı

  @override
  void initState() {
    super.initState();
    
    // --- YENİ: Başarıları Gösterme Tetikleyicisi ---
    if (widget.newAchievements != null && widget.newAchievements!.isNotEmpty) {
      // Ekran çizildikten HEMEN SONRA dialogları göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEarnedAchievements(widget.newAchievements!);
      });
    }
    // --- BİTTİ ---
  }

  // --- YENİ: Başarıları sırayla gösterme ---
  Future<void> _showEarnedAchievements(List<Map<String, dynamic>> achievements) async {
    for (var achievementData in achievements) {
      if (mounted) { // Hala bu ekrandaysak
        // (await) Dialog kapanana kadar bekler
        await _showAchievementEarnedDialog(achievementData); 
        // Dialog'lar arası bekleme
        await Future.delayed(const Duration(milliseconds: 300)); 
      }
    }
  }

  // --- YENİ: Popup fonksiyonu buraya taşındı ---
  Future<void> _showAchievementEarnedDialog(Map<String, dynamic> achievementData) async {
     if (!mounted) return;
     final emoji = achievementData['emoji'] as String? ?? '🏆';
     final name = achievementData['name'] as String? ?? 'Başarı';
     final description = achievementData['description'] as String? ?? '';
     
     return showDialog<void>(
      context: context,
      barrierDismissible: false, // Dışarı tıklayarak kapatmayı engelle
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade700, Colors.purple.shade700]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)) ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 40)))),
                  const SizedBox(height: 20),
                  Text("Tebrikler!", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.9)), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(), // Sadece bu dialog'u kapat
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Harika!", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
          ),
        );
       },
     );
  }
  // --- YENİ FONKSİYONLAR BİTTİ ---


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Widget'a erişim (widget.puan, widget.solvedData vb.)
    final int finalPuan = widget.puan ?? (widget.solvedData?['puan'] as num? ?? 0).toInt();
    final int finalDogru = widget.dogruSayisi ?? (widget.solvedData?['dogruSayisi'] as num? ?? 0).toInt();
    
    int finalToplamSoru = widget.soruSayisi ?? 0;
    if (finalToplamSoru == 0 && widget.solvedData != null) { 
       finalToplamSoru = (widget.solvedData?['dogruSayisi'] as num? ?? 0).toInt() + (widget.solvedData?['yanlisSayisi'] as num? ?? 0).toInt();
    }
    if (finalToplamSoru == 0 && widget.dogruSayisi != null && widget.soruSayisi != null) {
       finalToplamSoru = widget.soruSayisi!;
    }
    
    final String finalBaslik = widget.solvedData?['quizBaslik'] ?? 'Sonuç';

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fromHistory ? 'Geçmiş Sonuç' : 'Test Bitti!'),
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

                // Tekrar Çözüm Uyarı Mesajı
                if (widget.isReplay && !widget.fromHistory)
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

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true); // <<< 'true' döndürerek QuizListScreen'i yenile
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