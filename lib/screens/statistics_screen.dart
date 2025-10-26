import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:intl/intl.dart';
// import 'dart:math' as math; // (Artık gerekmiyor)

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String? _error;

  // Animasyon controller'ları
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;
  List<AnimationController> _cardAnimationControllers = [];

  // Hesaplanan İstatistikler
  int _totalSolvedQuizzes = 0;
  int _totalTrialExams = 0;
  int _totalScoreFromQuizzes = 0;
  int _totalScoreFromTrials = 0;
  int _overallTotalScore = 0;
  double _overallAccuracy = 0.0;
  double _averageQuizTimeSeconds = 0.0;
  Map<String, Map<String, dynamic>> _categoryStats = {};
  double _averageTrialScore = 0.0;
  double _trialAccuracy = 0.0;
  double _averageTrialKpssPuan = 0.0;
  double _averageTrialNet = 0.0;


  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _cardAnimationControllers = []; // Boş başlat

    _loadStatistics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressAnimationController.dispose();
    for (var controller in _cardAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Verileri çekip istatistikleri hesaplar
  Future<void> _loadStatistics() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = _authService.currentUser;
    if (user == null) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = "İstatistikleri görmek için giriş yapmalısınız.";
        });
      return;
    }

    try {
      final futures = await Future.wait([
        _firestore.collection('users').doc(user.uid).get(),
        _firestore.collection('users').doc(user.uid).collection('solvedQuizzes').get(),
        _firestore.collection('users').doc(user.uid).collection('trialExamResults').get(),
        _firestore.collection('categories').get(),
      ]);

      if (!mounted) return;

      final userDoc = futures[0] as DocumentSnapshot<Map<String, dynamic>>;
      final solvedQuizSnapshot = futures[1] as QuerySnapshot<Map<String, dynamic>>;
      final trialExamSnapshot = futures[2] as QuerySnapshot<Map<String, dynamic>>;
      final categoriesSnapshot = futures[3] as QuerySnapshot<Map<String, dynamic>>;

      // --- Hesaplamalar ---
      _overallTotalScore = (userDoc.data()?['toplamPuan'] as num? ?? 0).toInt();
      _totalSolvedQuizzes = solvedQuizSnapshot.size;
      _totalTrialExams = trialExamSnapshot.size;

      int quizCorrect = 0;
      int quizWrong = 0;
      int quizTimeSpent = 0;
      _totalScoreFromQuizzes = 0;
      Map<String, List<Map<String, dynamic>>> quizzesByCategory = {};

      for (var doc in solvedQuizSnapshot.docs) {
        final data = doc.data();
        final int correct = (data['dogruSayisi'] as num? ?? 0).toInt();
        final int wrong = (data['yanlisSayisi'] as num? ?? 0).toInt();
        final int time = (data['harcananSureSn'] as num? ?? 0).toInt();
        final int score = (data['puan'] as num? ?? 0).toInt();
        final String? categoryId = data['kategoriId'] as String?;

        quizCorrect += correct;
        quizWrong += wrong;
        quizTimeSpent += time;
        _totalScoreFromQuizzes += score;

        if (categoryId != null) {
          quizzesByCategory.putIfAbsent(categoryId, () => []).add({
            'score': score,
            'correct': correct,
            'wrong': wrong,
          });
        }
      }

      int trialCorrect = 0;
      int trialTotalQuestions = 0;
      _totalScoreFromTrials = 0;
      double totalKpssPuan = 0.0;
      double totalNet = 0.0;

      for (var doc in trialExamSnapshot.docs) {
        final data = doc.data();
        trialCorrect += (data['correctAnswers'] as num? ?? 0).toInt();
        trialTotalQuestions += (data['totalQuestions'] as num? ?? 0).toInt();
        _totalScoreFromTrials += (data['score'] as num? ?? 0).toInt();
        totalKpssPuan += (data['kpssPuan'] as num? ?? 0.0).toDouble();
        totalNet += (data['netSayisi'] as num? ?? 0.0).toDouble();
      }

      int totalCorrectOverall = quizCorrect + trialCorrect;
      int totalQuestionsOverall = (quizCorrect + quizWrong) + trialTotalQuestions;
      _overallAccuracy = totalQuestionsOverall > 0 ? (totalCorrectOverall / totalQuestionsOverall) * 100 : 0.0;
      _averageQuizTimeSeconds = _totalSolvedQuizzes > 0 ? (quizTimeSpent / _totalSolvedQuizzes) : 0.0;

      // Kategori İstatistikleri
      Map<String, String> categoryNames = {
        for (var doc in categoriesSnapshot.docs)
          doc.id: doc.data()['ad'] ?? 'Bilinmeyen',
      };
      Map<String, Map<String, dynamic>> tempCategoryStats = {};
      quizzesByCategory.forEach((catId, quizzes) {
        int catCorrect = 0;
        int catWrong = 0;
        int catHighestScore = 0;
        quizzes.forEach((quiz) {
          catCorrect += (quiz['correct'] as int? ?? 0);
          catWrong += (quiz['wrong'] as int? ?? 0);
          if ((quiz['score'] as int? ?? 0) > catHighestScore)
            catHighestScore = (quiz['score'] as int? ?? 0);
        });
        int catTotalQuestions = catCorrect + catWrong;
        double catAccuracy = catTotalQuestions > 0 ? (catCorrect / catTotalQuestions) * 100 : 0.0;
        
        // --- DÜZELTME: colorScheme ve icon ataması kaldırıldı ---
        tempCategoryStats[catId] = {
          'name': categoryNames[catId] ?? catId,
          'solvedCount': quizzes.length,
          'accuracy': catAccuracy,
          'highestScore': catHighestScore,
          // 'color': _getCategoryColor(catId, colorScheme.primary), // <<< KALDIRILDI
          // 'icon': _getCategoryIcon(catId), // <<< KALDIRILDI
        };
        // --- DÜZELTME BİTTİ ---
      });
      _categoryStats = Map.fromEntries(
        tempCategoryStats.entries.toList()..sort(
          (e1, e2) => (e2.value['solvedCount'] as int).compareTo(e1.value['solvedCount'] as int),
        ),
      );

      // Deneme Sınavı İstatistikleri
      _averageTrialScore = _totalTrialExams > 0 ? (_totalScoreFromTrials / _totalTrialExams) : 0.0;
      _averageTrialKpssPuan = _totalTrialExams > 0 ? (totalKpssPuan / _totalTrialExams) : 0.0;
      _averageTrialNet = _totalTrialExams > 0 ? (totalNet / _totalTrialExams) : 0.0;
      _trialAccuracy = trialTotalQuestions > 0 ? (trialCorrect / trialTotalQuestions) * 100 : 0.0;

      // Controller'ları (yeniden) oluştur
      for (var controller in _cardAnimationControllers) {
         controller.dispose();
      }
      _cardAnimationControllers = List.generate(
        3,
        (index) => AnimationController(
          duration: Duration(milliseconds: 600 + (index * 150)),
          vsync: this,
        ),
      );

      if (mounted) {
        setState(() { _isLoading = false; });
        _animationController.forward();
        _progressAnimationController.forward();
        for (var controller in _cardAnimationControllers) {
          controller.forward();
        }
      }
    } catch (e, st) {
      print("İstatistik yüklenirken hata: $e");
      print(st);
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = "İstatistikler yüklenirken bir hata oluştu.";
        });
    }
  }

  // Sayı formatları
  final NumberFormat _percentFormat = NumberFormat("##0.0'%'");
  final NumberFormat _scoreFormat = NumberFormat("###,##0");
  final NumberFormat _countFormat = NumberFormat("###,##0");
  final NumberFormat _timeFormat = NumberFormat("##0 'sn'");
  final NumberFormat _netFormat = NumberFormat("##0.00 'Net'");


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text('İstatistiklerim', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
              tooltip: 'Yenile',
              onPressed: _isLoading ? null : _loadStatistics,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: CircularProgressIndicator(color: colorScheme.primary, strokeWidth: 3),
                  ),
                  const SizedBox(height: 24),
                  Text('İstatistikler Yükleniyor...', style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80, padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: colorScheme.errorContainer, shape: BoxShape.circle),
                      child: Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(_error!, textAlign: TextAlign.center, style: textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Text('Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [ BoxShadow(color: colorScheme.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)) ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Dene'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _loadStatistics,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              color: colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // --- GENEL İSTATİSTİKLER KARTI ---
                    _buildModernSectionCard(
                      title: 'Genel Bakış',
                      icon: Icons.insights_rounded,
                      color: colorScheme.primary,
                      controller: _cardAnimationControllers.isNotEmpty ? _cardAnimationControllers[0] : null,
                      children: [
                        _buildModernStatGrid([
                          _buildModernStatItem(
                            Icons.quiz_outlined,
                            'Çözülen Test',
                            _countFormat.format(_totalSolvedQuizzes),
                            colorScheme.primary,
                          ),
                          _buildModernStatItem(
                            Icons.assignment_outlined,
                            'Deneme Sınavı',
                            _countFormat.format(_totalTrialExams),
                            colorScheme.secondary,
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildModernStatGrid([
                          _buildModernStatItem(
                            Icons.star_outline_rounded,
                            'Toplam Puan',
                            _scoreFormat.format(_overallTotalScore),
                            Colors.amber.shade700,
                          ),
                          _buildModernStatItem(
                            Icons.check_circle_outline_rounded,
                            'Genel Başarı',
                            _percentFormat.format(_overallAccuracy),
                            _getAccuracyColor(_overallAccuracy),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildModernStatItem(
                          Icons.timer_outlined,
                          'Ort. Test Süresi',
                          _timeFormat.format(_averageQuizTimeSeconds),
                          Colors.purple.shade400,
                          isFullWidth: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- KATEGORİ PERFORMANSI KARTI ---
                    _buildModernSectionCard(
                      title: 'Kategori Performansı',
                      icon: Icons.category_outlined,
                      color: colorScheme.secondary,
                      controller: _cardAnimationControllers.length > 1 ? _cardAnimationControllers[1] : null,
                      children: _categoryStats.isEmpty
                          ? [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.category_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Henüz test çözülmemiş.',
                                        style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]
                          : _categoryStats.entries.map((entry) {
                              final stats = entry.value;
                              final catName = stats['name'] ?? 'Bilinmeyen';
                              final solved = stats['solvedCount'] ?? 0;
                              final accuracy = stats['accuracy'] ?? 0.0;
                              final highest = stats['highestScore'] ?? 0;
                              
                              // --- DÜZELTME: İkon ve Renk burada, build() içinde atanıyor ---
                              final catIcon = _getCategoryIcon(entry.key);
                              final catColor = _getCategoryColor(entry.key, colorScheme.primary);
                              // --- DÜZELTME BİTTİ ---

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _buildCategoryPerformanceCard(
                                  catIcon, catColor, catName,
                                  solved, accuracy, highest,
                                ),
                              );
                            }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // --- DENEME SINAVI PERFORMANSI KARTI ---
                    _buildModernSectionCard(
                      title: 'Deneme Sınavları',
                      icon: Icons.assignment_turned_in_outlined,
                      color: Colors.teal.shade600,
                      controller: _cardAnimationControllers.length > 2 ? _cardAnimationControllers[2] : null,
                      children: _totalTrialExams == 0
                          ? [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.assignment_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Henüz deneme sınavına girilmemiş.',
                                        style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]
                          : [
                              _buildModernStatGrid([
                                _buildModernStatItem(
                                  Icons.calculate_outlined,
                                  'Ort. KPSS Puanı',
                                  _averageTrialKpssPuan.toStringAsFixed(3),
                                  Colors.teal.shade600,
                                ),
                                _buildModernStatItem(
                                  Icons.functions_rounded,
                                  'Ort. Net',
                                  _netFormat.format(_averageTrialNet),
                                  Colors.blue.shade600,
                                ),
                              ]),
                            ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // Modern bölüm kartı
  Widget _buildModernSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    AnimationController? controller,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    Widget cardChild = Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [colorScheme.surface, colorScheme.surface.withOpacity(0.9)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );

    if (controller != null) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: controller, curve: Curves.easeInOut),
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                      .animate(
                CurvedAnimation(parent: controller, curve: Curves.easeOut),
              ),
              child: cardChild,
            ),
          );
        },
      );
    }
    return cardChild;
  }

  // Modern istatistik grid'i
  Widget _buildModernStatGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: children,
        );
      },
    );
  }

  // Modern istatistik öğesi
  Widget _buildModernStatItem(
    IconData icon,
    String label,
    String value,
    Color color, {
    bool isFullWidth = false,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Kategori performans kartı
  Widget _buildCategoryPerformanceCard(
    IconData icon,
    Color color,
    String name,
    int solvedCount,
    double accuracy,
    int highestScore,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$solvedCount test çözüldü',
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildProgressIndicator(
                  'Başarı Oranı',
                  accuracy,
                  _getAccuracyColor(accuracy),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProgressIndicator(
                  'En Yüksek Puan',
                  highestScore.toDouble(),
                  Colors.amber.shade700,
                  // (Burada maxValue'yu dinamik olarak en yüksek puana göre ayarlamak daha iyi olurdu,
                  // ancak şimdilik sabit bir değere (örn: 2000 puan) göre oranlayalım)
                  maxValue: 2000, 
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // İlerleme göstergesi
  Widget _buildProgressIndicator(
    String label,
    double value,
    Color color, {
    double maxValue = 100.0,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final progress = (value / maxValue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
             value: progress,
             minHeight: 8,
             backgroundColor: color.withOpacity(0.2),
             valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label == 'Başarı Oranı'
              ? _percentFormat.format(value)
              : _scoreFormat.format(value.toInt()),
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Kategoriye özel renk
  Color _getCategoryColor(String catId, Color defaultColor) {
    switch (catId) {
      case 'tarih': return Colors.brown;
      case 'matematik': return Colors.blue;
      case 'cografya': return Colors.green;
      case 'turkce': return Colors.red;
      case 'vatandaslik': return Colors.purple;
      default: return defaultColor;
    }
  }

  // Kategoriye özel ikon
  IconData _getCategoryIcon(String catId) {
    switch (catId) {
      case 'tarih': return Icons.history_edu;
      case 'matematik': return Icons.calculate;
      case 'cografya': return Icons.public;
      case 'turkce': return Icons.translate;
      case 'vatandaslik': return Icons.gavel;
      default: return Icons.label_outline;
    }
  }

  // Başarı yüzdesine göre renk
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 75) return Colors.green.shade600;
    if (accuracy >= 50) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}