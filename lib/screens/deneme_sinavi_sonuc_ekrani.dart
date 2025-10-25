import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_review_screen.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_leaderboard_screen.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TrialExamResultScreen extends StatelessWidget {
  final String title;
  final double kpssPuan;
  final double netSayisi;
  final int dogruSayisi;
  final int yanlisSayisi;
  final int bosSayisi;
  final int soruSayisi;
  
  // Kategori Dökümü
  final Map<String, Map<String, int>> statsByCategory;
  final Map<String, String> categoryNameMap;
  
  // İnceleme ve Sıralama
  final List<DocumentSnapshot> questions;
  final Map<int, int> userAnswers;
  final Map<int, int> correctAnswers;
  final String trialExamId;
  final String trialExamTitle;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final double finalPuan = kpssPuan > 100.0 ? 100.0 : kpssPuan;
    final bool isSuccessful = finalPuan >= 70;

    // Kategori listesini sırala (Map'i List'e çevir)
    final sortedCategories = statsByCategory.entries.toList()
      ..sort((a, b) {
         final nameA = categoryNameMap[a.key] ?? a.key;
         final nameB = categoryNameMap[b.key] ?? b.key;
         return nameA.compareTo(nameB);
      });


    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
         if (didPop) return;
         Navigator.pop(context, true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Deneme Sonucu'),
          centerTitle: true,
          leading: IconButton(
             icon: const Icon(Icons.arrow_back),
             onPressed: () => Navigator.pop(context, true),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Icon(
                isSuccessful ? Icons.school_rounded : Icons.sentiment_dissatisfied_rounded,
                color: isSuccessful ? Colors.green.shade700 : colorScheme.primary,
                size: 100,
              ),
              const SizedBox(height: 24),
              Text(
                isSuccessful ? 'Tebrikler!' : 'Daha İyi Olabilir!',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'KPSS Puanınız:',
                style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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
              
              // Toplam Net Detay Kartı
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Doğru', dogruSayisi.toString(), Colors.green.shade700),
                      _buildStatColumn('Yanlış', yanlisSayisi.toString(), Colors.red.shade700),
                      _buildStatColumn('Boş', bosSayisi.toString(), Colors.grey.shade700),
                      _buildStatColumn(
                        'TOPLAM NET', 
                        netSayisi.toStringAsFixed(2), 
                        colorScheme.primary
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Kategori Bazlı Döküm ---
              Text(
                'Derslere Göre Döküm',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Column(
                  children: [
                    // Başlık Satırı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text('Ders Adı', style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
                          Expanded(flex: 1, child: Text('D', textAlign: TextAlign.center, style: theme.textTheme.labelMedium?.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.w600))),
                          Expanded(flex: 1, child: Text('Y', textAlign: TextAlign.center, style: theme.textTheme.labelMedium?.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.w600))),
                          Expanded(flex: 1, child: Text('B', textAlign: TextAlign.center, style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Net', textAlign: TextAlign.right, style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    // Kategori Listesi
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedCategories.length,
                      itemBuilder: (context, index) {
                         final katEntry = sortedCategories[index];
                         final katId = katEntry.key;
                         final data = katEntry.value;
                         final katAdi = categoryNameMap[katId] ?? 'Diğer';
                         final double katNet = (data['correct'] ?? 0) - ((data['wrong'] ?? 0) * 0.25);
                         
                         return Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                           decoration: BoxDecoration(
                              color: index % 2 == 0 ? colorScheme.surface.withOpacity(0.5) : Colors.transparent,
                              borderRadius: index == sortedCategories.length - 1 ? const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)) : null,
                           ),
                           child: Row(
                             children: [
                               Expanded(flex: 3, child: Text(katAdi, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
                               Expanded(flex: 1, child: Text('${data['correct']}', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)),
                               Expanded(flex: 1, child: Text('${data['wrong']}', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)),
                               Expanded(flex: 1, child: Text('${data['empty']}', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)),
                               Expanded(flex: 2, child: Text(katNet.toStringAsFixed(2), textAlign: TextAlign.right, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary))),
                             ],
                           ),
                         );
                      },
                    ),
                  ],
                ),
              ),
              // --- Döküm Bitti ---

              const SizedBox(height: 32),
              
              // Butonlar
              ElevatedButton.icon(
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Cevapları İncele'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => TrialExamReviewScreen(
                         questions: questions,
                         userAnswers: userAnswers,
                         correctAnswers: correctAnswers,
                         trialExamId: trialExamId,
                         trialExamTitle: trialExamTitle,
                       ),
                     ),
                   );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const FaIcon(FontAwesomeIcons.trophy, size: 18),
                label: const Text('Sıralamanı Gör'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => TrialExamLeaderboardScreen(
                         trialExamId: trialExamId,
                         title: trialExamTitle,
                       ),
                     ),
                   );
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 14),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   backgroundColor: colorScheme.surfaceVariant,
                   foregroundColor: colorScheme.onSurfaceVariant,
                ),
                child: const Text('Kapat'),
              ),
            ],
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}