import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/screens/result_screen.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class QuizScreen extends StatefulWidget {
  final String quizId;
  final String quizBaslik;
  final int soruSayisi;
  final int sureDakika;
  final String kategoriId;

  const QuizScreen({
    super.key,
    required this.quizId,
    required this.quizBaslik,
    required this.soruSayisi,
    required this.sureDakika,
    required this.kategoriId,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<DocumentSnapshot> _questions = [];
  int _currentQuestionIndex = 0;
  Map<String, int> _selectedAnswers = {};
  Timer? _timer;
  int _secondsRemaining = 0;
  List<QueryDocumentSnapshot> _achievementDefinitions = [];
  String? _fetchError;

  // --- YENİ STATE'LER ---
  Map<String, bool?> _answerStatus = {};
  bool _autoAdvanceEnabled = true;
  Timer? _advanceTimer;

  // Animasyon için yeni state'ler - late olarak tanımlandı
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<Color?> _progressColorAnimation;
  // --- YENİ STATE'LER BİTTİ ---

  @override
  void initState() {
    super.initState();

    // Animasyon controller'ını ve animasyonları başlat
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Animasyonları başlangıç değerleriyle başlat
    _initializeAnimations();

    _fetchQuestions();
    _loadAchievementDefinitions();
  }

  // Animasyonları başlangıç değerleriyle başlat
  void _initializeAnimations() {
    final totalSeconds = widget.sureDakika * 60;
    final initialProgress = _secondsRemaining / totalSeconds;

    _progressAnimation =
        Tween<double>(begin: initialProgress, end: initialProgress).animate(
          CurvedAnimation(
            parent: _progressAnimationController,
            curve: Curves.easeOut,
          ),
        );

    _progressColorAnimation =
        ColorTween(
          begin: _getProgressColor(initialProgress),
          end: _getProgressColor(initialProgress),
        ).animate(
          CurvedAnimation(
            parent: _progressAnimationController,
            curve: Curves.easeOut,
          ),
        );
  }

  // Animasyonları güncelle
  void _updateProgressAnimations() {
    final totalSeconds = widget.sureDakika * 60;
    final progressValue = _secondsRemaining / totalSeconds;

    _progressAnimation =
        Tween<double>(
          begin: _progressAnimation.value,
          end: progressValue,
        ).animate(
          CurvedAnimation(
            parent: _progressAnimationController,
            curve: Curves.easeOut,
          ),
        );

    _progressColorAnimation =
        ColorTween(
          begin: _getProgressColor(_progressAnimation.value),
          end: _getProgressColor(progressValue),
        ).animate(
          CurvedAnimation(
            parent: _progressAnimationController,
            curve: Curves.easeOut,
          ),
        );

    _progressAnimationController.forward(from: 0);
  }

  Color _getProgressColor(double progress) {
    if (progress > 0.5) return Colors.green;
    if (progress > 0.25) return Colors.orange;
    return Colors.red;
  }

  Future<void> _loadAchievementDefinitions() async {
    try {
      final snapshot = await _firestore.collection('achievements').get();
      if (mounted) {
        setState(() {
          _achievementDefinitions = snapshot.docs;
        });
      }
    } catch (e) {
      print("Başarı tanımları yüklenirken hata: $e");
    }
  }

  Future<void> _fetchQuestions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _fetchError = null;
    });

    try {
      final snapshot = await _firestore
          .collection('questions')
          .where('quizId', isEqualTo: widget.quizId)
          .get();

      if (mounted) {
        var fetchedQuestions = snapshot.docs;
        fetchedQuestions.shuffle();

        final int countToTake =
            (widget.soruSayisi > 0 &&
                widget.soruSayisi <= fetchedQuestions.length)
            ? widget.soruSayisi
            : fetchedQuestions.length;

        setState(() {
          _questions = fetchedQuestions.take(countToTake).toList();
          _isLoading = false;
          if (_questions.isNotEmpty) {
            // Animasyonları güncelle ve timer'ı başlat
            _initializeAnimations();
            _startTimer();
          }
        });
      }
    } catch (e) {
      print("Quiz soruları çekilirken hata: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          String errorMsg = "Sorular yüklenirken bir hata oluştu.";
          if (e is FirebaseException) {
            if (e.code == 'permission-denied')
              errorMsg = "Soruları okuma izniniz yok.";
            else if (e.code == 'unavailable')
              errorMsg = "Sunucuya bağlanılamadı. İnternetinizi kontrol edin.";
          }
          _fetchError = errorMsg;
        });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = widget.sureDakika * 60;

    // Animasyonları başlangıç değerleriyle güncelle
    _updateProgressAnimations();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
          _updateProgressAnimations();
        } else {
          _timer?.cancel();
          if (!_isSubmitting) {
            _submitQuiz();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _advanceTimer?.cancel();
    _progressAnimationController.dispose();
    super.dispose();
  }

  void _selectAnswer(String questionId, int selectedIndex, int correctIndex) {
    if (_answerStatus.containsKey(questionId) || _isLoading || _isSubmitting)
      return;

    _advanceTimer?.cancel();

    final bool isCorrect = selectedIndex == correctIndex;

    setState(() {
      _selectedAnswers[questionId] = selectedIndex;
      _answerStatus[questionId] = isCorrect;
    });

    if (_autoAdvanceEnabled) {
      _advanceTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) _moveToNextOrFinish();
      });
    }
  }

  void _moveToNextOrFinish() {
    _advanceTimer?.cancel();
    if (_currentQuestionIndex < _questions.length - 1) {
      _nextQuestion();
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();
    _advanceTimer?.cancel();
    if (_isSubmitting || !mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    final user = _authService.currentUser;
    if (user == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Puanı kaydetmek için giriş yapmalısınız.'),
          ),
        );
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    try {
      final solvedDocRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('solvedQuizzes')
          .doc(widget.quizId);
      final solvedDoc = await solvedDocRef.get();
      if (solvedDoc.exists) {
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ResultScreen(fromHistory: true, solvedData: solvedDoc.data()),
            ),
          );
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      int dogruSayisi = 0;
      int yanlisSayisi = 0;
      int actualQuestionCount = _questions.length;
      for (var question in _questions) {
        final questionId = question.id;
        final correctIndex =
            (question['dogruCevapIndex'] as num?)?.toInt() ?? -1;
        if (_selectedAnswers.containsKey(questionId) &&
            _selectedAnswers[questionId] == correctIndex)
          dogruSayisi++;
        else
          yanlisSayisi++;
      }
      int puan = (dogruSayisi * 100) + (_secondsRemaining * 5);

      Map<String, dynamic> newSolvedData = {
        'quizBaslik': widget.quizBaslik,
        'kategoriId': widget.kategoriId,
        'puan': puan,
        'tarih': FieldValue.serverTimestamp(),
        'dogruSayisi': dogruSayisi,
        'yanlisSayisi': yanlisSayisi,
        'harcananSureSn': (widget.sureDakika * 60) - _secondsRemaining,
      };
      await solvedDocRef.set(newSolvedData);

      final userDocRef = _firestore.collection('users').doc(user.uid);
      await userDocRef.set({
        'toplamPuan': FieldValue.increment(puan),
      }, SetOptions(merge: true));

      final updatedUserDoc = await userDocRef.get();
      final updatedTotalScore =
          (updatedUserDoc.data()?['toplamPuan'] as num? ?? 0).toInt();
      final updatedSolvedCountSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('solvedQuizzes')
          .count()
          .get();
      final updatedSolvedCount = updatedSolvedCountSnapshot.count ?? 0;
      await _checkAndGrantAchievements(
        userId: user.uid,
        solvedCount: updatedSolvedCount,
        totalScore: updatedTotalScore,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              quizId: widget.quizId,
              puan: puan,
              dogruSayisi: dogruSayisi,
              soruSayisi: actualQuestionCount,
              fromHistory: false,
            ),
          ),
        );
      }
    } catch (e) {
      print("Sonuçları kaydederken hata: $e");
      String errorMessage = 'Puanınız kaydedilemedi. Lütfen tekrar deneyin.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied')
          errorMessage = 'Puanı kaydetme izniniz yok.';
        else if (e.code == 'unavailable')
          errorMessage = 'Sunucuya bağlanılamadı.';
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Başarıları kontrol etme ve kazandırma (GÜNCELLENDİ: Kategori kriteri eklendi)
  Future<void> _checkAndGrantAchievements({
    required String userId,
    required int solvedCount, // Toplam çözülen sayı (zaten alıyoruz)
    required int totalScore, // Toplam skor (zaten alıyoruz)
  }) async {
    if (_achievementDefinitions.isEmpty || !mounted) return;

    try {
      // 1. Kullanıcının zaten kazandığı başarıların ID'lerini al (aynı)
      final earnedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('earnedAchievements')
          .get();
      final earnedAchievementIds = earnedSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      // --- YENİ: Kategori bazlı çözülen sayılarını hesapla ---
      final solvedByCategorySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('solvedQuizzes')
          .get();
      Map<String, int> solvedCountsByCategory = {};
      for (var doc in solvedByCategorySnapshot.docs) {
        final data = doc.data();
        final categoryId = data['kategoriId'] as String?;
        if (categoryId != null) {
          solvedCountsByCategory[categoryId] =
              (solvedCountsByCategory[categoryId] ?? 0) + 1;
        }
      }
      // --- YENİ KISIM BİTTİ ---

      // 2. Henüz kazanılmamış başarıları kontrol et
      WriteBatch? batch;
      List<Map<String, dynamic>> newlyEarnedAchievements = [];

      for (var achievementDoc in _achievementDefinitions) {
        final achievementId = achievementDoc.id;
        if (earnedAchievementIds.contains(achievementId))
          continue; // Zaten kazanılmışsa atla

        final achievementData = achievementDoc.data() as Map<String, dynamic>?;
        if (achievementData == null) continue;

        final criteriaType = achievementData['criteria_type'] as String?;
        final criteriaValue =
            (achievementData['criteria_value'] as num?)?.toInt() ?? 0;
        final String achievementName =
            achievementData['name'] as String? ?? 'İsimsiz Başarı';
        final String achievementEmoji =
            achievementData['emoji'] as String? ?? '🏆';
        final String achievementDescription =
            achievementData['description'] as String? ?? '';

        bool earned = false; // Başarı kazanıldı mı?

        // Kriterleri kontrol et
        switch (criteriaType) {
          case 'solved_count':
            if (solvedCount >= criteriaValue) earned = true;
            break;
          case 'total_score':
            if (totalScore >= criteriaValue) earned = true;
            break;
          // --- YENİ KRİTER KONTROLÜ ---
          case 'category_solved_count':
            final requiredCategory =
                achievementData['criteria_category'] as String?;
            if (requiredCategory != null &&
                (solvedCountsByCategory[requiredCategory] ?? 0) >=
                    criteriaValue) {
              earned = true;
            }
            break;
          // --- YENİ KRİTER BİTTİ ---
          // TODO: 'speed_accuracy' gibi başka kriterler buraya eklenebilir
        }

        // Başarı kazanıldıysa
        if (earned) {
          print("🎉 Yeni Başarı Kazanıldı: ${achievementName}");
          batch ??= _firestore.batch();
          final newEarnedRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('earnedAchievements')
              .doc(achievementId);
          batch.set(newEarnedRef, {
            'earnedDate': FieldValue.serverTimestamp(),
            'name': achievementName,
            'emoji': achievementEmoji, // Verileri de ekleyelim
          });
          newlyEarnedAchievements.add({
            'name': achievementName,
            'emoji': achievementEmoji,
            'description': achievementDescription,
          });
        }
      } // for döngüsü bitti

      // 3. Kazanılan yeni başarılar varsa kaydet ve popup göster (aynı)
      if (batch != null) {
        await batch.commit();
        print("Kazanılan başarılar kaydedildi.");
        if (mounted) {
          /* ... (popup gösterme kodu aynı) ... */
        }
      }
    } catch (e) {
      print("Başarı kontrolü sırasında hata: $e");
    }
  }

  void _showAchievementEarnedDialog(Map<String, dynamic> achievementData) {
    if (!mounted) return;
    final emoji = achievementData['emoji'] as String? ?? '🏆';
    final name = achievementData['name'] as String? ?? 'Başarı';
    final description = achievementData['description'] as String? ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade700, Colors.purple.shade700],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji ve animasyon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 40)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Başlık
                  Text(
                    "Tebrikler!",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Başarı adı
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Açıklama
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Kapatma butonu
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Harika!",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _nextQuestion() {
    _advanceTimer?.cancel();
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  void _previousQuestion() {
    _advanceTimer?.cancel();
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Sorular Yükleniyor...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_fetchError != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  'Sorular Yüklenemedi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _fetchError!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _fetchQuestions,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Dene'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Geri Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.quiz_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onBackground.withOpacity(0.5),
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  'Soru Bulunamadı',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu teste ait soru bulunamadı veya henüz eklenmemiş.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Geri Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int actualQuestionCount = _questions.length;
    if (_currentQuestionIndex >= _questions.length)
      _currentQuestionIndex = _questions.length - 1;
    if (_currentQuestionIndex < 0) _currentQuestionIndex = 0;

    final currentQuestion = _questions[_currentQuestionIndex];
    final questionId = currentQuestion.id;
    final questionData = currentQuestion.data() as Map<String, dynamic>? ?? {};
    final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
    final options = List<String>.from(questionData['secenekler'] ?? []);
    final correctIndex =
        (questionData['dogruCevapIndex'] as num?)?.toInt() ?? -1;
    final bool? answerCorrectness = _answerStatus[questionId];
    final bool isAnswered = answerCorrectness != null;
    final int? userAnswerIndex = _selectedAnswers[questionId];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          widget.quizBaslik,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Otomatik Geçiş Toggle
          Tooltip(
            message: _autoAdvanceEnabled
                ? 'Otomatik İlerleme Açık'
                : 'Otomatik İlerleme Kapalı',
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _autoAdvanceEnabled
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(
                      'Otomatik',
                      style: TextStyle(
                        fontSize: 12,
                        color: _autoAdvanceEnabled
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Switch(
                    value: _autoAdvanceEnabled,
                    onChanged: (value) {
                      setState(() {
                        _autoAdvanceEnabled = value;
                      });
                      if (!value) _advanceTimer?.cancel();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar ve Zamanlayıcı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Süre Progress Bar
                AnimatedBuilder(
                  animation: _progressAnimationController,
                  builder: (context, child) {
                    return Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Stack(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width:
                                    constraints.maxWidth *
                                    _progressAnimation.value,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _progressColorAnimation.value ??
                                          Colors.green,
                                      _progressColorAnimation.value ??
                                          Colors.green,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Üst Bilgi Satırı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Soru Sayacı
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_currentQuestionIndex + 1}/$actualQuestionCount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Zamanlayıcı
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _secondsRemaining < 60
                            ? Colors.red.withOpacity(0.1)
                            : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _secondsRemaining < 60
                              ? Colors.red.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: _secondsRemaining < 60
                                ? Colors.red
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formattedTime,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _secondsRemaining < 60
                                  ? Colors.red
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Soru İçeriği
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Soru Metni
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            'Soru ${_currentQuestionIndex + 1}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            questionText,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Seçenekler
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final bool isCorrectOption = index == correctIndex;
                        final bool isSelectedOption = index == userAnswerIndex;
                        final bool isOptionDisabled =
                            isAnswered || correctIndex == -1;

                        Color cardColor = Theme.of(context).colorScheme.surface;
                        Color borderColor = Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.3);
                        Color textColor = Theme.of(
                          context,
                        ).colorScheme.onSurface;
                        IconData? leadingIcon;
                        Color? leadingIconColor;

                        // Cevap durumuna göre stil
                        if (isAnswered) {
                          if (isCorrectOption) {
                            cardColor = Colors.green.withOpacity(0.1);
                            borderColor = Colors.green;
                            textColor = Colors.green.shade800;
                            leadingIcon = Icons.check_circle_rounded;
                            leadingIconColor = Colors.green;
                          } else if (isSelectedOption) {
                            cardColor = Colors.red.withOpacity(0.1);
                            borderColor = Colors.red;
                            textColor = Colors.red.shade800;
                            leadingIcon = Icons.cancel_rounded;
                            leadingIconColor = Colors.red;
                          } else {
                            cardColor = Theme.of(
                              context,
                            ).colorScheme.surfaceVariant;
                            textColor = Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant;
                          }
                        }

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            elevation: isAnswered ? 1 : 0,
                            child: InkWell(
                              onTap: isOptionDisabled
                                  ? null
                                  : () {
                                      _selectAnswer(
                                        questionId,
                                        index,
                                        correctIndex,
                                      );
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Seçenek Harfi
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isOptionDisabled
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.1)
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          String.fromCharCode(
                                            65 + index,
                                          ), // A, B, C, D
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isOptionDisabled
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.5)
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    // Seçenek Metni
                                    Expanded(
                                      child: Text(
                                        options[index],
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.4,
                                          color: textColor,
                                        ),
                                      ),
                                    ),

                                    // Durum İkonu
                                    if (leadingIcon != null) ...[
                                      const SizedBox(width: 12),
                                      Icon(
                                        leadingIcon,
                                        color: leadingIconColor,
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Navigasyon Butonları
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Önceki Buton
                        AnimatedOpacity(
                          opacity: _currentQuestionIndex > 0 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: IgnorePointer(
                            ignoring: _currentQuestionIndex == 0,
                            child: FilledButton.tonal(
                              onPressed: _previousQuestion,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_back_ios_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text('Önceki'),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Sonraki/Bitir Butonu
                        if (!_autoAdvanceEnabled || !isAnswered)
                          _currentQuestionIndex == _questions.length - 1
                              ? FilledButton(
                                  onPressed: (isAnswered && !_isSubmitting)
                                      ? _submitQuiz
                                      : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_rounded, size: 18),
                                            SizedBox(width: 8),
                                            Text('Testi Bitir'),
                                          ],
                                        ),
                                )
                              : FilledButton(
                                  onPressed: isAnswered ? _nextQuestion : null,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Sonraki'),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                )
                        else
                          const SizedBox(width: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
