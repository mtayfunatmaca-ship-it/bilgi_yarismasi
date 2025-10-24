import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_screen.dart';

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
              colorScheme.primary.withOpacity(0.1),
              colorScheme.background,
            ],
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      onPressed: () => Navigator.pop(context),
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
                    const SizedBox(width: 48), // Geri butonu için denge
                  ],
                ),
              ),

              // Modern Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.transparent,
                  ),
                  labelColor: const Color.fromARGB(255, 28, 51, 157),
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Çözmediklerim'),
                    Tab(text: 'Çözdüklerim'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // TabBarView
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('quizzes')
                          .where('kategoriId', isEqualTo: widget.kategoriId)
                          .snapshots(),
                      builder: (context, allSnapshot) {
                        if (!allSnapshot.hasData) {
                          return _buildLoadingState(colorScheme);
                        }

                        final allQuizzes = allSnapshot.data!.docs;

                        return StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('users')
                              .doc(userId)
                              .collection('solvedQuizzes')
                              .snapshots(),
                          builder: (context, solvedSnapshot) {
                            if (!solvedSnapshot.hasData) {
                              return _buildLoadingState(colorScheme);
                            }

                            final solvedIds = solvedSnapshot.data!.docs
                                .map((d) => d.id)
                                .toSet();

                            final unsolvedQuizzes = allQuizzes
                                .where((q) => !solvedIds.contains(q.id))
                                .toList();
                            final solvedQuizzes = allQuizzes
                                .where((q) => solvedIds.contains(q.id))
                                .toList();

                            return TabBarView(
                              controller: _tabController,
                              children: [
                                _buildQuizListView(
                                  quizzes: unsolvedQuizzes,
                                  isSolvedTab: false,
                                  userId: userId,
                                  colorScheme: colorScheme,
                                ),
                                _buildQuizListView(
                                  quizzes: solvedQuizzes,
                                  isSolvedTab: true,
                                  userId: userId,
                                  colorScheme: colorScheme,
                                ),
                              ],
                            );
                          },
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  Widget _buildQuizListView({
    required List<DocumentSnapshot> quizzes,
    required bool isSolvedTab,
    required String? userId,
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
                  isSolvedTab
                      ? Icons.check_circle_outline
                      : Icons.quiz_outlined,
                  color: colorScheme.primary,
                  size: 70,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isSolvedTab
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
                isSolvedTab
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

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        setState(() {});
      },
      color: colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: quizzes.length,
        itemBuilder: (context, index) {
          var quiz = quizzes[index];
          var quizId = quiz.id;
          var quizData = quiz.data() as Map<String, dynamic>;
          var quizBaslik = quizData['baslik'] ?? 'Başlıksız Test';
          var soruSayisi = quizData['soruSayisi'] ?? 0;
          var sureDakika = quizData['sureDakika'] ?? 0;

          // Sabit puan gösterme kodları kaldırıldı.

          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 16),
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
                        colors: isSolvedTab
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
                        color: isSolvedTab
                            ? colorScheme.primary.withOpacity(0.2)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Sol İkon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: isSolvedTab
                                  ? LinearGradient(
                                      colors: [
                                        colorScheme.primary.withOpacity(0.8),
                                        colorScheme.primary.withOpacity(0.6),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: [
                                        colorScheme.surfaceVariant,
                                        colorScheme.surfaceVariant.withOpacity(
                                          0.8,
                                        ),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isSolvedTab
                                      ? colorScheme.primary.withOpacity(0.2)
                                      : colorScheme.shadow.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isSolvedTab
                                  ? Icons.check_circle
                                  : Icons.play_circle_outline,
                              color: isSolvedTab
                                  ? Colors.white
                                  : colorScheme.onSurfaceVariant,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Orta İçerik
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quizBaslik,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),

                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: [
                                    _buildInfoChip(
                                      icon: Icons.quiz_outlined,
                                      text: '$soruSayisi Soru',
                                      colorScheme: colorScheme,
                                    ),
                                    _buildInfoChip(
                                      icon: Icons.timer_outlined,
                                      text: '$sureDakika dk',
                                      colorScheme: colorScheme,
                                    ),
                                  ],
                                ),

                                // === YENİ PUANLAMA BİLGİ SATIRI ===
                                // Sadece çözmedikleri testlerde göster
                                if (!isSolvedTab)
                                  _buildScoringInfo(colorScheme),
                              ],
                            ),
                          ),

                          // Sağ Ok
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: colorScheme.primary,
                              size: 16,
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
  }

  // === YENİ FONKSİYON ===
  // Puanlama bilgisini gösteren modern bilgi satırı
  Widget _buildScoringInfo(ColorScheme colorScheme) {
    return Padding(
      // Çiplerle hizalı olması için hafif bir iç boşluk
      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Gereksiz yer kaplamasın
        children: [
          Icon(
            Icons.auto_awesome, // Işıltı/Bonus ikonu
            size: 14,
            color: Colors.amber.shade700, // Vurgu rengi (altın)
          ),
          const SizedBox(width: 6),
          Text(
            "Puanlama: Hız + Doğruluk", // AÇIKLAMA METNİ
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // === _buildInfoChip GÜNCELLENDİ (Esnek haliyle duruyor) ===
  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required ColorScheme colorScheme,
    Color? backgroundColor, // Opsiyonel arka plan rengi
    Color? foregroundColor, // Opsiyonel ön plan (ikon/metin) rengi
  }) {
    // Varsayılan renkleri belirle
    final bgColor =
        backgroundColor ?? colorScheme.surfaceVariant.withOpacity(0.7);
    final fgColor = foregroundColor ?? colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
