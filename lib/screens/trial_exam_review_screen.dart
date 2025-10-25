import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrialExamReviewScreen extends StatelessWidget {
  final List<DocumentSnapshot> questions;
  final Map<int, int> userAnswers;
  final Map<int, int> correctAnswers;

  const TrialExamReviewScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.correctAnswers, required String trialExamId, required String trialExamTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cevapları İncele'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final questionDoc = questions[index];
          final questionData =
              questionDoc.data() as Map<String, dynamic>? ?? {};
          final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
          final options = List<String>.from(questionData['secenekler'] ?? []);
          final String? imageUrl = questionData['imageUrl'] as String?;

          final int? correctIndex = correctAnswers[index];
          final int? userIndex =
              userAnswers[index]; // Kullanıcının seçimi (null olabilir)

          final bool isCorrect =
              (userIndex != null && userIndex == correctIndex);
          final bool isSkipped = (userIndex == null); // Boş bırakılmış

          IconData statusIcon;
          Color statusColor;
          String statusText;

          if (isCorrect) {
            statusIcon = Icons.check_circle_rounded;
            statusColor = Colors.green.shade700;
            statusText = "Doğru";
          } else if (isSkipped) {
            statusIcon = Icons.radio_button_off_rounded;
            statusColor = Colors.grey.shade600;
            statusText = "Boş Bırakıldı";
          } else {
            // Yanlış
            statusIcon = Icons.cancel_rounded;
            statusColor = Colors.red.shade700;
            statusText = "Yanlış";
          }

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Soru Başlığı ve Durumu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Soru ${index + 1}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Soru Metni
                  Text(
                    questionText,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),

                  // Resim (varsa)
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(imageUrl, fit: BoxFit.contain),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Seçenekler
                  Column(
                    children: options.asMap().entries.map((entry) {
                      final optionIndex = entry.key;
                      final optionText = entry.value;

                      final bool isThisCorrect = (optionIndex == correctIndex);
                      final bool isThisSelected = (optionIndex == userIndex);

                      Color tileColor = colorScheme.surface;
                      Color textColor = colorScheme.onSurface;
                      Widget? trailingIcon;

                      if (isThisCorrect) {
                        // Bu DOĞRU CEVAP
                        tileColor = Colors.green.shade50;
                        textColor = Colors.green.shade900;
                        trailingIcon = Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green.shade700,
                        );
                      } else if (isThisSelected) {
                        // Bu kullanıcının seçtiği YANLIŞ CEVAP
                        tileColor = Colors.red.shade50;
                        textColor = Colors.red.shade900;
                        trailingIcon = Icon(
                          Icons.cancel_rounded,
                          color: Colors.red.shade700,
                        );
                      } else {
                        // Bu seçilmeyen yanlış cevap
                        textColor = colorScheme.onSurface.withOpacity(0.6);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: tileColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Text(
                            '${String.fromCharCode(65 + optionIndex)}.', // A, B, C...
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          title: Text(
                            optionText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: textColor,
                            ),
                          ),
                          trailing: trailingIcon,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
