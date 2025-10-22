import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class TrialExamLeaderboardScreen extends StatefulWidget {
  final String trialExamId;
  final String title;

  const TrialExamLeaderboardScreen({
    super.key,
    required this.trialExamId,
    required this.title,
  });

  @override
  State<TrialExamLeaderboardScreen> createState() =>
      _TrialExamLeaderboardScreenState();
}

class _TrialExamLeaderboardScreenState
    extends State<TrialExamLeaderboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: textTheme.titleMedium),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // --- YENİ SORGUMUZ (INDEX GEREKTİRECEK) ---
        stream: _firestore
            .collectionGroup('trialExamResults') // TÜM alt koleksiyonlarda ara
            .where(
              'trialExamId',
              isEqualTo: widget.trialExamId,
            ) // Sadece bu sınava ait olanları
            .orderBy('score', descending: true) // Puana göre sırala
            .limit(100) // İlk 100'ü al
            .snapshots(),

        // --- SORGU BİTTİ ---
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Deneme sıralama hatası: ${snapshot.error}");
            // İlk çalıştırmada hata alacaksınız (Adım 4'e bakın)
            return _buildErrorState(
              colorScheme,
              textTheme,
              'Sıralama yüklenemedi. Firestore Index\'ini oluşturdunuz mu?',
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(
              colorScheme,
              textTheme,
              'Bu sınava henüz kimse katılmamış.',
            );
          }

          var userDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: userDocs.length,
            itemBuilder: (context, index) {
              final userData = userDocs[index].data() as Map<String, dynamic>;
              final rank = index + 1;
              // Veriyi kaydederken 'userId' eklediğimiz için buradan okuyabiliriz
              final bool isCurrentUser = userData['userId'] == _currentUserId;

              // Podyum veya liste elemanı için (basit liste kullanalım)
              return _buildUserListItem(
                userData: userData,
                rank: rank,
                isCurrentUser: isCurrentUser,
                colorScheme: colorScheme,
                textTheme: textTheme,
              );
            },
          );
        },
      ),
    );
  }

  // --- Liderlik Listesi için Yardımcı Widget'lar (LeaderboardScreen'den alındı) ---

  Widget _buildUserListItem({
    required Map<String, dynamic> userData,
    required int rank,
    required bool isCurrentUser,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final puan = (userData['score'] as num? ?? 0)
        .toInt(); // 'puanField' yerine 'score'
    final kullaniciAdi = userData['kullaniciAdi'] ?? 'İsimsiz';
    final emoji = userData['emoji'] ?? '🙂';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: colorScheme.primary, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Text(
          '$rank.',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                kullaniciAdi,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: isCurrentUser
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Text(
          '$puan Puan',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildErrorState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: colorScheme.error,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bir hata oluştu',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.leaderboard_outlined,
                color: colorScheme.primary,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Yardımcı Widget'lar Bitti ---
}
