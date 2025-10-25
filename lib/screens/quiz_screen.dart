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
  final bool isReplay;

  const QuizScreen({
    super.key,
    required this.quizId,
    required this.quizBaslik,
    required this.soruSayisi,
    required this.sureDakika,
    required this.kategoriId,
    this.isReplay = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // ... (initState, dispose, ve diğer tüm fonksiyonlar AYNI) ...
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
  Map<String, bool?> _answerStatus = {};
  bool _autoAdvanceEnabled = true;
  Timer? _advanceTimer;
  late AnimationController _progressAnimationController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _progressAnimation;
  late Animation<Color?> _progressColorAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fetchQuestions();
    _loadAchievementDefinitions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationsInitialized) {
      _secondsRemaining = widget.sureDakika * 60;
      _initializeAnimations();
      _animationsInitialized = true;
    }
  }

  void _initializeAnimations() { /* ... (Tam kod öncekiyle aynı) ... */ 
    final totalSeconds = (widget.sureDakika * 60).toDouble();
    if (totalSeconds == 0) return;
    final initialProgress = _secondsRemaining / totalSeconds;
    _progressAnimation = Tween<double>(begin: initialProgress, end: initialProgress).animate(CurvedAnimation(parent: _progressAnimationController, curve: Curves.linear))..addListener(() { setState(() {}); });
    _progressColorAnimation = ColorTween(begin: _getProgressColor(initialProgress), end: _getProgressColor(initialProgress)).animate(CurvedAnimation(parent: _progressAnimationController, curve: Curves.linear));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
  }
  void _updateProgressAnimations() { /* ... (Tam kod öncekiyle aynı) ... */ 
    final totalSeconds = (widget.sureDakika * 60).toDouble();
    if (totalSeconds == 0) return;
    final progressValue = _secondsRemaining / totalSeconds;
    _progressAnimation = Tween<double>(begin: _progressAnimation.value, end: progressValue).animate(_progressAnimationController);
    _progressColorAnimation = ColorTween(begin: _getProgressColor(_progressAnimation.value), end: _getProgressColor(progressValue)).animate(_progressAnimationController);
    _progressAnimationController.value = 0.0;
    _progressAnimationController.animateTo(1.0, duration: const Duration(seconds: 1), curve: Curves.linear);
  }
  Color _getProgressColor(double progress) { /* ... (Tam kod öncekiyle aynı) ... */ 
    final colorScheme = Theme.of(context).colorScheme;
    if (progress > 0.4) return Colors.green.shade400;
    if (progress > 0.15) return Colors.orange.shade400;
    return colorScheme.error;
  }
  Future<void> _loadAchievementDefinitions() async { /* ... (Tam kod öncekiyle aynı) ... */ 
     try {
      final snapshot = await _firestore.collection('achievements').get();
      if (mounted) { setState(() { _achievementDefinitions = snapshot.docs; }); }
    } catch (e) { print("Başarı tanımları yüklenirken hata: $e"); }
  }
  Future<void> _fetchQuestions() async { /* ... (Tam kod öncekiyle aynı) ... */ 
    if (!mounted) return;
    setState(() { _isLoading = true; _fetchError = null; });
    try {
      final snapshot = await _firestore.collection('questions').where('quizId', isEqualTo: widget.quizId).get();
      if (mounted) {
        var fetchedQuestions = snapshot.docs;
        fetchedQuestions.shuffle();
        final int countToTake = (widget.soruSayisi > 0 && widget.soruSayisi <= fetchedQuestions.length) ? widget.soruSayisi : fetchedQuestions.length;
        setState(() {
          _questions = fetchedQuestions.take(countToTake).toList();
          _isLoading = false;
          if (_questions.isNotEmpty) { _startTimer(); }
        });
      }
    } catch (e) {
      print("Quiz soruları çekilirken hata: $e");
      if (mounted) { setState(() { _isLoading = false; _fetchError = "Sorular yüklenemedi: $e"; }); }
    }
  }
  void _startTimer() { /* ... (Tam kod öncekiyle aynı) ... */ 
    _timer?.cancel();
    if(_animationsInitialized) {
       _progressAnimationController.reset();
       _progressAnimationController.value = _progressAnimation.value;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--; _updateProgressAnimations();
        } else {
          _timer?.cancel(); if (!_isSubmitting) _submitQuiz();
        }
      });
    });
  }
  @override
  void dispose() { /* ... (Tam kod öncekiyle aynı) ... */ 
    _timer?.cancel(); _advanceTimer?.cancel();
    _progressAnimationController.dispose(); _fadeController.dispose(); _slideController.dispose();
    super.dispose();
  }
  void _selectAnswer(String questionId, int selectedIndex, int correctIndex) { /* ... (Tam kod öncekiyle aynı) ... */ 
    if (_answerStatus.containsKey(questionId) || _isLoading || _isSubmitting) return;
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
  void _moveToNextOrFinish() { /* ... (Tam kod öncekiyle aynı) ... */ 
    _advanceTimer?.cancel();
    _advanceTimer = null; 
    if (_currentQuestionIndex < _questions.length - 1) {
      _nextQuestion();
    } else {
      _submitQuiz();
    }
  }

  // --- _submitQuiz GÜNCELLENDİ (Sadece normal quiz verisi gönderiyor) ---
  Future<void> _submitQuiz() async {
    _timer?.cancel();
    _advanceTimer?.cancel();
    if (_isSubmitting || !mounted) return;
    setState(() { _isSubmitting = true; });

    final user = _authService.currentUser;

    int dogruSayisi = 0; int yanlisSayisi = 0;
    int actualQuestionCount = _questions.length;
    for (var question in _questions) {
      final questionId = question.id;
      final correctIndex = (question['dogruCevapIndex'] as num?)?.toInt() ?? -1;
      if (_selectedAnswers.containsKey(questionId) && _selectedAnswers[questionId] == correctIndex)
        dogruSayisi++;
      else
        yanlisSayisi++;
    }
    int puan = (dogruSayisi * 10) + (_secondsRemaining * 1); 

    try {
      if (widget.isReplay) {
        print("Tekrar çözüm. Puan ($puan) kaydedilmedi.");
      } else if (user != null) { 
        final solvedDocRef = _firestore.collection('users').doc(user.uid).collection('solvedQuizzes').doc(widget.quizId);
        final solvedDoc = await solvedDocRef.get();
        if (solvedDoc.exists) {
           if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResultScreen(fromHistory: true, solvedData: solvedDoc.data())));
           if (mounted) setState(() => _isSubmitting = false);
           return;
        }
        
        print("İlk çözüm. Puan ($puan) kaydediliyor...");
        Map<String, dynamic> newSolvedData = {
          'quizBaslik': widget.quizBaslik, 'kategoriId': widget.kategoriId,
          'puan': puan, 'tarih': FieldValue.serverTimestamp(),
          'dogruSayisi': dogruSayisi, 'yanlisSayisi': yanlisSayisi,
          'harcananSureSn': (widget.sureDakika * 60) - _secondsRemaining,
        };
        await solvedDocRef.set(newSolvedData);
        final userDocRef = _firestore.collection('users').doc(user.uid);
        await userDocRef.set({'toplamPuan': FieldValue.increment(puan)}, SetOptions(merge: true));
        
        final updatedUserDoc = await userDocRef.get();
        final updatedTotalScore = (updatedUserDoc.data()?['toplamPuan'] as num? ?? 0).toInt();
        final updatedSolvedCountSnapshot = await _firestore.collection('users').doc(user.uid).collection('solvedQuizzes').count().get();
        final updatedSolvedCount = updatedSolvedCountSnapshot.count ?? 0;
        await _checkAndGrantAchievements(userId: user.uid, solvedCount: updatedSolvedCount, totalScore: updatedTotalScore);
      
      } else {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puanı kaydetmek için giriş yapmalısınız.')));
      }

      if (mounted) {
        // --- DEĞİŞİKLİK BURADA ---
        // Artık deneme sınavı verilerini (questions, userAnswers vb.) göndermiyoruz
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              puan: puan,
              dogruSayisi: dogruSayisi,
              soruSayisi: actualQuestionCount,
              fromHistory: false, 
              isReplay: widget.isReplay, // Sadece 'isReplay' bilgisi
            ),
          ),
        );
        // --- DEĞİŞİKLİK BİTTİ ---
      }
    } catch (e) {
      print("Sonuçları kaydederken hata: $e");
      String errorMessage = 'Puanınız kaydedilemedi. Lütfen tekrar deneyin.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') errorMessage = 'Puanı kaydetme izniniz yok.';
        else if (e.code == 'unavailable') errorMessage = 'Sunucuya bağlanılamadı.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  // --- _submitQuiz Bitti ---

  Future<void> _checkAndGrantAchievements({required String userId, required int solvedCount, required int totalScore}) async {
     // ... (Bu fonksiyonun içi tam olarak öncekiyle aynı) ...
     if (_achievementDefinitions.isEmpty || !mounted) return;
     try {
       final earnedSnapshot = await _firestore.collection('users').doc(userId).collection('earnedAchievements').get();
       final earnedAchievementIds = earnedSnapshot.docs.map((doc) => doc.id).toSet();
       final solvedByCategorySnapshot = await _firestore.collection('users').doc(userId).collection('solvedQuizzes').get();
       Map<String, int> solvedCountsByCategory = {};
       for (var doc in solvedByCategorySnapshot.docs) {
           final data = doc.data();
           final categoryId = data['kategoriId'] as String?;
           if (categoryId != null) { solvedCountsByCategory[categoryId] = (solvedCountsByCategory[categoryId] ?? 0) + 1; }
       }
       WriteBatch? batch;
       List<Map<String, dynamic>> newlyEarnedAchievements = [];
       for (var achievementDoc in _achievementDefinitions) {
         final achievementId = achievementDoc.id;
         if (earnedAchievementIds.contains(achievementId)) continue;
         final achievementData = achievementDoc.data() as Map<String, dynamic>?;
         if (achievementData == null) continue;
         final criteriaType = achievementData['criteria_type'] as String?;
         final criteriaValue = (achievementData['criteria_value'] as num?)?.toInt() ?? 0;
         final String achievementName = achievementData['name'] as String? ?? 'İsimsiz Başarı';
         final String achievementEmoji = achievementData['emoji'] as String? ?? '🏆';
         final String achievementDescription = achievementData['description'] as String? ?? '';
         bool earned = false;
         switch (criteriaType) {
           case 'solved_count':
             if (solvedCount >= criteriaValue) earned = true;
             break;
           case 'total_score':
             if (totalScore >= criteriaValue) earned = true;
             break;
           case 'category_solved_count':
             final requiredCategory = achievementData['criteria_category'] as String?;
             if (requiredCategory != null && (solvedCountsByCategory[requiredCategory] ?? 0) >= criteriaValue) { earned = true; }
             break;
         }
         if (earned) {
           print("🎉 Yeni Başarı Kazanıldı: ${achievementName}");
           batch ??= _firestore.batch();
           final newEarnedRef = _firestore.collection('users').doc(userId).collection('earnedAchievements').doc(achievementId);
           batch.set(newEarnedRef, {'earnedDate': FieldValue.serverTimestamp(), 'name': achievementName, 'emoji': achievementEmoji});
           newlyEarnedAchievements.add({'name': achievementName, 'emoji': achievementEmoji, 'description': achievementDescription});
         }
       }
       if (batch != null) {
         await batch.commit();
         print("Kazanılan başarılar kaydedildi.");
         if (mounted) {
           for (var achievementData in newlyEarnedAchievements) {
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) _showAchievementEarnedDialog(achievementData);
           }
         }
       }
     } catch (e) { print("Başarı kontrolü sırasında hata: $e"); }
  }
  
  void _showAchievementEarnedDialog(Map<String, dynamic> achievementData) {
    // ... (Bu fonksiyonun içi tam olarak öncekiyle aynı) ...
     if (!mounted) return;
     final emoji = achievementData['emoji'] as String? ?? '🏆';
     final name = achievementData['name'] as String? ?? 'Başarı';
     final description = achievementData['description'] as String? ?? '';
     showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) {
         return Dialog(
           backgroundColor: Colors.transparent,
           child: Container(
             decoration: BoxDecoration(
               gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade700, Colors.purple.shade700]),
               borderRadius: BorderRadius.circular(24),
               boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)) ],
             ),
             child: Padding(
               padding: const EdgeInsets.all(24),
               child: Column(mainAxisSize: MainAxisSize.min, children: [
                   Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                     child: Center(child: Text(emoji, style: const TextStyle(fontSize: 40)))),
                   const SizedBox(height: 20),
                   Text("Tebrikler!", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                   Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                   const SizedBox(height: 8),
                   Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.9)), textAlign: TextAlign.center),
                   const SizedBox(height: 24),
                   ElevatedButton(
                     onPressed: () => Navigator.of(context).pop(),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.white, foregroundColor: Colors.blue.shade700,
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                     ),
                     child: const Text("Harika!", style: TextStyle(fontWeight: FontWeight.bold)),
                   ),
               ]),
             ),
           ),
         );
       },
     );
  }
  
  void _nextQuestion() async { /* ... (Tam kod öncekiyle aynı) ... */ 
    _advanceTimer?.cancel(); _advanceTimer = null;
    if (_currentQuestionIndex < _questions.length - 1) {
      await _slideController.reverse(); 
      if (mounted) { setState(() => _currentQuestionIndex++); _slideController.forward(); }
    }
  }
  void _previousQuestion() async { /* ... (Tam kod öncekiyle aynı) ... */ 
    _advanceTimer?.cancel(); _advanceTimer = null;
    if (_currentQuestionIndex > 0) {
      await _slideController.reverse();
      if (mounted) { setState(() => _currentQuestionIndex--); _slideController.forward(); }
    }
  }
  String get _formattedTime { /* ... (Tam kod öncekiyle aynı) ... */ 
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // === build METODU (Tam Kod - Değişiklik Yok) ===
  @override
  Widget build(BuildContext context) {
    // ... (Bu fonksiyonun içi tam olarak öncekiyle aynı) ...
     final colorScheme = Theme.of(context).colorScheme;
     final textTheme = Theme.of(context).textTheme;

     if (_isLoading) {
       return Scaffold(
         backgroundColor: colorScheme.background,
         body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
             const CircularProgressIndicator(), const SizedBox(height: 20),
             Text('Sorular Yükleniyor...', style: textTheme.titleMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.7))),
         ])),
       );
     }
     if (_fetchError != null) {
       return Scaffold(
         backgroundColor: colorScheme.background,
         body: Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
             Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 64),
             const SizedBox(height: 20),
             Text('Sorular Yüklenemedi', style: textTheme.titleLarge?.copyWith(color: colorScheme.onBackground), textAlign: TextAlign.center),
             const SizedBox(height: 12),
             Text(_fetchError!, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.7)), textAlign: TextAlign.center),
             const SizedBox(height: 24),
             FilledButton.icon(onPressed: _fetchQuestions, icon: const Icon(Icons.refresh_rounded), label: const Text('Tekrar Dene')),
             const SizedBox(height: 12),
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Geri Dön')),
         ]))),
       );
     }
     if (_questions.isEmpty) {
       return Scaffold(
         backgroundColor: colorScheme.background,
         body: Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
             Icon(Icons.quiz_rounded, color: colorScheme.onBackground.withOpacity(0.5), size: 64),
             const SizedBox(height: 20),
             Text('Soru Bulunamadı', style: textTheme.titleLarge, textAlign: TextAlign.center),
             const SizedBox(height: 12),
             Text('Bu teste ait soru bulunamadı veya henüz eklenmemiş.', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.7)), textAlign: TextAlign.center),
             const SizedBox(height: 24),
             FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Geri Dön')),
         ]))),
       );
     }

     final int actualQuestionCount = _questions.length;
     if (_currentQuestionIndex >= _questions.length) _currentQuestionIndex = _questions.length - 1;
     if (_currentQuestionIndex < 0) _currentQuestionIndex = 0;
     final currentQuestion = _questions[_currentQuestionIndex];
     final questionId = currentQuestion.id;
     final questionData = currentQuestion.data() as Map<String, dynamic>? ?? {};
     final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
     final options = List<String>.from(questionData['secenekler'] ?? []);
     final correctIndex = (questionData['dogruCevapIndex'] as num?)?.toInt() ?? -1;
     final String? imageUrl = questionData['imageUrl'] as String?;
     final bool isAnswered = _answerStatus.containsKey(questionId);
     final int? userAnswerIndex = _selectedAnswers[questionId];
     final bool isTimerTicking = _advanceTimer?.isActive ?? false;
     final bool showNavigationButtons = !_autoAdvanceEnabled || isAnswered || !isTimerTicking;

     return Scaffold(
       backgroundColor: colorScheme.background,
       appBar: AppBar(
         title: Text(widget.quizBaslik, style: TextStyle(color: colorScheme.onBackground, fontWeight: FontWeight.w600)),
         backgroundColor: colorScheme.surface,
         elevation: 0, centerTitle: true,
         leading: IconButton(
           icon: Icon(Icons.close_rounded, color: colorScheme.onBackground),
           onPressed: () { _timer?.cancel(); _advanceTimer?.cancel(); Navigator.pop(context, true); },
         ),
         actions: [
           Tooltip(
              message: _autoAdvanceEnabled ? 'Otomatik İlerleme Açık' : 'Otomatik İlerleme Kapalı',
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: _autoAdvanceEnabled ? colorScheme.primary.withOpacity(0.1) : colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                    Padding(padding: const EdgeInsets.only(left: 12.0),
                      child: Text('Otomatik', style: TextStyle(fontSize: 12, color: _autoAdvanceEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant))),
                    Switch(value: _autoAdvanceEnabled, onChanged: (value) {
                        setState(() { _autoAdvanceEnabled = value; });
                        if (!value) _advanceTimer?.cancel();
                        if (value && isAnswered && !isTimerTicking) {
                          _advanceTimer = Timer(const Duration(seconds: 2), () { if (mounted) _moveToNextOrFinish(); });
                        }
                    }, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ]),
              ),
           ),
         ],
       ),
       body: Column(
         children: [
           Container( // Progress Bar ve Zamanlayıcı
             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
             decoration: BoxDecoration(color: colorScheme.surface, boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
             child: Column(children: [
                 AnimatedBuilder(
                   animation: _progressAnimationController,
                   builder: (context, child) {
                     if (!_animationsInitialized) return Container(height: 8); 
                     return Container(height: 8, decoration: BoxDecoration(color: colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(4)),
                       child: ClipRRect(borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: _progressAnimation.value, backgroundColor: Colors.transparent, valueColor: _progressColorAnimation, minHeight: 8)));
                   },
                 ),
                 const SizedBox(height: 12),
                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                       child: Row(children: [
                           Icon(Icons.quiz_outlined, size: 16, color: colorScheme.primary), const SizedBox(width: 6),
                           Text('${_currentQuestionIndex + 1}/$actualQuestionCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                       ])),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       decoration: BoxDecoration(
                         color: _secondsRemaining < 60 ? colorScheme.errorContainer.withOpacity(0.5) : colorScheme.surfaceVariant,
                         borderRadius: BorderRadius.circular(20),
                         border: Border.all(color: _secondsRemaining < 60 ? colorScheme.error.withOpacity(0.3) : Colors.transparent),
                       ),
                       child: Row(children: [
                           Icon(Icons.timer_outlined, size: 18, color: _secondsRemaining < 60 ? colorScheme.error : colorScheme.onSurfaceVariant), const SizedBox(width: 6),
                           Text(_formattedTime, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _secondsRemaining < 60 ? colorScheme.error : colorScheme.onSurfaceVariant)),
                       ])),
                 ]),
             ]),
           ),
           Expanded( // Soru İçeriği
             child: FadeTransition(
               opacity: _fadeAnimation,
               child: SlideTransition(
                 position: _slideAnimation,
                 child: SingleChildScrollView(
                   padding: const EdgeInsets.all(20.0),
                   physics: const BouncingScrollPhysics(),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       if (imageUrl != null && imageUrl.isNotEmpty)
                         Container(
                           margin: const EdgeInsets.only(bottom: 16),
                           height: MediaQuery.of(context).size.height * 0.25,
                           width: double.infinity,
                           child: ClipRRect(borderRadius: BorderRadius.circular(12.0),
                             child: InteractiveViewer(
                               minScale: 1.0, maxScale: 4.0,
                               child: Image.network(imageUrl, fit: BoxFit.contain,
                                 loadingBuilder: (context, child, loadingProgress) {
                                   if (loadingProgress == null) return child;
                                   return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                                 },
                                 errorBuilder: (context, exception, stackTrace) {
                                   return Container(color: Colors.grey.shade200, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                           Icon(Icons.broken_image_outlined, color: Colors.grey.shade600, size: 40), const SizedBox(height: 8),
                                           Text('Resim yüklenemedi', style: TextStyle(color: Colors.grey.shade600)),
                                   ])));
                                 },
                               ),
                             ),
                           ),
                         ),
                       Card(
                         elevation: 2, margin: const EdgeInsets.only(bottom: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         child: Padding(
                           padding: const EdgeInsets.all(20.0),
                           child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                               Text('Soru ${_currentQuestionIndex + 1}', style: textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                               const SizedBox(height: 12),
                               Text(questionText, style: textTheme.titleLarge?.copyWith(height: 1.4), textAlign: TextAlign.left),
                           ]),
                         ),
                       ),
                       ListView.builder( // Seçenekler
                         shrinkWrap: true,
                         physics: const NeverScrollableScrollPhysics(),
                         itemCount: options.length,
                         itemBuilder: (context, index) {
                           final bool isCorrectOption = index == correctIndex;
                           final bool isSelectedOption = index == userAnswerIndex;
                           final bool isOptionDisabled = isAnswered || correctIndex == -1;
                           Color cardColor = colorScheme.surface;
                           Color borderColor = colorScheme.outline.withOpacity(0.3);
                           Color textColor = colorScheme.onSurface;
                           IconData? trailingIcon;
                           Color? trailingIconColor;

                           if (isAnswered) {
                             if (isCorrectOption) {
                               cardColor = Colors.green.withOpacity(0.1); borderColor = Colors.green; textColor = Colors.green.shade900;
                               trailingIcon = Icons.check_circle_rounded; trailingIconColor = Colors.green;
                             } else if (isSelectedOption) {
                               cardColor = Colors.red.withOpacity(0.1); borderColor = Colors.red; textColor = Colors.red.shade800;
                               trailingIcon = Icons.cancel_rounded; trailingIconColor = Colors.red;
                             } else {
                               cardColor = colorScheme.surfaceVariant.withOpacity(0.8);
                               textColor = colorScheme.onSurfaceVariant.withOpacity(0.7);
                               borderColor = colorScheme.outline.withOpacity(0.1);
                             }
                           }
                           
                           return AnimatedContainer(
                             duration: const Duration(milliseconds: 300),
                             margin: const EdgeInsets.only(bottom: 12),
                             child: Material(
                               color: cardColor,
                               borderRadius: BorderRadius.circular(12),
                               elevation: isAnswered ? (isSelectedOption || isCorrectOption ? 2 : 0) : 1,
                               child: InkWell(
                                 onTap: isOptionDisabled ? null : () => _selectAnswer(questionId, index, correctIndex),
                                 borderRadius: BorderRadius.circular(12),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                   decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.5)),
                                   child: Row(children: [
                                       Container(
                                         width: 32, height: 32,
                                         decoration: BoxDecoration(
                                           color: isOptionDisabled ? (isCorrectOption ? Colors.green.withOpacity(0.1) : colorScheme.onSurface.withOpacity(0.1)) : colorScheme.primary.withOpacity(0.1),
                                           shape: BoxShape.circle,
                                           border: Border.all(color: isOptionDisabled ? (isCorrectOption ? Colors.green.withOpacity(0.3) : Colors.transparent) : colorScheme.primary.withOpacity(0.3))
                                         ),
                                         child: Center(child: Text(String.fromCharCode(65 + index),
                                             style: TextStyle(fontWeight: FontWeight.bold, color: isOptionDisabled ? (isCorrectOption ? Colors.green.shade700 : colorScheme.onSurface.withOpacity(0.5)) : colorScheme.primary))),
                                       ),
                                       const SizedBox(width: 16),
                                       Expanded(child: Text(options[index], style: TextStyle(fontSize: 16, height: 1.4, color: textColor), maxLines: 3, overflow: TextOverflow.ellipsis)),
                                       if (trailingIcon != null) ...[const SizedBox(width: 12), Icon(trailingIcon, color: trailingIconColor, size: 20)],
                                   ]),
                                 ),
                               ),
                             ),
                           );
                         },
                       ),
                       Container( // Navigasyon Butonları
                         padding: const EdgeInsets.only(top: 16, bottom: 20),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             AnimatedOpacity(
                               opacity: _currentQuestionIndex > 0 ? 1.0 : 0.0,
                               duration: const Duration(milliseconds: 300),
                               child: IgnorePointer(
                                 ignoring: _currentQuestionIndex == 0,
                                 child: FilledButton.tonal(
                                   onPressed: _previousQuestion,
                                   style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                   child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_back_ios_rounded, size: 16), SizedBox(width: 8), Text('Önceki')]),
                                 ),
                               ),
                             ),
                             if (showNavigationButtons)
                               _currentQuestionIndex == _questions.length - 1
                                   ? FilledButton(
                                       onPressed: (isAnswered && !_isSubmitting) ? _submitQuiz : null,
                                       style: FilledButton.styleFrom(
                                         backgroundColor: Colors.green, foregroundColor: Colors.white,
                                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                         disabledBackgroundColor: Colors.green.withOpacity(0.3),
                                       ),
                                       child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                           : const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_rounded, size: 18), SizedBox(width: 8), Text('Testi Bitir')]),
                                     )
                                   : FilledButton(
                                       onPressed: isAnswered ? _nextQuestion : null,
                                       style: FilledButton.styleFrom(
                                         backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary,
                                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                       ),
                                       child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Sonraki'), SizedBox(width: 8), Icon(Icons.arrow_forward_ios_rounded, size: 16)]),
                                     )
                             else
                               const SizedBox(width: 120),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
           ),
         ],
       ),
     );
  }
}