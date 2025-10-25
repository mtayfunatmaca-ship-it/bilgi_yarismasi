import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_screen.dart';
import 'package:bilgi_yarismasi/screens/result_screen.dart';

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

  // Puanlama sabitleri
  static const int puanPerCorrect = 5;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- Test Başlatma Diyaloğu KALDIRILDI ---

  // Puanlama Bilgisi için yardımcı widget
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 18),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
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
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [ colorScheme.primary.withOpacity(0.05), colorScheme.background ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Başlık ve Geri Butonu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                    Container(
                       decoration: BoxDecoration(color: colorScheme.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]),
                       child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context), color: colorScheme.primary),
                    ),
                    Expanded(
                      child: Text(widget.kategoriAd, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.primary), textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 48),
                ]),
              ),

              // Modern Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(colors: [colorScheme.primary, Color.lerp(colorScheme.primary, colorScheme.secondary, 0.4)!]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [ BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)) ]
                  ),
                  labelColor: colorScheme.onPrimary,
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.7),
                  tabs: const [ Tab(text: 'Çözmediklerim'), Tab(text: 'Çözdüklerim') ],
                ),
              ),
              
              // --- YENİ: Sabit Puanlama Bilgisi ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                       _buildInfoRow(context, Icons.check_circle_outline, 'Her Doğru Cevap:', '+$puanPerCorrect Puan'),
                      
                    ],
                  ),
                ),
              ),
              // --- YENİ BÖLÜM BİTTİ ---

              // TabBarView
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('quizzes').where('kategoriId', isEqualTo: widget.kategoriId).snapshots(),
                      builder: (context, allSnapshot) {
                        if (allSnapshot.connectionState == ConnectionState.waiting) {
                          return _buildLoadingState(colorScheme);
                        }
                        if (!allSnapshot.hasData) {
                           return _buildLoadingState(colorScheme);
                        }
                        final allQuizzes = allSnapshot.data!.docs;

                        return StreamBuilder<QuerySnapshot>(
                          stream: userId == null ? null : _firestore.collection('users').doc(userId).collection('solvedQuizzes').where('kategoriId', isEqualTo: widget.kategoriId).snapshots(),
                          builder: (context, solvedSnapshot) {
                            if (allSnapshot.connectionState == ConnectionState.waiting || (solvedSnapshot.connectionState == ConnectionState.waiting && userId != null)) {
                              return _buildLoadingState(colorScheme);
                            }
                            final solvedIds = solvedSnapshot.data?.docs.map((d) => d.id).toSet() ?? {};
                            final Map<String, Map<String, dynamic>> solvedDataMap = {};
                            for (var doc in (solvedSnapshot.data?.docs ?? [])) {
                               solvedDataMap[doc.id] = doc.data() as Map<String, dynamic>;
                            }
                            final unsolvedQuizzes = allQuizzes.where((q) => !solvedIds.contains(q.id)).toList();
                            final solvedQuizzes = allQuizzes.where((q) => solvedIds.contains(q.id)).toList();

                            return TabBarView(
                              controller: _tabController,
                              children: [
                                // Çözmediklerim
                                _buildQuizListView(
                                  quizzes: unsolvedQuizzes,
                                  isReplay: false, // <<< Bu ilk çözüm
                                  solvedDataMap: {},
                                  colorScheme: colorScheme,
                                ),
                                // Çözdüklerim
                                _buildQuizListView(
                                  quizzes: solvedQuizzes,
                                  isReplay: true, // <<< Bu TEKRAR çözüm
                                  solvedDataMap: solvedDataMap,
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
    // ... (Tam kod öncekiyle aynı) ...
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [colorScheme.primary.withOpacity(0.8), colorScheme.primary.withOpacity(0.4)], begin: Alignment.topLeft, end: Alignment.bottomRight), shape: BoxShape.circle),
            child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text('Testler Yükleniyor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.primary)),
      ]),
    );
  }

  // --- _buildQuizListView GÜNCELLENDİ ---
  Widget _buildQuizListView({
    required List<DocumentSnapshot> quizzes,
    required bool isReplay, // <<< 'isSolvedTab' yerine 'isReplay'
    required Map<String, Map<String, dynamic>> solvedDataMap,
    required ColorScheme colorScheme,
  }) {
    if (quizzes.isEmpty) {
      // ... (Boş durum UI'ı aynı) ...
       return Center(
        child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 120, height: 120, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [colorScheme.primary.withOpacity(0.2), colorScheme.primary.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight), shape: BoxShape.circle),
              child: Icon(isReplay ? Icons.check_circle_outline : Icons.quiz_outlined, color: colorScheme.primary, size: 70),
            ),
            const SizedBox(height: 24),
            Text(isReplay ? 'Bu kategoride henüz çözdüğünüz test yok.' : 'Bu kategorideki tüm testleri çözmüşsünüz!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurface), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(isReplay ? 'Test çözerek yeni başarılar kazanabilirsiniz.' : 'Diğer kategorileri keşfetmeye ne dersiniz?', style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.7)), textAlign: TextAlign.center),
        ])),
      );
    }

    return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: quizzes.length,
        itemBuilder: (context, index) {
          var quiz = quizzes[index];
          var quizId = quiz.id;
          var quizData = quiz.data() as Map<String, dynamic>;
          var quizBaslik = quizData['baslik'] ?? 'Başlıksız Test';
          var soruSayisi = (quizData['soruSayisi'] as num?)?.toInt() ?? 0;
          var sureDakika = (quizData['sureDakika'] as num?)?.toInt() ?? 0;

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
                  // --- ONTAP GÜNCELLENDİ (Artık dialog yok) ---
                  onTap: () async {
                    // İster "Çözdüklerim" (isReplay: true) olsun,
                    // ister "Çözmediklerim" (isReplay: false) olsun,
                    // Her zaman QuizScreen'i aç.
                    final result = await Navigator.push( // <<< 'result'ı yakala
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            QuizScreen(
                              quizId: quizId,
                              quizBaslik: quizBaslik,
                              soruSayisi: soruSayisi,
                              sureDakika: sureDakika,
                              kategoriId: widget.kategoriId,
                              isReplay: isReplay, // <<< ÖNEMLİ: Tekrar mı oynuyor?
                            ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.ease;
                            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                            return SlideTransition(position: animation.drive(tween), child: child);
                        },
                      ),
                    );
                    
                    // QuizScreen'den (veya ResultScreen'den) 'true' ile dönülürse
                    // (bu genellikle ilk çözümden sonradır)
                    if (result == true && mounted) {
                       setState(() {}); // StreamBuilder'ı yenilemeye zorla
                    }
                  },
                  // --- ONTAP BİTTİ ---
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: isReplay
                            ? [ colorScheme.primary.withOpacity(0.1), colorScheme.primary.withOpacity(0.05) ]
                            : [ colorScheme.surface, colorScheme.surface.withOpacity(0.8) ],
                      ),
                      boxShadow: [ BoxShadow(color: colorScheme.shadow.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)) ],
                      border: Border.all(
                        color: isReplay ? colorScheme.primary.withOpacity(0.2) : colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              gradient: isReplay
                                  ? LinearGradient(colors: [colorScheme.primary.withOpacity(0.8), colorScheme.primary.withOpacity(0.6)])
                                  : LinearGradient(colors: [colorScheme.surfaceVariant, colorScheme.surfaceVariant.withOpacity(0.8)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [ BoxShadow(color: isReplay ? colorScheme.primary.withOpacity(0.2) : colorScheme.shadow.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)) ],
                            ),
                            child: Icon(
                              isReplay ? Icons.replay_rounded : Icons.play_circle_fill_rounded,
                              color: isReplay ? Colors.white : colorScheme.onSurfaceVariant,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quizBaslik,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildInfoChip(icon: Icons.quiz_outlined, text: '$soruSayisi Soru', colorScheme: colorScheme),
                                    const SizedBox(width: 8),
                                    _buildInfoChip(icon: Icons.timer_outlined, text: '$sureDakika dk', colorScheme: colorScheme),
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
        },
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
          ),
      ]),
    );
  }
}