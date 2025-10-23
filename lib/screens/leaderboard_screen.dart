import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:intl/intl.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  int _currentSegment = 0; // 0=Haftalık, 1=Aylık, 2=Genel

  late AnimationController _podiumAnimationController;
  late List<Animation<double>> _podiumAnimations;
  late AnimationController _listAnimationController;
  late Animation<Offset> _slideAnimation;

  Stream<QuerySnapshot>? _generalStream;
  Stream<QuerySnapshot>? _weeklyStream;
  Stream<QuerySnapshot>? _monthlyStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();

    // Podyum animasyonu
    _podiumAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _podiumAnimations = [
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _podiumAnimationController,
          curve: const Interval(0.2, 0.8, curve: Curves.elasticOut), // 2. sıra
        ),
      ),
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _podiumAnimationController,
          curve: const Interval(0.4, 1.0, curve: Curves.elasticOut), // 1. sıra
        ),
      ),
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _podiumAnimationController,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut), // 3. sıra
        ),
      ),
    ];

    // Liste animasyonu
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _listAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Animasyonları başlat
    _podiumAnimationController.forward();
    _listAnimationController.forward();

    _logLeaderboardView(_currentSegment);
  }

  // Stream'leri başlat (Aylık dahil)
  void _initializeStreams() {
    _generalStream = _firestore
        .collection('users')
        .orderBy('toplamPuan', descending: true)
        .limit(100)
        .snapshots();
    _weeklyStream = _firestore
        .collection('mevcutHaftalikLiderlik')
        .orderBy('puan', descending: true)
        .limit(100)
        .snapshots();
    _monthlyStream = _firestore
        .collection('mevcutAylikLiderlik')
        .orderBy('puan', descending: true)
        .limit(100)
        .snapshots();
  }

  // Analytics
  void _logLeaderboardView(int segmentIndex) {
    String segmentName;
    switch (segmentIndex) {
      case 0:
        segmentName = 'haftalik';
        break;
      case 1:
        segmentName = 'aylik';
        break;
      case 2:
        segmentName = 'genel';
        break;
      default:
        segmentName = 'bilinmeyen';
    }
    FirebaseAnalytics.instance.logEvent(
      name: 'view_leaderboard',
      parameters: {'segment': segmentName},
    );
  }

  // Yenileme (Animasyonları sıfırlar)
  Future<void> _refreshData() async {
    _podiumAnimationController.reset();
    _listAnimationController.reset();
    setState(() {
      _initializeStreams();
    });
    _podiumAnimationController.forward();
    _listAnimationController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _podiumAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  // === build METODU (Tam Kod) ===
  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Tema renklerini kullanarak dinamik renkler oluştur
    final Color bgColor = colorScheme.primary;
    final Color podiumBaseColor = colorScheme.primaryContainer;
    final Color podiumShadowColor = colorScheme.primary.withOpacity(0.8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Leaderboard',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        backgroundColor: bgColor,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: colorScheme.onPrimary,
        backgroundColor: bgColor,
        child: Column(
          children: [
            _buildSegmentControl(context, colorScheme),
            Expanded(
              child: IndexedStack(
                index: _currentSegment,
                children: [
                  // 0: Haftalık
                  _buildLeaderboardContent(
                    stream: _weeklyStream!,
                    puanField: 'puan',
                    currentUserId: currentUserId,
                    emptyMessage: 'Bu hafta henüz kimse test çözmedi.',
                    bgColor: bgColor,
                    podiumBaseColor: podiumBaseColor,
                    podiumShadowColor: podiumShadowColor,
                  ),
                  // 1: Aylık
                  _buildLeaderboardContent(
                    stream: _monthlyStream!,
                    puanField: 'puan',
                    currentUserId: currentUserId,
                    emptyMessage: 'Bu ay henüz kimse test çözmedi.',
                    bgColor: bgColor,
                    podiumBaseColor: podiumBaseColor,
                    podiumShadowColor: podiumShadowColor,
                  ),
                  // 2: Genel
                  _buildLeaderboardContent(
                    stream: _generalStream!,
                    puanField: 'toplamPuan',
                    currentUserId: currentUserId,
                    emptyMessage: 'Henüz puan alan kimse yok.',
                    bgColor: bgColor,
                    podiumBaseColor: podiumBaseColor,
                    podiumShadowColor: podiumShadowColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // === build METODU SONU ===

  // === YARDIMCI WIDGET'LAR ===

  // Segment Butonu (3 sekmeli)
  Widget _buildSegmentControl(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _buildSegmentButton(context, 'Haftalık', 0, colorScheme),
            _buildSegmentButton(context, 'Aylık', 1, colorScheme),
            _buildSegmentButton(context, 'Genel', 2, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(
    BuildContext context,
    String text,
    int index,
    ColorScheme colorScheme,
  ) {
    final bool isSelected = _currentSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentSegment != index) {
            setState(() {
              _currentSegment = index;
              _logLeaderboardView(index);
              _podiumAnimationController.reset();
              _listAnimationController.reset();
              _podiumAnimationController.forward();
              _listAnimationController.forward();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onPrimary.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  // --- Liderlik İçeriği Oluşturucu (HATA DÜZELTİLDİ) ---
  Widget _buildLeaderboardContent({
    required Stream<QuerySnapshot> stream,
    required String puanField,
    required String? currentUserId,
    required String emptyMessage,
    required Color bgColor,
    required Color podiumBaseColor,
    required Color podiumShadowColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError) {
          print('Leaderboard Stream Error: ${snapshot.error}');
          String errorMsg = 'Sıralama yüklenemedi. Lütfen tekrar deneyin.';
          if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
            errorMsg =
                'Sıralama için gerekli Firestore Index\'i oluşturulmamış.\nLütfen Debug Console\'daki linke tıklayın.';
          }
          return _buildErrorState(_refreshData, errorMsg, colorScheme);
        }

        // --- HATA DÜZELTMESİ: Animasyon başlatma kodları buradan kaldırıldı ---
        // if (_podiumAnimationController.status == AnimationStatus.completed) { ... }
        // if (_listAnimationController.status == AnimationStatus.completed) { ... }
        // --- DÜZELTME BİTTİ ---

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Boş durum
          return Stack(
            children: [
              _buildPodiumSection(
                [],
                puanField,
                currentUserId,
                colorScheme,
                textTheme,
                podiumBaseColor,
                podiumShadowColor,
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.45,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: colorScheme.background,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: _buildEmptyState(emptyMessage, context, colorScheme),
                  );
                },
              ),
            ],
          );
        }

        // Veri varsa
        var userDocs = snapshot.data!.docs;
        final topThree = userDocs.take(3).toList();

        final bool isUserInTopThree = topThree.any(
          (doc) => _isCurrentUser(doc, currentUserId),
        );

        DocumentSnapshot? stickyUserDoc;
        int stickyUserRank = -1;
        List<QueryDocumentSnapshot> otherUsers = userDocs.skip(3).toList();

        if (!isUserInTopThree) {
          final currentUserIndex = userDocs.indexWhere(
            (u) => _isCurrentUser(u, currentUserId),
          );
          if (currentUserIndex >= 3) {
            stickyUserDoc = userDocs[currentUserIndex];
            stickyUserRank = currentUserIndex + 1;
            otherUsers.removeWhere((doc) => _isCurrentUser(doc, currentUserId));
          }
        }

        return Stack(
          children: [
            _buildPodiumSection(
              topThree,
              puanField,
              currentUserId,
              colorScheme,
              textTheme,
              podiumBaseColor,
              podiumShadowColor,
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.45,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child:
                      otherUsers.isEmpty &&
                          stickyUserDoc ==
                              null // Liste de boşsa, sabit kullanıcı da yoksa
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              "Listede başka kullanıcı yok.",
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : _buildOtherUsersSection(
                          otherUsers,
                          stickyUserDoc,
                          stickyUserRank,
                          puanField,
                          currentUserId,
                          scrollController,
                          colorScheme,
                          textTheme,
                          userDocs,
                        ),
                );
              },
            ),
          ],
        );
      },
    );
  }
  // --- HATA DÜZELTMESİ BİTTİ ---

  // Podyum Bölümü
  Widget _buildPodiumSection(
    List<QueryDocumentSnapshot> topThree,
    String puanField,
    String? currentUserId,
    ColorScheme colorScheme,
    TextTheme textTheme,
    Color podiumBaseColor,
    Color podiumShadowColor,
  ) {
    Widget user1 = (topThree.isNotEmpty)
        ? _buildPodiumUser(
            topThree[0],
            1,
            puanField,
            currentUserId,
            _podiumAnimations[1],
            colorScheme,
            textTheme,
            podiumBaseColor,
            podiumShadowColor,
          )
        : const SizedBox();
    Widget user2 = (topThree.length > 1)
        ? _buildPodiumUser(
            topThree[1],
            2,
            puanField,
            currentUserId,
            _podiumAnimations[0],
            colorScheme,
            textTheme,
            podiumBaseColor,
            podiumShadowColor,
          )
        : const SizedBox();
    Widget user3 = (topThree.length > 2)
        ? _buildPodiumUser(
            topThree[2],
            3,
            puanField,
            currentUserId,
            _podiumAnimations[2],
            colorScheme,
            textTheme,
            podiumBaseColor,
            podiumShadowColor,
          )
        : const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(flex: 3, child: user2),
          Flexible(flex: 4, child: user1),
          Flexible(flex: 3, child: user3),
        ],
      ),
    );
  }

  // Podyum Kullanıcısı Widget'ı (Puanlı)
  Widget _buildPodiumUser(
    DocumentSnapshot userDoc,
    int rank,
    String puanField,
    String? currentUserId,
    Animation<double> animation,
    ColorScheme colorScheme,
    TextTheme textTheme,
    Color podiumBaseColor,
    Color podiumShadowColor,
  ) {
    final userData = userDoc.data() as Map<String, dynamic>;
    final puan = (userData[puanField] as num? ?? 0).toInt();
    final kullaniciAdi = userData['kullaniciAdi'] ?? 'İsimsiz';
    final emoji = userData['emoji'] ?? '🙂';
    final isCurrentUser = _isCurrentUser(userDoc, currentUserId);

    double height = rank == 1 ? 120 : (rank == 2 ? 80 : 60);
    Color rankColor = rank == 1
        ? Colors.amber
        : (rank == 2 ? Colors.grey.shade400 : Colors.brown.shade400);

    return ScaleTransition(
      scale: animation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1)
            Icon(Icons.star_rounded, color: rankColor, size: 30)
          else
            const SizedBox(height: 30),

          CircleAvatar(
            radius: rank == 1 ? 36 : 30,
            backgroundColor: isCurrentUser ? colorScheme.surface : rankColor,
            child: CircleAvatar(
              radius: (rank == 1 ? 36 : 30) - 3,
              backgroundColor: podiumBaseColor,
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            kullaniciAdi,
            style: textTheme.bodyMedium?.copyWith(
              color: isCurrentUser
                  ? colorScheme.surface
                  : colorScheme.onPrimary,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat.compact().format(puan)} Puan',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimary.withOpacity(0.9),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: rankColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${rank}${rank == 1 ? 'ST' : (rank == 2 ? 'ND' : 'RD')} TOP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: rank == 1 ? podiumShadowColor : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: podiumBaseColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: podiumShadowColor, width: 2),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: rank == 1 ? 48 : 40,
                  fontWeight: FontWeight.bold,
                  color: podiumShadowColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Diğer Kullanıcılar Listesi (Kullanıcıyı Sabitlemeli)
  Widget _buildOtherUsersSection(
    List<QueryDocumentSnapshot> otherUsers,
    DocumentSnapshot? stickyUserDoc,
    int stickyUserRank,
    String puanField,
    String? currentUserId,
    ScrollController scrollController,
    ColorScheme colorScheme,
    TextTheme textTheme,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 40),
      itemCount: otherUsers.length + 1 + (stickyUserDoc != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              "Diğer Katılımcılar",
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        if (stickyUserDoc != null && index == 1) {
          final userData = stickyUserDoc.data() as Map<String, dynamic>;
          return _buildUserListItem(
            userData: userData,
            rank: stickyUserRank,
            puanField: puanField,
            isCurrentUser: true,
            colorScheme: colorScheme,
            textTheme: textTheme,
          );
        }

        final userIndex = index - 1 - (stickyUserDoc != null ? 1 : 0);
        if (userIndex < 0 || userIndex >= otherUsers.length)
          return const SizedBox.shrink();

        final userDoc = otherUsers[userIndex];
        final userData = userDoc.data() as Map<String, dynamic>;

        final originalIndex = allDocs.indexWhere((doc) => doc.id == userDoc.id);
        final rank = originalIndex + 1;

        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _listAnimationController,
                  curve: Interval(
                    (0.1 * userIndex).clamp(0.0, 1.0),
                    1.0,
                    curve: Curves.easeOut,
                  ),
                ),
              ),
          child: _buildUserListItem(
            userData: userData,
            rank: rank,
            puanField: puanField,
            isCurrentUser: false,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        );
      },
    );
  }

  // Liste Elemanı Widget'ı
  Widget _buildUserListItem({
    required Map<String, dynamic> userData,
    required int rank,
    required String puanField,
    required bool isCurrentUser,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final puan = (userData[puanField] as num? ?? 0).toInt();
    final kullaniciAdi = userData['kullaniciAdi'] ?? 'İsimsiz';
    final emoji = userData['emoji'] ?? '🙂';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Text(
            '$rank.',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isCurrentUser
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.surface,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              kullaniciAdi,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            NumberFormat.compact(locale: "tr_TR").format(puan),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // Mevcut Kullanıcı mı?
  bool _isCurrentUser(DocumentSnapshot userDoc, String? currentUserId) {
    var data = userDoc.data() as Map<String, dynamic>? ?? {};
    var userId = data.containsKey('userId') ? data['userId'] : userDoc.id;
    return userId == currentUserId;
  }

  // Hata Durumu Widget'ı
  Widget _buildErrorState(
    VoidCallback onRetry,
    String message,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade300,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'Bir hata oluştu',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Boş Durum Widget'ı
  Widget _buildEmptyState(
    String message,
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard_outlined,
              color: colorScheme.onPrimary.withOpacity(0.5),
              size: 80,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
