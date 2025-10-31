import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

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

  Stream<QuerySnapshot>? _generalStream;
  Stream<QuerySnapshot>? _weeklyStream;
  Stream<QuerySnapshot>? _monthlyStream;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _initializeStreams();

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

    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

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
    _confettiController.dispose();
    super.dispose();
  }

  // === build METODU (GÜNCELLENDİ) ===
  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color bgColor = colorScheme.primary;
    final Color podiumBaseColor = colorScheme.primaryContainer.withOpacity(0.8);
    final Color podiumShadowColor = colorScheme.primary.withOpacity(0.6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Sıralama',
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
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            color: colorScheme.onPrimary,
            backgroundColor: bgColor,
            child: Column(
              children: [
                _buildSegmentControl(context, colorScheme, bgColor),
                Expanded(
                  child: IndexedStack(
                    index: _currentSegment,
                    children: [
                      // 0: Haftalık
                      _buildLeaderboardTab(
                        // HAFTALIK LİDER İLAN KARTI
                        header: _buildWeeklyWinnerCard(colorScheme, textTheme),
                        content: _buildLeaderboardContent(
                          stream: _weeklyStream!,
                          puanField: 'puan',
                          currentUserId: currentUserId,
                          emptyMessage: 'Bu hafta henüz kimse test çözmedi.',
                          bgColor: bgColor,
                          podiumBaseColor: podiumBaseColor,
                          podiumShadowColor: podiumShadowColor,
                        ),
                        timingCard: _buildTimingInfoCard(
                          'Haftalık sıralama sonuçları her Pazartesi 00:00\'da güncellenir.',
                          colorScheme,
                        ),
                      ),
                      // 1: Aylık
                      _buildLeaderboardTab(
                        // AYLIK LİDER İLAN KARTI
                        header: _buildMonthlyWinnerCard(colorScheme, textTheme),
                        content: _buildLeaderboardContent(
                          stream: _monthlyStream!,
                          puanField: 'puan',
                          currentUserId: currentUserId,
                          emptyMessage: 'Bu ay henüz kimse test çözmedi.',
                          bgColor: bgColor,
                          podiumBaseColor: podiumBaseColor,
                          podiumShadowColor: podiumShadowColor,
                        ),
                        timingCard: _buildTimingInfoCard(
                          'Aylık sıralama sonuçları her ayın 2\'sinde 00:00\'da güncellenir.',
                          colorScheme,
                        ),
                      ),
                      // 2: Genel
                      _buildLeaderboardTab(
                        header: null,
                        content: _buildLeaderboardContent(
                          stream: _generalStream!,
                          puanField: 'toplamPuan',
                          currentUserId: currentUserId,
                          emptyMessage: 'Henüz puan alan kimse yok.',
                          bgColor: bgColor,
                          podiumBaseColor: podiumBaseColor,
                          podiumShadowColor: podiumShadowColor,
                        ),
                        timingCard: _buildTimingInfoCard(
                          'Genel sıralama anlık olarak güncellenir.',
                          colorScheme,
                        ),
                      ),
                    ],
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
  // === build METODU SONU ===

  // === YENİ VE YARDIMCI WIDGET'LAR ===

  // Liderlik sekmesini (başlıklı veya başlıksız) oluşturan ana widget
  Widget _buildLeaderboardTab({
    required Widget content,
    Widget? header,
    required Widget timingCard,
  }) {
    return Column(
      children: [
        if (header != null) header,
        timingCard, // <<< YENİ: Bilgilendirme kartı eklendi
        Expanded(child: content),
      ],
    );
  }

  // YENİ WIDGET: Zamanlama Bilgilendirme Kartı
  Widget _buildTimingInfoCard(String message, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Geçen Haftanın Lideri Kartı
  Widget _buildWeeklyWinnerCard(ColorScheme colorScheme, TextTheme textTheme) {
    // Sadece Pazar günleri göster
    bool showWinnerCard = DateTime.now().weekday == DateTime.sunday;

    // YUKARIDAN KALDIRILDI: Bu kartın görünmesini isteyen bir kişi varsa,
    // bunu true yaparak test edebilir. (Şimdilik kodda kalabilir, aktif değildir.)
    // if (!showWinnerCard) { return const SizedBox.shrink(); }

    // GÖSTERİLMEYEN GÜNLERDE YENİ HAFTALIK SIRALAMA GÖRÜNDÜĞÜNDEN EMİN OLALIM
    return const SizedBox.shrink(); // Şimdilik sadece yer tutucu olarak kalsın.
  }

  // Geçen Ayın Lideri Kartı
  Widget _buildMonthlyWinnerCard(ColorScheme colorScheme, TextTheme textTheme) {
    // Sadece Ayın 1'inde göster
    bool showWinnerCard = DateTime.now().day == 1;

    // YUKARIDAN KALDIRILDI: Bu kartın görünmesini isteyen bir kişi varsa,
    // bunu true yaparak test edebilir. (Şimdilik kodda kalabilir, aktif değildir.)
    // if (!showWinnerCard) { return const SizedBox.shrink(); }

    // GÖSTERİLMEYEN GÜNLERDE YENİ AYLIK SIRALAMA GÖRÜNDÜĞÜNDEN EMİN OLALIM
    return const SizedBox.shrink(); // Şimdilik sadece yer tutucu olarak kalsın.
  }

  // ... (Kalan fonksiyonlar aynı) ...

  Widget _buildSegmentControl(
    BuildContext context,
    ColorScheme colorScheme,
    Color bgColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _buildSegmentButton(context, 'Haftalık', 0, colorScheme, bgColor),
            _buildSegmentButton(context, 'Aylık', 1, colorScheme, bgColor),
            _buildSegmentButton(context, 'Genel', 2, colorScheme, bgColor),
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
    Color bgColor,
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
                  ? bgColor
                  : colorScheme.onPrimary.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

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
          String errorMsg = 'Sıralama yüklenemedi. Lütfen tekrar deneyin.';
          if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
            errorMsg =
                'Sıralama için gerekli Firestore Index\'i oluşturulmamış.\nLütfen Debug Console\'daki linke tıklayın.';
          }
          return _buildErrorState(_refreshData, errorMsg, colorScheme);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: _buildEmptyState(
                        emptyMessage,
                        context,
                        colorScheme,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        }

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
                  child: otherUsers.isEmpty && stickyUserDoc == null
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
    final bool isPro = userData['isPro'] ?? false;
    double height = rank == 1 ? 120 : (rank == 2 ? 80 : 60);
    Color rankColor = rank == 1
        ? Colors.amber
        : (rank == 2 ? Colors.grey.shade400 : Colors.brown.shade400);
    final HSLColor hslColor = HSLColor.fromColor(podiumBaseColor);
    final Color lightColor = hslColor
        .withLightness((hslColor.lightness + 0.1).clamp(0.0, 1.0))
        .toColor();
    final Color darkColor = hslColor
        .withLightness((hslColor.lightness - 0.1).clamp(0.0, 1.0))
        .toColor();
    final Color frontFaceColor = hslColor
        .withLightness((hslColor.lightness - 0.2).clamp(0.0, 1.0))
        .toColor();
    final Color numberColor = podiumShadowColor;
    const double podiumFrontFaceHeight = 15.0;

    return ScaleTransition(
      scale: animation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1)
            Icon(Icons.star_rounded, color: rankColor, size: 30)
          else
            const SizedBox(height: 30),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: rank == 1 ? 36 : 30,
                backgroundColor: isCurrentUser
                    ? colorScheme.surface
                    : rankColor,
                child: CircleAvatar(
                  radius: (rank == 1 ? 36 : 30) - 3,
                  backgroundColor: podiumBaseColor,
                  child: Text(emoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
              if (isCurrentUser && rank != 1)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.my_location,
                      color: colorScheme.primary,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPro)
                FaIcon(
                  FontAwesomeIcons.crown,
                  color: Colors.amber.shade600,
                  size: 12,
                ),
              if (isPro) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  kullaniciAdi,
                  style: textTheme.bodyMedium?.copyWith(
                    color: isCurrentUser
                        ? colorScheme.surface
                        : colorScheme.onPrimary,
                    fontWeight: isCurrentUser
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: height + podiumFrontFaceHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [darkColor, frontFaceColor],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
              Container(
                height: height,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [lightColor, podiumBaseColor, darkColor],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: rank == 1 ? 48 : 40,
                      fontWeight: FontWeight.bold,
                      color: numberColor,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                        ),
                        Shadow(
                          color: Colors.white.withOpacity(0.7),
                          offset: const Offset(-1, -1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
    final bool isPro = userData['isPro'] ?? false;
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
            child: Row(
              children: [
                if (isPro)
                  FaIcon(
                    FontAwesomeIcons.crown,
                    color: Colors.amber.shade700,
                    size: 12,
                  ),
                if (isPro) const SizedBox(width: 6),
                Flexible(
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

  bool _isCurrentUser(DocumentSnapshot userDoc, String? currentUserId) {
    var data = userDoc.data() as Map<String, dynamic>? ?? {};
    var userId = data.containsKey('userId') ? data['userId'] : userDoc.id;
    return userId == currentUserId;
  }

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

  Widget _buildEmptyState(
    String message,
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard_outlined,
              color: colorScheme.onBackground.withOpacity(0.5),
              size: 80,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
