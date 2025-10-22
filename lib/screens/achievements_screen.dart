import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<QueryDocumentSnapshot> _allAchievements = [];
  Map<String, dynamic> _earnedAchievements = {};
  bool _isLoading = true;

  // Animasyon controller'ları
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late List<AnimationController> _badgeAnimationControllers;
  late List<Animation<double>> _badgeAnimations;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _loadAchievements();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose();
    for (var controller in _badgeAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    if (!mounted) return;
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _firestore.collection('achievements').get(),
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('earnedAchievements')
            .get(),
      ]);

      if (!mounted) return;

      final allSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final earnedSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

      _allAchievements = allSnapshot.docs;

      Map<String, dynamic> earnedMap = {};
      for (var doc in earnedSnapshot.docs) {
        earnedMap[doc.id] = doc.data();
      }
      _earnedAchievements = earnedMap;

      // Kazanılanları öne getir
      _allAchievements.sort((a, b) {
        final aIsEarned = _earnedAchievements.containsKey(a.id);
        final bIsEarned = _earnedAchievements.containsKey(b.id);
        if (aIsEarned && !bIsEarned) return -1;
        if (!aIsEarned && bIsEarned) return 1;
        return 0;
      });

      // Animasyon controller'larını oluştur
      _badgeAnimationControllers = List.generate(
        _allAchievements.length,
        (index) => AnimationController(
          duration: Duration(milliseconds: 600 + (index * 100)),
          vsync: this,
        ),
      );

      _badgeAnimations = _badgeAnimationControllers
          .map(
            (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: controller, curve: Curves.elasticOut),
            ),
          )
          .toList();

      setState(() => _isLoading = false);

      // Animasyonları başlat
      _animationController.forward();
      _shimmerController.repeat();
      for (var controller in _badgeAnimationControllers) {
        controller.forward();
      }
    } catch (e) {
      print("Başarılar yüklenirken hata: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Başarılar yüklenemedi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    try {
      return DateFormat.yMd('tr_TR').format(timestamp.toDate());
    } catch (e) {
      return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onBackground,
        title: Text(
          'Başarılarım',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh_rounded, size: 22),
            ),
            onPressed: _isLoading ? null : _loadAchievements,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState(colorScheme, textTheme)
          : _allAchievements.isEmpty
          ? _buildEmptyState(colorScheme, textTheme)
          : _buildAchievementsGrid(colorScheme, textTheme),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.2),
                  colorScheme.primary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Başarılar Yükleniyor',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Harika başarılarınız hazırlanıyor...',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withOpacity(0.4),
                    colorScheme.primary.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                color: colorScheme.primary,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Henüz Başarı Bulunmuyor',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Yakında yeni başarılar eklenecek!\nTest çözerek yeni başarılar kazanabilirsin.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.quiz_outlined),
              label: Text('Test Çözmeye Başla'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsGrid(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator.adaptive(
      onRefresh: _loadAchievements,
      color: colorScheme.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // İstatistikler Kartı
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _animationController,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.8),
                        colorScheme.primary.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.onPrimary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.emoji_events_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Başarı İlerlemesi',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_earnedAchievements.length} / ${_allAchievements.length} tamamlandı',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // İlerleme Barı
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeOut,
                              width:
                                  (MediaQuery.of(context).size.width - 88) *
                                  (_earnedAchievements.length /
                                      _allAchievements.length),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'Kazanılan',
                            '${_earnedAchievements.length}',
                            Icons.check_circle_rounded,
                            colorScheme.onPrimaryContainer,
                          ),
                          _buildStatItem(
                            'Toplam',
                            '${_allAchievements.length}',
                            Icons.flag_rounded,
                            colorScheme.onPrimaryContainer,
                          ),
                          _buildStatItem(
                            'Tamamlanma',
                            '${(_earnedAchievements.length / _allAchievements.length * 100).toInt()}%',
                            Icons.percent_rounded,
                            colorScheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Başlık
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Tüm Başarılar',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onBackground,
                ),
              ),
            ),
          ),

          // Rozet Grid'i
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= _allAchievements.length) return null;

                final achievementDoc = _allAchievements[index];
                final achievementId = achievementDoc.id;
                final achievementData =
                    achievementDoc.data() as Map<String, dynamic>? ?? {};

                final bool isEarned = _earnedAchievements.containsKey(
                  achievementId,
                );
                final earnedData = isEarned
                    ? _earnedAchievements[achievementId]
                    : null;
                final String earnedDate = isEarned
                    ? _formatTimestamp(earnedData?['earnedDate'])
                    : '';

                final String emoji = achievementData['emoji'] ?? '🏆';
                final String name = achievementData['name'] ?? 'Başarı';
                final String description =
                    achievementData['description'] ?? 'Açıklama yok';

                if (index < _badgeAnimations.length) {
                  return FadeTransition(
                    opacity: _badgeAnimations[index],
                    child: ScaleTransition(
                      scale: _badgeAnimations[index],
                      child: _buildAchievementBadge(
                        emoji,
                        name,
                        description,
                        isEarned,
                        earnedDate,
                        colorScheme,
                        textTheme,
                      ),
                    ),
                  );
                } else {
                  return _buildAchievementBadge(
                    emoji,
                    name,
                    description,
                    isEarned,
                    earnedDate,
                    colorScheme,
                    textTheme,
                  );
                }
              }, childCount: _allAchievements.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(
    String emoji,
    String name,
    String description,
    bool isEarned,
    String earnedDate,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Tooltip(
      message: isEarned ? '$name\nKazanıldı: $earnedDate' : 'Kilitli: $name',
      child: GestureDetector(
        onTap: () {
          _showAchievementDetails(
            emoji,
            name,
            description,
            isEarned,
            earnedDate,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isEarned
                ? colorScheme.surface
                : colorScheme.surface.withOpacity(0.5),
            boxShadow: [
              if (isEarned)
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              BoxShadow(
                color: colorScheme.onSurface.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isEarned
                            ? LinearGradient(
                                colors: [
                                  colorScheme.primary.withOpacity(0.9),
                                  colorScheme.primary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.grey.shade300,
                                  Colors.grey.shade500,
                                ],
                              ),
                        boxShadow: [
                          if (isEarned)
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            )
                          else
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isEarned)
                            AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withOpacity(
                                          0.4 * _shimmerController.value,
                                        ),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.1, 0.8],
                                    ),
                                  ),
                                );
                              },
                            ),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isEarned
                                  ? colorScheme.primaryContainer
                                  : Colors.grey.shade100.withOpacity(0.8),
                              boxShadow: [
                                if (isEarned)
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: isEarned
                                      ? colorScheme.onPrimaryContainer
                                      : Colors.grey.shade600.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isEarned)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.yellow.shade400,
                                Colors.orange.shade400,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isEarned
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withOpacity(0.4),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementDetails(
    String emoji,
    String name,
    String description,
    bool isEarned,
    String earnedDate,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withOpacity(0.9),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isEarned
                          ? LinearGradient(
                              colors: [
                                colorScheme.primary.withOpacity(0.9),
                                colorScheme.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                Colors.grey.shade300,
                                Colors.grey.shade500,
                              ],
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: (isEarned ? colorScheme.primary : Colors.grey)
                              .withOpacity(0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  if (isEarned)
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(
                                  0.3 * _shimmerController.value,
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0.1, 0.7],
                            ),
                          ),
                        );
                      },
                    ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isEarned
                          ? colorScheme.primaryContainer
                          : Colors.grey.shade100.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                          color: (isEarned ? colorScheme.primary : Colors.grey)
                              .withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: TextStyle(
                          fontSize: 48,
                          color: isEarned
                              ? colorScheme.onPrimaryContainer
                              : Colors.grey.shade600.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                  if (isEarned)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.yellow.shade400,
                              Colors.orange.shade400,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                name,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isEarned
                      ? Colors.green.withOpacity(0.1)
                      : colorScheme.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isEarned
                        ? Colors.green.withOpacity(0.3)
                        : colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEarned
                          ? Icons.emoji_events_rounded
                          : Icons.hourglass_empty_rounded,
                      color: isEarned
                          ? Colors.green
                          : colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEarned ? 'Kazanıldı: $earnedDate' : 'Henüz Kazanılmadı',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isEarned
                            ? Colors.green
                            : colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
