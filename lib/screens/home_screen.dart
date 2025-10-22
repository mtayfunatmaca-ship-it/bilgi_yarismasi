import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_list_screen.dart';
import 'package:bilgi_yarismasi/screens/trial_exams_list_screen.dart';

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
  late AnimationController
  _shimmerController; // Pulse yerine Shimer controller'ı
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation; // Shimer animasyonu

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;

    // Ana animasyonları başlat
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInCirc),
    );

    // Işık efekti (Shimmer) animasyonu için controller
    _shimmerController = AnimationController(
      // Animasyonun süresi (5 saniye)
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // --- YENİ: Aralıklı animasyon mantığı ---
    // Animasyonun durumunu dinleyen bir listener ekliyoruz.
    _shimmerController.addStatusListener((status) {
      // Eğer animasyon tamamlandıysa...
      if (status == AnimationStatus.completed) {
        // Animasyonu başa sar.
        _shimmerController.reset();
        // 10 saniye bekle.
        Future.delayed(const Duration(seconds: 10), () {
          // 10 saniye sonra ve eğer widget hala ekrandaysa...
          if (mounted) {
            // Animasyonu tekrar oynat.
            _shimmerController.forward();
          }
        });
      }
    });

    _animationController.forward();
    // İlk başlangıç için animasyonu bir kez çalıştır.
    _shimmerController.forward();

    _loadCompletionStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose(); // Yeni controller'ı dispose et
    super.dispose();
  }

  Future<void> _reloadAllData() async {
    // Yenileme animasyonu
    _animationController.reset();
    _animationController.forward();

    await _loadCompletionStatus();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCompletionStatus() async {
    if (!mounted || _currentUserId == null) {
      if (mounted) setState(() => _isCompletionLoading = false);
      return;
    }
    setState(() => _isCompletionLoading = true);

    try {
      final categoriesSnapshot = await _firestore
          .collection('categories')
          .get();
      if (!mounted || categoriesSnapshot.docs.isEmpty) {
        if (mounted) setState(() => _isCompletionLoading = false);
        return;
      }

      Map<String, Map<String, int>> completionData = {};
      final List<Future<void>> futures = [];
      final Map<String, int> totalQuizCounts = {};
      final Map<String, int> solvedQuizCounts = {};

      for (var categoryDoc in categoriesSnapshot.docs) {
        final categoryId = categoryDoc.id;
        futures.add(
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

      final solvedSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('solvedQuizzes')
          .get();

      Map<String, int> solvedCountsByCategory = {};
      for (var solvedDoc in solvedSnapshot.docs) {
        final solvedData = solvedDoc.data();
        final categoryId = solvedData['kategoriId'] as String?;
        if (categoryId != null) {
          solvedCountsByCategory[categoryId] =
              (solvedCountsByCategory[categoryId] ?? 0) + 1;
        }
      }
      categoriesSnapshot.docs.forEach((categoryDoc) {
        final categoryId = categoryDoc.id;
        solvedQuizCounts[categoryId] = solvedCountsByCategory[categoryId] ?? 0;
      });

      await Future.wait(futures);

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
            backgroundColor: Colors.red.shade400,
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
    final String currentUserEmail =
        _authService.currentUser?.email ?? 'Kullanıcı';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF4A6572),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.quiz, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Bilgi Yarışması',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Yenile',
              onPressed: _isCompletionLoading ? null : _reloadAllData,
            ),
          ),
        ],
      ),
      body: _currentUserId == null
          ? _buildErrorUI(
              'Kullanıcı bilgisi bulunamadı. Lütfen tekrar giriş yapın.',
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_currentUserId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                Widget welcomeWidget;
                String welcomeMessage = 'Hoş Geldin!';

                if (userSnapshot.hasError) {
                  welcomeWidget = Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade300,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          welcomeMessage,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(Profil yüklenemedi)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                } else if (userSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  welcomeWidget = Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Yükleniyor...',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                } else if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  var userData =
                      userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  var username = userData['kullaniciAdi'] ?? currentUserEmail;
                  welcomeMessage = 'Hoş Geldin, $username!';
                  final puan = userData['toplamPuan'] ?? 0;

                  welcomeWidget = FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4A6572),
                            const Color(0xFF4A6572).withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A6572).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  welcomeMessage,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bugün ne kadar bilgilisin? Testlere başla ve kendini ölç!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatCard(
                                'Puan',
                                puan.toString(),
                                Icons.star,
                                Colors.amber,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  welcomeWidget = FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4A6572),
                            const Color(0xFF4A6572).withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A6572).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        welcomeMessage,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    welcomeWidget,

                    // --- GÜNCELLENMİŞ DENEME SINAVLARI BUTONU ---
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8,
                        ),
                        child: AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                // Işık efekti için animasyonlu gradient
                                gradient: LinearGradient(
                                  colors: [
                                    const Color.fromARGB(255, 238, 114, 13),
                                    Colors.orange,
                                    Colors.orange.shade200, // Işık rengi
                                    Colors.orange,
                                    Colors.orange.shade800,
                                  ],
                                  stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                                  // Animasyon ile gradient'in başlangıç ve bitiş noktalarını kaydırıyoruz
                                  begin: Alignment(_shimmerAnimation.value, 0),
                                  end: Alignment(
                                    _shimmerAnimation.value + 0.5,
                                    0,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.edit_note, size: 24),
                                label: const Text('DENEME SINAVLARI'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 56),
                                  // Butonun kendi rengini şeffaf yapıyoruz ki gradient görünsün
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: theme.textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TrialExamsListScreen(),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('categories')
                            .orderBy('sira')
                            .snapshots(),
                        builder: (context, catSnapshot) {
                          if (catSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              _isCompletionLoading) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: const Color(0xFF4A6572),
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Kategoriler Yükleniyor...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF4A6572),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          if (catSnapshot.hasError) {
                            return _buildErrorUI(
                              'Kategoriler yüklenirken bir sorun oluştu.',
                              onRetry: _reloadAllData,
                            );
                          }
                          if (!catSnapshot.hasData ||
                              catSnapshot.data!.docs.isEmpty) {
                            return _buildErrorUI(
                              'Görsterilecek kategori bulunamadı.\nVerilerin yüklendiğinden emin olun.',
                              icon: Icons.search_off_rounded,
                            );
                          }

                          var documents = catSnapshot.data!.docs;

                          return RefreshIndicator(
                            color: const Color(0xFF4A6572),
                            onRefresh: _reloadAllData,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                top: 8,
                              ),
                              itemCount: documents.length,
                              itemBuilder: (context, index) {
                                final itemAnimation =
                                    Tween<double>(begin: 0.0, end: 1.0).animate(
                                      CurvedAnimation(
                                        parent: _animationController,
                                        curve: Interval(
                                          0.1 + (0.1 * index),
                                          0.5 + (0.1 * index),
                                          curve: Curves.easeOut,
                                        ),
                                      ),
                                    );

                                var data =
                                    documents[index].data()
                                        as Map<String, dynamic>;
                                var docId = documents[index].id;
                                var kategoriAdi =
                                    data['ad'] ?? 'İsimsiz Kategori';

                                final completionInfo =
                                    _categoryCompletion[docId];
                                final total = completionInfo?['total'] ?? 0;
                                final solved = completionInfo?['solved'] ?? 0;

                                Widget trailingWidget = const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 18,
                                );

                                if (!_isCompletionLoading && total > 0) {
                                  if (solved == total) {
                                    trailingWidget = Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.emoji_events,
                                        color: Colors.green.shade600,
                                        size: 20,
                                      ),
                                    );
                                  } else if (solved > 0) {
                                    final progress = solved / total;
                                    trailingWidget = Container(
                                      width: 50,
                                      height: 50,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF4A6572,
                                        ).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: CircularProgressIndicator(
                                              value: progress,
                                              backgroundColor:
                                                  Colors.grey.shade300,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    const Color(0xFF4A6572),
                                                  ),
                                              strokeWidth: 4,
                                            ),
                                          ),
                                          Text(
                                            '${(progress * 100).toInt()}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF4A6572),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } else if (!_isCompletionLoading &&
                                    total == 0) {
                                  trailingWidget = Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.hourglass_empty,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  );
                                } else if (total == -1) {
                                  trailingWidget = Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange.shade600,
                                      size: 20,
                                    ),
                                  );
                                }

                                return FadeTransition(
                                  opacity: itemAnimation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.3),
                                      end: Offset.zero,
                                    ).animate(itemAnimation),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    QuizListScreen(
                                                      kategoriId: docId,
                                                      kategoriAd: kategoriAdi,
                                                    ),
                                              ),
                                            ).then(
                                              (value) =>
                                                  _loadCompletionStatus(),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getCategoryColor(
                                                      index,
                                                    ).withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    _getCategoryIcon(index),
                                                    color: _getCategoryColor(
                                                      index,
                                                    ),
                                                    size: 28,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        kategoriAdi,
                                                        style: theme
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  const Color(
                                                                    0xFF4A6572,
                                                                  ),
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (total > 0)
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .quiz_outlined,
                                                              size: 14,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              '$total test',
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade600,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  child: trailingWidget,
                                                  key: ValueKey(
                                                    docId +
                                                        solved.toString() +
                                                        total.toString(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(int index) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.amber,
      Colors.green,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  IconData _getCategoryIcon(int index) {
    final icons = [
      Icons.science,
      Icons.history_edu,
      Icons.language,
      Icons.calculate,
      Icons.palette,
      Icons.music_note,
      Icons.sports_soccer,
      Icons.computer,
    ];
    return icons[index % icons.length];
  }

  Widget _buildErrorUI(
    String message, {
    VoidCallback? onRetry,
    IconData icon = Icons.error_outline,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.error, size: 60),
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
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A6572).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF4A6572),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
