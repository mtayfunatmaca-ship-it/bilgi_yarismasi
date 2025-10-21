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
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;

    // Animasyonları başlat
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
    // Yenileme animasyonu
    _animationController.reset();
    _animationController.forward();

    await _loadCompletionStatus();
    // userStream zaten dinlendiği için state değişikliği onu da tetikler.
    if (mounted) {
      setState(() {}); // Build'i tetiklemek için boş setState
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
                totalQuizCounts[categoryId] = -1; // Hata
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
        setState(() {
          _isCompletionLoading = false;
        });
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
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text(
          'Kategoriler',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
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
              // Kullanıcı adını dinle
              stream: _firestore
                  .collection('users')
                  .doc(_currentUserId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                Widget welcomeWidget;
                String welcomeMessage = 'Hoş Geldin!'; // Başlangıç değeri

                if (userSnapshot.hasError) {
                  print("Kullanıcı adı okuma hatası: ${userSnapshot.error}");
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
                  welcomeMessage = 'Yükleniyor...';
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
                          welcomeMessage,
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
                  welcomeWidget = FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
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
                                Icons.waving_hand,
                                color: colorScheme.onPrimary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  welcomeMessage,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bugün ne öğrenmek istersin?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // hasData false veya !exists
                  welcomeWidget = FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        welcomeMessage,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    welcomeWidget,

                    // Deneme Sınavları Butonu
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.assignment_outlined,
                              size: 20,
                            ),
                            label: const Text('Deneme Sınavlarını Gör'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              foregroundColor: colorScheme.onPrimary,
                              backgroundColor: colorScheme.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
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
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Kategori Listesi
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        // Kategorileri dinle
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
                                    color: colorScheme.primary,
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Kategoriler Yükleniyor...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(
                                        0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          if (catSnapshot.hasError) {
                            print(
                              "Kategori okuma hatası: ${catSnapshot.error}",
                            );
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
                            color: colorScheme.primary,
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
                                // Her kategori kartı için gecikmeli animasyon
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
                                        Icons.check_circle,
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
                                        color: colorScheme.primaryContainer
                                            .withOpacity(0.2),
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
                                                    colorScheme.primary,
                                                  ),
                                              strokeWidth: 4,
                                            ),
                                          ),
                                          Text(
                                            '${(progress * 100).toInt()}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
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
                                  // Hata durumunu belirt
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
                                        color: theme.cardColor,
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
                                            ).then((value) {
                                              // Geri dönüldüğünde tamamlama durumunu yenile
                                              _loadCompletionStatus();
                                            });
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
                                                    color: colorScheme
                                                        .primaryContainer
                                                        .withOpacity(0.3),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.category_outlined,
                                                    color: colorScheme.primary,
                                                    size: 24,
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
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (total > 0)
                                                        Text(
                                                          '$total test',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: colorScheme
                                                                    .onSurface
                                                                    .withOpacity(
                                                                      0.6,
                                                                    ),
                                                              ),
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

  // Hata/Boş Durum Gösterimi Widget'ı
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
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
