import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_screen.dart';
// import 'package:bilgi_yarismasi/screens/result_screen.dart'; // Artık kullanılmıyor

class QuizListScreen extends StatefulWidget {
  final String kategoriId;
  final String kategoriAd;

  const QuizListScreen({
    super.key,
    required this.kategoriId,
    required this.kategoriAd,
  });

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const int puanPerCorrect = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userId = _authService.currentUser?.uid;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.05),
              colorScheme.background,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Başlık ve Geri Butonu
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.pop(context),
                        color: colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.kategoriAd,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Modern Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        Color.lerp(
                          colorScheme.primary,
                          colorScheme.secondary,
                          0.4,
                        )!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  labelColor: colorScheme.onPrimary,
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.7),
                  tabs: const [
                    Tab(text: 'Konu Testleri'),
                    Tab(text: 'Çözdüklerim'),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        context,
                        Icons.check_circle_outline,
                        'Her Doğru Cevap:',
                        '+$puanPerCorrect Puan',
                      ),
                    ],
                  ),
                ),
              ),

              // TabBarView
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    // 1. Kullanıcının Çözdüğü Testleri Çek
                    child: StreamBuilder<QuerySnapshot>(
                      // Stream'i sadece kullanıcı varsa çalıştır
                      stream: userId == null
                          ? null
                          : _firestore
                                .collection('users')
                                .doc(userId)
                                .collection('solvedQuizzes')
                                .where(
                                  'kategoriId',
                                  isEqualTo: widget.kategoriId,
                                )
                                .snapshots(),
                      builder: (context, solvedSnapshot) {
                        // Eğer kullanıcı yoksa (userId=null) veya veriler bekleniyorsa
                        if (userId == null ||
                            solvedSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          // Eğer solvedSnapshot.data yoksa (ilk yükleme) veya sadece loading ise
                          if (solvedSnapshot.data == null && userId != null) {
                            return _buildLoadingState(colorScheme);
                          }
                          // Kullanıcı giriş yapmamışsa, boş çözülmüş listesiyle devam et
                          if (userId == null) {
                            final solvedIds = <String>{};
                            final Map<String, Map<String, dynamic>>
                            solvedDataMap = {};
                            return _buildTopicsAndQuizzesStream(
                              solvedIds: solvedIds,
                              solvedDataMap: solvedDataMap,
                              colorScheme: colorScheme,
                            );
                          }
                          return _buildLoadingState(
                            colorScheme,
                          ); // Yüklenirken bekle
                        }

                        // Veri geldiyse, ID'leri ve Data Map'i hesapla
                        final solvedIds = solvedSnapshot.data!.docs
                            .map((d) => d.id)
                            .toSet();
                        final Map<String, Map<String, dynamic>> solvedDataMap =
                            {};
                        for (var doc in solvedSnapshot.data!.docs) {
                          solvedDataMap[doc.id] =
                              doc.data() as Map<String, dynamic>;
                        }

                        // Diğer Stream'lere (Topics ve Quizzes) geçiş yap
                        return _buildTopicsAndQuizzesStream(
                          solvedIds: solvedIds,
                          solvedDataMap: solvedDataMap,
                          colorScheme: colorScheme,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.8),
                  colorScheme.primary.withOpacity(0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator.adaptive(
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Testler Yükleniyor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Widget: Konu ve Quiz Stream'lerini yönetir ---
  Widget _buildTopicsAndQuizzesStream({
    required Set<String> solvedIds,
    required Map<String, Map<String, dynamic>> solvedDataMap,
    required ColorScheme colorScheme,
  }) {
    // 2. Konu Başlıklarını çek (topics)
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('topics')
          .where('kategoriId', isEqualTo: widget.kategoriId)
          .orderBy('sira') // İndeks gerekli! (topics'te sira ve kategoriId)
          .snapshots(),
      builder: (context, topicsSnapshot) {
        if (topicsSnapshot.hasError) {
          // Güvenlik kuralı hatası (Permission Denied) burada yakalanır
          return Center(
            child: Text(
              'Konular yüklenirken hata oluştu: ${topicsSnapshot.error}',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
          );
        }
        if (!topicsSnapshot.hasData ||
            topicsSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(colorScheme);
        }
        final topics = topicsSnapshot.data!.docs;

        // 3. Sonra TÜM quizleri çek
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('quizzes')
              .where('kategoriId', isEqualTo: widget.kategoriId)
              .orderBy(
                'baslik',
              ) // İndeks gerekli! (quizzes'de kategoriId ve baslik)
              .snapshots(),
          builder: (context, allQuizzesSnapshot) {
            if (allQuizzesSnapshot.hasError) {
              return Center(
                child: Text(
                  'Testler yüklenirken hata oluştu: ${allQuizzesSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              );
            }
            if (!allQuizzesSnapshot.hasData ||
                allQuizzesSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState(colorScheme);
            }

            final allQuizzes = allQuizzesSnapshot.data!.docs;
            final unsolvedQuizzes = allQuizzes
                .where((q) => !solvedIds.contains(q.id))
                .toList();
            final solvedQuizzes = allQuizzes
                .where((q) => solvedIds.contains(q.id))
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildGroupedQuizListView(
                  allTopics: topics,
                  quizzes: unsolvedQuizzes,
                  isReplay: false,
                  solvedDataMap: {},
                  colorScheme: colorScheme,
                ),
                _buildGroupedQuizListView(
                  allTopics: topics,
                  quizzes: solvedQuizzes,
                  isReplay: true,
                  solvedDataMap: solvedDataMap,
                  colorScheme: colorScheme,
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- BİTTİ ---

  Widget _buildGroupedQuizListView({
    required List<DocumentSnapshot> allTopics,
    required List<DocumentSnapshot> quizzes,
    required bool isReplay,
    required Map<String, Map<String, dynamic>> solvedDataMap,
    required ColorScheme colorScheme,
  }) {
    if (quizzes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(24),
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
                child: Icon(
                  isReplay ? Icons.check_circle_outline : Icons.quiz_outlined,
                  color: colorScheme.primary,
                  size: 70,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isReplay
                    ? 'Bu kategoride henüz çözdüğünüz test yok.'
                    : 'Bu kategorideki tüm testleri çözmüşsünüz!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isReplay
                    ? 'Test çözerek yeni başarılar kazanabilirsiniz.'
                    : 'Diğer kategorileri keşfetmeye ne dersiniz?',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    List<Widget> groupedList = [];

    for (var topic in allTopics) {
      final topicId = topic.id;
      final topicData = topic.data() as Map<String, dynamic>? ?? {};
      final String topicName = topicData['ad'] ?? 'Diğer Başlık';

      List<DocumentSnapshot> topicQuizzes = quizzes.where((quiz) {
        final data = quiz.data() as Map<String, dynamic>? ?? {};
        return data['konuId'] == topicId;
      }).toList();

      topicQuizzes.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>? ?? {};
        final bData = b.data() as Map<String, dynamic>? ?? {};
        final String aTitle = aData['baslik'] ?? '';
        final String bTitle = bData['baslik'] ?? '';
        return aTitle.compareTo(bTitle);
      });

      if (topicQuizzes.isEmpty) continue;

      groupedList.add(
        Padding(
          padding: const EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: 12.0,
          ),
          child: Text(
            topicName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );

      groupedList.addAll(
        topicQuizzes.map((quiz) {
          return _buildQuizCard(
            quiz: quiz,
            isReplay: isReplay,
            solvedDataMap: solvedDataMap,
            colorScheme: colorScheme,
          );
        }).toList(),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16.0),
      children: groupedList,
    );
  }

  Widget _buildQuizCard({
    required DocumentSnapshot quiz,
    required bool isReplay,
    required Map<String, Map<String, dynamic>> solvedDataMap,
    required ColorScheme colorScheme,
  }) {
    var quizData = quiz.data() as Map<String, dynamic>? ?? {};
    var quizId = quiz.id;
    var quizBaslik = quizData['baslik'] ?? 'Başlıksız Test';
    var soruSayisi = (quizData['soruSayisi'] as num?)?.toInt() ?? 0;
    var sureDakika = (quizData['sureDakika'] as num?)?.toInt() ?? 0;
    var isNew = quizData['isNew'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Hero(
        tag: 'quiz_$quizId',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final result = await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      QuizScreen(
                        quizId: quizId,
                        quizBaslik: quizBaslik,
                        soruSayisi: soruSayisi,
                        sureDakika: sureDakika,
                        kategoriId: widget.kategoriId,
                        isReplay: isReplay,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.ease;
                        var tween = Tween(
                          begin: begin,
                          end: end,
                        ).chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                ),
              );
              if (result == true && mounted) {
                setState(() {});
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isReplay
                      ? [
                          colorScheme.primary.withOpacity(0.1),
                          colorScheme.primary.withOpacity(0.05),
                        ]
                      : [
                          colorScheme.surface,
                          colorScheme.surface.withOpacity(0.8),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isReplay
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: isReplay
                            ? LinearGradient(
                                colors: [
                                  colorScheme.primary.withOpacity(0.8),
                                  colorScheme.primary.withOpacity(0.6),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  colorScheme.surfaceVariant,
                                  colorScheme.surfaceVariant.withOpacity(0.8),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isReplay
                                ? colorScheme.primary.withOpacity(0.2)
                                : colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isReplay
                            ? Icons.replay_rounded
                            : Icons.play_circle_fill_rounded,
                        color: isReplay
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  quizBaslik,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isNew && !isReplay) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: const Text('YENİ'),
                                  labelStyle: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                  backgroundColor: Colors.green.shade100
                                      .withOpacity(0.8),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide.none,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildInfoChip(
                                icon: Icons.quiz_outlined,
                                text: '$soruSayisi Soru',
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                icon: Icons.timer_outlined,
                                text: '$sureDakika dk',
                                colorScheme: colorScheme,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: colorScheme.primary.withOpacity(0.7),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Bilgi Çipi
  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
