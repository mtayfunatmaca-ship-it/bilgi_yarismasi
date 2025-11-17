import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

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

class _TrialExamLeaderboardScreenState extends State<TrialExamLeaderboardScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  String? _currentUserId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _podiumAnimationController;
  late List<Animation<double>> _podiumAnimations;
  Stream<QuerySnapshot>? _examLeaderboardStream;

  late ConfettiController _confettiController;
  bool _isExamFinished = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;

    _initializeStream();
    _checkExamStatus();

    // Animasyonlar (Aynı)
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _podiumAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _podiumAnimations = List.generate(3, (index) {
      double beginInterval = index == 0 ? 0.4 : (index == 1 ? 0.2 : 0.0);
      double endInterval = index == 0 ? 1.0 : (index == 1 ? 0.8 : 0.6);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _podiumAnimationController,
          curve: Interval(beginInterval, endInterval, curve: Curves.elasticOut),
        ),
      );
    });

    // Konfeti Controller (Aynı)
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _animationController.forward();
    _podiumAnimationController.forward();

    FirebaseAnalytics.instance.logEvent(
      name: 'view_trial_leaderboard',
      parameters: {'exam_id': widget.trialExamId},
    );
  }

  void _initializeStream() {
    _examLeaderboardStream = _firestore
        .collectionGroup('trialExamResults')
        .where('trialExamId', isEqualTo: widget.trialExamId)
        .orderBy('score', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> _checkExamStatus() async {
    try {
      final examDoc = await _firestore
          .collection('trialExams')
          .doc(widget.trialExamId)
          .get();
      if (!examDoc.exists || !mounted) return;

      final data = examDoc.data() as Map<String, dynamic>;
      final Timestamp? endTimeTs = data['endTime'] as Timestamp?;

      if (endTimeTs != null) {
        final DateTime endTime = endTimeTs.toDate();
        if (DateTime.now().isAfter(endTime)) {
          setState(() {
            _isExamFinished = true;
          });
          _confettiController.play();
        }
      }
    } catch (e) {
      print("Sınav durumu kontrol hatası: $e");
    }
  }

  Future<void> _refreshData() async {
    _animationController.reset();
    _podiumAnimationController.reset();
    _animationController.forward();
    _podiumAnimationController.forward();
    setState(() {
      _initializeStream();
    });
    _checkExamStatus();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _podiumAnimationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            color: colorScheme.primary,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(
                    widget.title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  centerTitle: true,
                  pinned: true,
                  floating: true,
                  snap: true,
                  elevation: 1,
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildLeaderboardContent(
                      stream: _examLeaderboardStream!,
                      puanField: 'score',
                      currentUserId: _currentUserId,
                      emptyMessage:
                          'Bu deneme sınavına henüz kimse katılmamış.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Konfeti Widget'ı
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
              gravity: 0.1,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardContent({
    required Stream<QuerySnapshot> stream,
    required String puanField,
    required String? currentUserId,
    required String emptyMessage,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print("Deneme Sıralama Hatası: ${snapshot.error}");
          String errorMsg = 'Sıralama yüklenemedi. Lütfen tekrar deneyin.';
          if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
            errorMsg =
                'Sıralama için gerekli Firestore Index\'i oluşturulmamış.\nLütfen Debug Console\'daki linke tıklayın.';
          }
          return _buildErrorState(_refreshData, errorMsg);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (_podiumAnimationController.status == AnimationStatus.dismissed) {
            _podiumAnimationController.forward();
          }
          return _buildEmptyState(emptyMessage, context);
        }

        var userDocs = snapshot.data!.docs;
        final currentUserIndex = userDocs.indexWhere(
          (u) => _isCurrentUser(u, currentUserId),
        );
        final topThree = userDocs.take(3).toList();
        final otherUsers = userDocs.skip(3).toList();

        if (_podiumAnimationController.status == AnimationStatus.dismissed) {
          _podiumAnimationController.forward();
        }

        return Column(
          children: [
            if (_isExamFinished && topThree.isNotEmpty)
              _buildWinnerCard(
                topThree[0].data() as Map<String, dynamic>,
                puanField,
              ),

            if (topThree.isNotEmpty)
              _buildPodiumSection(topThree, puanField, currentUserId),
            if (otherUsers.isNotEmpty)
              _buildOtherUsersSection(
                otherUsers,
                puanField,
                currentUserId,
                currentUserIndex >= 3 ? currentUserIndex : -1,
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // --- GÜNCELLENDİ: Sınav Şampiyonu Kartı (KPSS Puanı 2 ondalık) ---
  Widget _buildWinnerCard(Map<String, dynamic> winnerData, String puanField) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String name = winnerData['kullaniciAdi'] ?? 'Bilinmiyor';
    final String emoji = winnerData['emoji'] ?? '🏆';
    final int puan = (winnerData[puanField] as num? ?? 0).toInt();
    final double kpssPuan = (winnerData['kpssPuan'] as num? ?? 0.0).toDouble();

    // KPSS Puanını virgülden sonra 2 basamakla formatla
    final String formattedKpssPuan = kpssPuan.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const FaIcon(
                FontAwesomeIcons.crown,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SINAV ŞAMPİYONU',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  name,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  // K-Puanı formatında gösterim
                  '$formattedKpssPuan K-Puanı ($puan Skor)',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Podyum Bölümü (Değişiklik yok)
  Widget _buildPodiumSection(
    List<QueryDocumentSnapshot> topThree,
    String puanField,
    String? currentUserId,
  ) {
    List<Widget> podiumItems = [];
    if (topThree.isNotEmpty) {
      podiumItems.add(
        ScaleTransition(
          scale: _podiumAnimations[0],
          child: _buildPodiumUser(
            userData: topThree[0].data() as Map<String, dynamic>,
            rank: 1,
            puanField: puanField,
            isCurrentUser: _isCurrentUser(topThree[0], currentUserId),
          ),
        ),
      );
    }
    if (topThree.length > 1) {
      podiumItems.add(
        ScaleTransition(
          scale: _podiumAnimations[1],
          child: _buildPodiumUser(
            userData: topThree[1].data() as Map<String, dynamic>,
            rank: 2,
            puanField: puanField,
            isCurrentUser: _isCurrentUser(topThree[1], currentUserId),
          ),
        ),
      );
    }
    if (topThree.length > 2) {
      podiumItems.add(
        ScaleTransition(
          scale: _podiumAnimations[2],
          child: _buildPodiumUser(
            userData: topThree[2].data() as Map<String, dynamic>,
            rank: 3,
            puanField: puanField,
            isCurrentUser: _isCurrentUser(topThree[2], currentUserId),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (podiumItems.length > 1)
            Flexible(child: podiumItems[1])
          else
            const Spacer(),
          const SizedBox(width: 8),
          if (podiumItems.isNotEmpty)
            Flexible(child: podiumItems[0])
          else
            const Spacer(),
          const SizedBox(width: 8),
          if (podiumItems.length > 2)
            Flexible(child: podiumItems[2])
          else
            const Spacer(),
        ],
      ),
    );
  }

  // --- GÜNCELLENDİ: Podyum Kullanıcısı Widget'ı (KPSS Puanı 2 ondalık) ---
  Widget _buildPodiumUser({
    required Map<String, dynamic> userData,
    required int rank,
    required String puanField,
    required bool isCurrentUser,
  }) {
    final puan = (userData[puanField] as num? ?? 0).toInt();
    // KPSS Puanını çek
    final double kpssPuan = (userData['kpssPuan'] as num? ?? 0.0).toDouble();
    final kullaniciAdi = userData['kullaniciAdi'] ?? 'İsimsiz';
    final emoji = userData['emoji'] ?? '🙂';
    final bool isPro = userData['isPro'] ?? false;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // KPSS Puanını virgülden sonra 2 basamakla formatla
    final String formattedKpssPuan = kpssPuan.toStringAsFixed(2);

    double heightFactor = rank == 1 ? 1.0 : (rank == 2 ? 0.85 : 0.7);
    Color rankColor;
    IconData rankIcon;
    switch (rank) {
      case 1:
        rankColor = Colors.amber.shade600;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey.shade500;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = Colors.brown.shade400;
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.grey;
        rankIcon = Icons.military_tech;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCurrentUser)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Icon(
              Icons.person_pin_circle_rounded,
              color: colorScheme.primary,
              size: 18,
            ),
          ),

        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPro)
                FaIcon(
                  FontAwesomeIcons.crown,
                  color: Colors.amber.shade700,
                  size: 10,
                ),
              if (isPro) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  kullaniciAdi,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCurrentUser ? colorScheme.primary : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        Container(
          constraints: const BoxConstraints(maxWidth: 110),
          height: 100 * heightFactor,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [rankColor.withOpacity(0.9), rankColor.withOpacity(0.6)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: 24 + (4 * (4 - rank)).toDouble()),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  // K-Puanı formatında gösterim
                  formattedKpssPuan,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 110),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(rankIcon, color: rankColor, size: 16),
              const SizedBox(width: 4),
              Text(
                '$rank.',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Diğer Kullanıcılar Bölümü (Değişiklik yok)
  Widget _buildOtherUsersSection(
    List<QueryDocumentSnapshot> otherUsers,
    String puanField,
    String? currentUserId,
    int currentUserRankInOthers,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
            child: Text(
              'Diğer Sıralamalar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: otherUsers.length,
            itemBuilder: (context, index) {
              final userData = otherUsers[index].data() as Map<String, dynamic>;
              final rank = 4 + index;
              final isCurrentUser = _isCurrentUser(
                otherUsers[index],
                currentUserId,
              );
              return _buildUserListItem(
                userData: userData,
                rank: rank,
                puanField: puanField,
                isCurrentUser: isCurrentUser,
              );
            },
          ),
        ],
      ),
    );
  }

  // --- GÜNCELLENDİ: Liste Elemanı Widget'ı (KPSS Puanı 2 ondalık) ---
  Widget _buildUserListItem({
    required Map<String, dynamic> userData,
    required int rank,
    required String puanField,
    required bool isCurrentUser,
  }) {
    // Ham skor
    final int puan = (userData[puanField] as num? ?? 0).toInt();
    // KPSS Puanını çek
    final double kpssPuan = (userData['kpssPuan'] as num? ?? 0.0).toDouble();
    final String kullaniciAdi = userData['kullaniciAdi'] ?? 'İsimsiz';
    final String emoji = userData['emoji'] ?? '🙂';
    final bool isPro = userData['isPro'] ?? false;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // KPSS Puanını virgülden sonra 2 basamakla formatla
    final String formattedKpssPuan = kpssPuan.toStringAsFixed(2);

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
            if (isPro)
              FaIcon(
                FontAwesomeIcons.crown,
                color: Colors.amber.shade700,
                size: 12,
              ),
            if (isPro) const SizedBox(width: 6),
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
          // K-Puanı formatında gösterim
          '$formattedKpssPuan Puan',
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

  // Mevcut Kullanıcı mı? (Değişiklik yok)
  bool _isCurrentUser(DocumentSnapshot userDoc, String? currentUserId) {
    var data = userDoc.data() as Map<String, dynamic>? ?? {};
    var userId = data.containsKey('userId') ? data['userId'] : userDoc.id;
    return userId == currentUserId;
  }

  // Hata Durumu Widget'ı (Değişiklik yok)
  Widget _buildErrorState(VoidCallback onRetry, String message) {
    final colorScheme = Theme.of(context).colorScheme;
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }

  // Boş Durum Widget'ı (Değişiklik yok)
  Widget _buildEmptyState(String message, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Geri Dön'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
