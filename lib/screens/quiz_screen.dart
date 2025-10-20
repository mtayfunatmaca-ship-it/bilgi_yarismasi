import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/screens/result_screen.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class QuizScreen extends StatefulWidget {
  final String quizId;
  final String quizBaslik;
  final int soruSayisi; // JSON'dan gelen beklenen sayı
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

class _QuizScreenState extends State<QuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  bool _isLoading = true; // Veri yükleniyor mu?
  bool _isSubmitting = false; // Sonuç kaydediliyor mu?
  List<DocumentSnapshot> _questions = []; // Yüklenen sorular
  int _currentQuestionIndex = 0;
  Map<String, int> _selectedAnswers = {};
  Timer? _timer;
  int _secondsRemaining = 0;
  List<QueryDocumentSnapshot> _achievementDefinitions = []; // Başarı tanımları
  String? _fetchError; // <<< SORU YÜKLEME HATASINI TUTMAK İÇİN STATE

  @override
  void initState() {
    super.initState();
    _fetchQuestions(); // Başlangıçta soruları yükle
    _loadAchievementDefinitions();
  }

  // Başarı tanımlarını Firestore'dan çeker
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

  // Soruları Firestore'dan çeker (Hata yönetimi ve Timer başlatma güncellendi)
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
          // Sorular başarıyla yüklendikten SONRA Timer'ı başlat
          if (_questions.isNotEmpty) {
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
          _fetchError = errorMsg; // Hata mesajını state'e kaydet
        });
      }
    }
  }

  // Timer'ı başlatır
  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = widget.sureDakika * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          if (!_isSubmitting) _submitQuiz();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Cevap seçme
  void _selectAnswer(String questionId, int selectedIndex) {
    setState(() => _selectedAnswers[questionId] = selectedIndex);
  }

  // Testi bitirme ve kaydetme (Başarı kontrolü içerir)
  Future<void> _submitQuiz() async {
    _timer?.cancel();
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
      // Puan koruması
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

      // Puan hesaplama
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

      // 1. KAYIT: Çözülen test belgesi
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

      // 2. KAYIT: Toplam puan
      final userDocRef = _firestore.collection('users').doc(user.uid);
      await userDocRef.set({
        'toplamPuan': FieldValue.increment(puan),
      }, SetOptions(merge: true));

      // BAŞARI KONTROLÜ
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

      // Sonuç Ekranına Git
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

  // Başarıları kontrol etme ve kazandırma
  Future<void> _checkAndGrantAchievements({
    required String userId,
    required int solvedCount,
    required int totalScore,
  }) async {
    if (_achievementDefinitions.isEmpty || !mounted) return;
    try {
      final earnedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('earnedAchievements')
          .get();
      final earnedAchievementIds = earnedSnapshot.docs
          .map((doc) => doc.id)
          .toSet();
      WriteBatch? batch;
      List<Map<String, dynamic>> newlyEarnedAchievements = [];

      for (var achievementDoc in _achievementDefinitions) {
        final achievementId = achievementDoc.id;
        if (earnedAchievementIds.contains(achievementId)) continue;
        final achievementData = achievementDoc.data() as Map<String, dynamic>?;
        if (achievementData == null) continue;

        final criteriaType = achievementData['criteria_type'] as String?;
        final criteriaValue =
            (achievementData['criteria_value'] as num?)?.toInt() ?? 0;
        final achievementName =
            achievementData['name'] as String? ?? 'İsimsiz Başarı';
        final achievementEmoji = achievementData['emoji'] as String? ?? '🏆';
        final achievementDescription =
            achievementData['description'] as String? ?? '';

        bool earned = false;
        if (criteriaType == 'solved_count' && solvedCount >= criteriaValue)
          earned = true;
        else if (criteriaType == 'total_score' && totalScore >= criteriaValue)
          earned = true;

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
            'emoji': achievementEmoji,
          });
          newlyEarnedAchievements.add({
            'name': achievementName,
            'emoji': achievementEmoji,
            'description': achievementDescription,
          });
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
    } catch (e) {
      print("Başarı kontrolü sırasında hata: $e");
    }
  }

  // Başarı kazanıldı popup'ı
  void _showAchievementEarnedDialog(Map<String, dynamic> achievementData) {
    if (!mounted) return;
    final emoji = achievementData['emoji'] as String? ?? '🏆';
    final name = achievementData['name'] as String? ?? 'Başarı';
    final description = achievementData['description'] as String? ?? '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              const Text("Yeni Başarı!"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(description),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Harika!"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // Sonraki soru
  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  // Önceki soru
  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  // Zaman formatlama
  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // === build METODU (Hata Yönetimi Dahil) ===
  @override
  Widget build(BuildContext context) {
    // 1. YÜKLENİYOR DURUMU
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizBaslik)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 2. HATA DURUMU
    if (_fetchError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizBaslik)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.grey,
                  size: 60,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Sorular Yüklenemedi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _fetchError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                  onPressed: _fetchQuestions,
                ),
                TextButton(
                  child: const Text('Geri Dön'),
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. SORU YOK DURUMU
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizBaslik)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  color: Colors.grey,
                  size: 60,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Soru Bulunamadı',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Bu teste ait soru bulunamadı veya henüz eklenmemiş.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextButton(
                  child: const Text('Geri Dön'),
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 4. SORULAR VARSA NORMAL EKRAN
    final int actualQuestionCount = _questions.length;
    if (actualQuestionCount != widget.soruSayisi && widget.soruSayisi > 0) {
      print(
        "Uyarı: Beklenen soru sayısı (${widget.soruSayisi}) ile bulunan ($actualQuestionCount) farklı!",
      );
    }

    // Index kontrolü
    if (_currentQuestionIndex >= _questions.length)
      _currentQuestionIndex = _questions.length - 1;
    if (_currentQuestionIndex < 0) _currentQuestionIndex = 0;

    final currentQuestion = _questions[_currentQuestionIndex];
    final questionId = currentQuestion.id;
    final questionData = currentQuestion.data() as Map<String, dynamic>? ?? {};
    final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
    final options = List<String>.from(questionData['secenekler'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizBaslik),
        actions: [
          Padding(
            // Zamanlayıcı Chip
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              label: Text(
                _formattedTime,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              avatar: Icon(
                Icons.timer_outlined,
                color: _secondsRemaining < 60
                    ? Colors.red.shade700
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18,
              ),
              backgroundColor: _secondsRemaining < 60
                  ? Colors.red.shade100.withOpacity(0.5)
                  : Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.5),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Soru Sayacı
            Text(
              'Soru ${_currentQuestionIndex + 1} / $actualQuestionCount',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 20),
            // Soru Metni
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  questionText,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Seçenekler
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: _selectedAnswers[questionId] == index ? 2 : 1,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: _selectedAnswers[questionId] == index
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withOpacity(0.7)
                        : Theme.of(context).cardColor,
                    child: RadioListTile<int>(
                      title: Text(options[index]),
                      value: index,
                      groupValue: _selectedAnswers[questionId],
                      onChanged: (value) {
                        if (value != null) _selectAnswer(questionId, value);
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Navigasyon Butonları
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Opacity(
                    opacity: _currentQuestionIndex > 0 ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: _currentQuestionIndex == 0,
                      child: ElevatedButton.icon(
                        onPressed: _previousQuestion,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                        ),
                        label: const Text('Önceki'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _currentQuestionIndex == _questions.length - 1
                      ? ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitQuiz,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          icon: _isSubmitting
                              ? Container(
                                  width: 18,
                                  height: 18,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                ),
                          label: Text(_isSubmitting ? '...' : 'Testi Bitir'),
                        )
                      : ElevatedButton.icon(
                          onPressed: _nextQuestion,
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
                          label: const Text('Sonraki'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
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
} // _QuizScreenState sonu
