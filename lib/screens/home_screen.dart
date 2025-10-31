import 'package:bilgi_yarismasi/screens/purchase_screen.dart';
import 'package:bilgi_yarismasi/screens/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_list_screen.dart';
import 'package:bilgi_yarismasi/screens/trial_exams_list_screen.dart';
import 'package:bilgi_yarismasi/screens/profile_screen.dart';
import 'package:bilgi_yarismasi/screens/leaderboard_screen.dart';
import 'package:bilgi_yarismasi/screens/achievements_screen.dart';
import 'package:bilgi_yarismasi/screens/solved_quizzes_screen.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:bilgi_yarismasi/services/user_data_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, int>> _categoryCompletion = {};
  bool _isCompletionLoading = true;
  String? _currentUserId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
    _loadCompletionStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _reloadAllData() async {
    _animationController.reset();
    _animationController.forward();
    await _loadCompletionStatus();
  }

  // --- YENİ FONKSİYON: Saate göre karşılama metni ---
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) {
      return 'İyi geceler'; // 00:00 - 04:59
    } else if (hour < 12) {
      return 'Günaydın'; // 05:00 - 11:59
    } else if (hour < 18) {
      return 'İyi günler'; // 12:00 - 17:59
    } else {
      return 'İyi akşamlar'; // 18:00 - 23:59
    }
  }
  // --- BİTTİ ---

  void _showProFeatureDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            Icons.lock_person_rounded,
            color: colorScheme.primary,
            size: 48,
          ),
          title: const Text(
            'PRO Özellik',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Detaylı istatistikler ve daha fazlası için PRO üyeliğe geçiş yapmanız gerekmektedir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dialog'u kapat
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PurchaseScreen(),
                  ),
                );
              },
              child: const Text('PRO\'ya Geç'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadCompletionStatus() async {
    if (!mounted || _currentUserId == null) {
      if (mounted) setState(() => _isCompletionLoading = false);
      return;
    }
    setState(() => _isCompletionLoading = true);
    try {
      final categoriesSnapshotFuture = _firestore
          .collection('categories')
          .get();
      final solvedSnapshotFuture = _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('solvedQuizzes')
          .get();
      final results = await Future.wait([
        categoriesSnapshotFuture,
        solvedSnapshotFuture,
      ]);
      if (!mounted) return;
      final categoriesSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final solvedSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      if (categoriesSnapshot.docs.isEmpty) {
        if (mounted) setState(() => _isCompletionLoading = false);
        return;
      }
      Map<String, Map<String, int>> completionData = {};
      final List<Future<void>> quizCountFutures = [];
      final Map<String, int> totalQuizCounts = {};
      final Map<String, int> solvedQuizCounts = {};
      Map<String, int> solvedCountsByCategory = {};
      for (var solvedDoc in solvedSnapshot.docs) {
        final solvedData = solvedDoc.data();
        final categoryId = solvedData['kategoriId'] as String?;
        if (categoryId != null) {
          solvedCountsByCategory[categoryId] =
              (solvedCountsByCategory[categoryId] ?? 0) + 1;
        }
      }
      for (var categoryDoc in categoriesSnapshot.docs) {
        final categoryId = categoryDoc.id;
        solvedQuizCounts[categoryId] = solvedCountsByCategory[categoryId] ?? 0;
        quizCountFutures.add(
          _firestore
              .collection('quizzes')
              .where('kategoriId', isEqualTo: categoryId)
              .count()
              .get()
              .then(
                (aggregate) =>
                    totalQuizCounts[categoryId] = aggregate.count ?? 0,
              )
              .catchError((e) {
                print("Toplam test sayısı alınırken hata ($categoryId): $e");
                totalQuizCounts[categoryId] = -1;
              }),
        );
      }
      await Future.wait(quizCountFutures);
      if (!mounted) return;
      categoriesSnapshot.docs.forEach((categoryDoc) {
        final categoryId = categoryDoc.id;
        completionData[categoryId] = {
          'total': totalQuizCounts[categoryId] ?? 0,
          'solved': solvedQuizCounts[categoryId] ?? 0,
        };
      });
      setState(() {
        _categoryCompletion = completionData;
        _isCompletionLoading = false;
      });
    } catch (e) {
      print("Kategori tamamlama durumu yüklenirken genel hata: $e");
      if (mounted) {
        setState(() => _isCompletionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kategori ilerlemesi yüklenemedi: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final String currentUserEmail =
        _authService.currentUser?.email ?? 'Kullanıcı';

    final bool isPro = context.watch<UserDataProvider>().isPro;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(elevation: 0, backgroundColor: colorScheme.background),
      ),
      body: _currentUserId == null
          ? _buildErrorUI(
              'Kullanıcı bilgisi bulunamadı. Lütfen tekrar giriş yapın.',
              theme,
            )
          : RefreshIndicator(
              onRefresh: _reloadAllData,
              color: colorScheme.primary,
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('users')
                    .doc(_currentUserId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  String displayName = 'Kullanıcı';
                  String emoji = '🙂';
                  int puan = 0;
                  Widget? headerStatusWidget;

                  if (userSnapshot.hasError) {
                    print("Kullanıcı adı okuma hatası: ${userSnapshot.error}");
                    headerStatusWidget = _buildSimpleHeader(
                      'Profil Yüklenemedi',
                      theme,
                      colorScheme,
                      hasError: true,
                    );
                  } else if (userSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !userSnapshot.hasData) {
                    headerStatusWidget = _buildSimpleHeader(
                      'Yükleniyor...',
                      theme,
                      colorScheme,
                      showProgress: true,
                    );
                  } else if (userSnapshot.hasData &&
                      userSnapshot.data!.exists) {
                    var userData =
                        userSnapshot.data!.data() as Map<String, dynamic>? ??
                        {};
                    displayName =
                        userData['ad'] ??
                        userData['kullaniciAdi'] ??
                        currentUserEmail;
                    emoji = userData['emoji'] ?? '🙂';
                    puan = (userData['toplamPuan'] as num?)?.toInt() ?? 0;
                  }

                  return ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      _buildProfileHeader(
                        displayName,
                        emoji,
                        puan,
                        theme,
                        colorScheme,
                      ),
                      _buildQuickActions(
                        context,
                        colorScheme,
                        textTheme,
                        isPro,
                      ),
                      _buildTrialExamBanner(context, colorScheme, textTheme),
                      if (!isPro)
                        _buildGoProBanner(context, colorScheme, textTheme),
                      _buildCategoriesHeader(context, colorScheme, textTheme),
                      _buildCategoriesGrid(theme, colorScheme),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
    );
  }

  // --- GÜNCELLENDİ: Header (Saate göre karşılama) ---
  Widget _buildProfileHeader(
    String displayName,
    String emoji,
    int puan,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Saate göre karşılama metnini al
    final String greeting = _getGreeting();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surface,
                  border: Border.all(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting, // <<< "İyi günler!" DEĞİŞTİRİLDİ
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: Colors.amber.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    NumberFormat.compact().format(puan),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- BİTTİ ---

  Widget _buildQuickActions(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isPro,
  ) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    return FadeTransition(
      opacity: _animationController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            _buildQuickActionButton(
              context: context,
              color: const Color(0xFF6A5AE0), // Mor
              icon: FontAwesomeIcons.trophy,
              label: 'Sıralama',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen(),
                  ),
                );
              },
              isLocked: false,
            ),
            const SizedBox(width: 12),
            _buildQuickActionButton(
              context: context,
              color: const Color(0xFF33CC99), // Yeşil
              icon: FontAwesomeIcons.shieldHalved,
              label: 'Başarılar',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AchievementsScreen(),
                  ),
                );
              },
              isLocked: false,
            ),
            const SizedBox(width: 12),
            _buildQuickActionButton(
              context: context,
              color: isPro ? const Color(0xFF2F80ED) : Colors.grey.shade500,
              icon: isPro ? FontAwesomeIcons.chartSimple : Icons.lock,
              label: 'İstatistik',
              onTap: () {
                if (isPro) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StatisticsScreen()),
                  );
                } else {
                  _showProFeatureDialog(context);
                }
              },
              isLocked: !isPro,
            ),
            const SizedBox(width: 12),
            _buildQuickActionButton(
              context: context,
              color: const Color(0xFFF27A54), // Turuncu
              icon: FontAwesomeIcons.clockRotateLeft,
              label: 'Geçmiş',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SolvedQuizzesScreen(),
                  ),
                );
              },
              isLocked: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isLocked,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(-2, -2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.2)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  FaIcon(icon, color: Colors.white, size: 24),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrialExamBanner(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.secondary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                colorScheme.secondary,
                Color.lerp(colorScheme.secondary, Colors.black, 0.3)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deneme Sınavları',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Çöz, yüksek puan al, rekabet et!',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondary.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TrialExamsListScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.onSecondary,
                        foregroundColor: colorScheme.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        shadowColor: Colors.black.withOpacity(0.2),
                      ),
                      child: const Text('Hemen Katıl'),
                    ),
                  ],
                ),
              ),
              FaIcon(
                FontAwesomeIcons.stopwatch,
                color: colorScheme.onSecondary.withOpacity(0.2),
                size: 80,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoProBanner(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Yönlendirme zaten doğru
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PurchaseScreen()),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amber.shade300,
                    size: 48,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRO\'ya Geçiş Yap',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reklamları kaldır ve tüm özelliklere eriş!',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Kategorileri Keşfet',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(ThemeData theme, ColorScheme colorScheme) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('categories').orderBy('sira').snapshots(),
      builder: (context, catSnapshot) {
        if (catSnapshot.connectionState == ConnectionState.waiting ||
            _isCompletionLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (catSnapshot.hasError) {
          print("Kategori okuma hatası: ${catSnapshot.error}");
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildErrorUI(
              'Kategoriler yüklenirken bir sorun oluştu.',
              theme,
              onRetry: _reloadAllData,
            ),
          );
        }
        if (!catSnapshot.hasData || catSnapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildErrorUI(
              'Görsterilecek kategori bulunamadı...',
              theme,
              iconWidget: FaIcon(
                FontAwesomeIcons.frownOpen,
                color: colorScheme.secondary,
                size: 60,
              ),
            ),
          );
        }

        var documents = catSnapshot.data!.docs;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
            top: 0,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final itemAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  (0.3 + (0.1 * index)).clamp(0.0, 1.0),
                  (0.9 + (0.1 * index)).clamp(0.0, 1.0),
                  curve: Curves.easeOut,
                ),
              ),
            );

            var data = documents[index].data() as Map<String, dynamic>;
            var docId = documents[index].id;
            var kategoriAdi = data['ad'] ?? 'İsimsiz Kategori';
            var kategoriIcon = _getCategoryIcon(docId);
            var kategoriColor = _getCategoryColor(docId, colorScheme);

            final completionInfo = _categoryCompletion[docId];
            final total = completionInfo?['total'] ?? 0;
            final solved = completionInfo?['solved'] ?? 0;
            final progress = total > 0 ? solved / total : 0.0;

            return FadeTransition(
              opacity: itemAnimation,
              child: _buildCategoryCard(
                docId,
                kategoriAdi,
                kategoriIcon,
                kategoriColor,
                progress,
                solved,
                total,
                theme,
                colorScheme,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    String docId,
    String kategoriAdi,
    IconData kategoriIcon,
    List<Color> kategoriColor,
    double progress,
    int solved,
    int total,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: kategoriColor.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(-2, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: kategoriColor,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizListScreen(
                        kategoriId: docId,
                        kategoriAd: kategoriAdi,
                      ),
                    ),
                  ).then((_) => _loadCompletionStatus());
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -10,
                        right: -10,
                        child: FaIcon(
                          kategoriIcon,
                          color: Colors.white.withOpacity(0.2),
                          size: 80,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            kategoriAdi,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                total > 0
                                    ? '$total Test'
                                    : (total == 0 ? 'Test Yok' : 'Hata'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (total > 0 && !_isCompletionLoading)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    backgroundColor: Colors.white.withOpacity(
                                      0.3,
                                    ),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    minHeight: 6,
                                  ),
                                )
                              else if (_isCompletionLoading)
                                Container(
                                  height: 6,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                )
                              else
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 6,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    String message,
    ThemeData theme, {
    VoidCallback? onRetry,
    IconData? icon,
    Widget? iconWidget,
  }) {
    final colorScheme = theme.colorScheme;
    final Widget finalIconWidget =
        iconWidget ??
        Icon(
          icon ?? Icons.error_outline_rounded,
          color: icon == Icons.error_outline_rounded
              ? colorScheme.error
              : colorScheme.secondary,
          size: 60,
        );
    final Color iconBgColor =
        (icon == Icons.error_outline_rounded || icon == null)
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: finalIconWidget,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: colorScheme.onPrimary,
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleHeader(
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    String message,
    ThemeData theme,
    ColorScheme colorScheme, {
    bool showProgress = false,
    bool hasError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showProgress)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              hasError ? Icons.warning_amber_rounded : Icons.info_outline,
              size: 18,
              color: hasError
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          const SizedBox(width: 8),
          Text(message, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  List<Color> _getCategoryColor(String categoryId, ColorScheme colorScheme) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    switch (categoryId) {
      case 'turkce':
        return [const Color(0xFF9775FA), const Color(0xFF6741D9)];
      case 'matematik':
        return [const Color(0xFF4DABF7), const Color(0xFF1864AB)];
      case 'tarih':
        return [const Color(0xFFFF6B6B), const Color(0xFFC92A2A)];
      case 'cografya':
        return [const Color(0xFF51CF66), const Color(0xFF2B8A3E)];
      case 'vatandaslik':
        return [const Color(0xFFFF922B), const Color(0xFFE8590C)];
      default:
        return [colorScheme.secondary, colorScheme.secondary.withOpacity(0.7)];
    }
  }

  IconData _getCategoryIcon(String categoryId) {
    // ... (Bu fonksiyon aynı, değişiklik yok) ...
    switch (categoryId) {
      case 'turkce':
        return FontAwesomeIcons.penNib;
      case 'matematik':
        return FontAwesomeIcons.calculator;
      case 'tarih':
        return FontAwesomeIcons.bookOpen;
      case 'cografya':
        return FontAwesomeIcons.globeAmericas;
      case 'vatandaslik':
        return FontAwesomeIcons.scaleBalanced;
      default:
        return FontAwesomeIcons.question;
    }
  }
}
