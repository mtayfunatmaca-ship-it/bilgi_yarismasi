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
  Map<String, int> _selectedAnswers = {}; // Kullanıcının seçtiği index'i tutar
  Timer? _timer; // Ana süre sayacı
  int _secondsRemaining = 0;
  List<QueryDocumentSnapshot> _achievementDefinitions = []; // Başarı tanımları
  String? _fetchError; // Soru yükleme hatasını tutmak için state

  // --- YENİ STATE'LER ---
  // Key: questionId, Value: true (doğru), false (yanlış), null (cevaplanmadı)
  Map<String, bool?> _answerStatus = {};
  // Otomatik sonraki soruya geçiş aktif mi?
  bool _autoAdvanceEnabled = true; // Varsayılan olarak açık
  // Otomatik geçiş için kullanılan timer
  Timer? _advanceTimer;
  // --- YENİ STATE'LER BİTTİ ---

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
    }); // Yüklemeye başla
    try {
      final snapshot = await _firestore
          .collection('questions')
          .where('quizId', isEqualTo: widget.quizId)
          .get();
      if (mounted) {
        var fetchedQuestions = snapshot.docs;
        fetchedQuestions.shuffle(); // Soruları karıştır

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
    _timer?.cancel(); // Önceki timer varsa durdur
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
          // Süre bittiğinde submit fonksiyonunu doğrudan çağırmadan önce
          // kullanıcıya bir uyarı vermek daha iyi olabilir.
          // Şimdilik doğrudan çağıralım:
          if (!_isSubmitting) {
            // Zaten submit oluyorsa tekrar çağırma
            _submitQuiz();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _advanceTimer?.cancel(); // <<< Otomatik geçiş timer'ını da iptal et
    super.dispose();
  }

  // CEVAP SEÇME MANTIĞI GÜNCELLENDİ
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

  // YENİ YARDIMCI FONKSİYON: Sonraki soruya geç veya bitir
  void _moveToNextOrFinish() {
    _advanceTimer?.cancel();
    if (_currentQuestionIndex < _questions.length - 1) {
      _nextQuestion();
    } else {
      _submitQuiz();
    }
  }

  // Testi bitirme ve kaydetme (Başarı kontrolü içerir)
  Future<void> _submitQuiz() async {
    _timer?.cancel();
    _advanceTimer?.cancel(); // Geçiş timer'ını da iptal et
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
    _advanceTimer?.cancel(); // Manuel geçişte timer'ı iptal et
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  // Önceki soru
  void _previousQuestion() {
    _advanceTimer?.cancel(); // Manuel geçişte timer'ı iptal et
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

  // === build METODU (Hata Yönetimi ve Anında Geri Bildirim Dahil) ===
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
    final correctIndex =
        (questionData['dogruCevapIndex'] as num?)?.toInt() ?? -1;
    final bool? answerCorrectness = _answerStatus[questionId];
    final bool isAnswered = answerCorrectness != null;
    final int? userAnswerIndex = _selectedAnswers[questionId];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizBaslik),
        actions: [
          // Otomatik Geçiş Switch'i
          Tooltip(
            message: _autoAdvanceEnabled
                ? 'Otomatik İlerleme Açık'
                : 'Otomatik İlerleme Kapalı',
            child: Switch(
              value: _autoAdvanceEnabled,
              onChanged: (value) {
                setState(() {
                  _autoAdvanceEnabled = value;
                });
                if (!value) _advanceTimer?.cancel();
              },
              activeColor: Colors.white, // AppBar'a uygun
              activeTrackColor: Colors.white.withOpacity(0.5),
            ),
          ),
          // Zamanlayıcı Chip
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
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
            // Seçenekler (Geri Bildirimli)
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final bool isCorrectOption = index == correctIndex;
                  final bool isSelectedOption = index == userAnswerIndex;
                  Color cardColor = Theme.of(context).cardColor;
                  Color borderColor = Theme.of(
                    context,
                  ).dividerColor.withOpacity(0.5);
                  double elevation = 1;
                  Icon? trailingIcon;

                  if (isAnswered) {
                    if (isCorrectOption) {
                      cardColor = Colors.green.shade50;
                      borderColor = Colors.green.shade300;
                      elevation = 2;
                      trailingIcon = Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade700,
                      ); // İkon değişti
                    } else if (isSelectedOption) {
                      cardColor = Colors.red.shade50;
                      borderColor = Colors.red.shade300;
                      elevation = 2;
                      trailingIcon = Icon(
                        Icons.cancel_rounded,
                        color: Colors.red.shade700,
                      ); // İkon değişti
                    } else {
                      cardColor = Colors.grey.shade100.withOpacity(0.5);
                      borderColor = Colors.grey.shade300.withOpacity(0.5);
                      elevation = 0;
                    }
                  }

                  return Card(
                    elevation: elevation,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: borderColor,
                        width: isAnswered ? 1.5 : 1,
                      ),
                    ),
                    color: cardColor,
                    child: RadioListTile<int>(
                      title: Text(
                        options[index],
                        style: TextStyle(
                          color:
                              (isAnswered &&
                                  !isSelectedOption &&
                                  !isCorrectOption)
                              ? Colors.grey.shade600
                              : null,
                        ),
                      ),
                      value: index,
                      groupValue: userAnswerIndex,
                      // Cevaplanmışsa null yap
                      onChanged: (isAnswered || correctIndex == -1)
                          ? null
                          : (value) {
                              // correctIndex -1 ise de disable
                              if (value != null)
                                _selectAnswer(questionId, value, correctIndex);
                            },
                      activeColor: Theme.of(context).colorScheme.primary,
                      secondary: trailingIcon, // Geri bildirim ikonu
                      controlAffinity:
                          ListTileControlAffinity.trailing, // Radio'yu sağa al
                      contentPadding: const EdgeInsets.only(
                        left: 16,
                        right: 8,
                        top: 4,
                        bottom: 4,
                      ), // Padding ayarlandı
                    ),
                  );
                },
              ),
            ),
            // Navigasyon Butonları (Güncellendi)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Önceki Buton
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

                  // Sonraki / Bitir Butonu
                  // Otomatik geçiş kapalıysa VEYA soru henüz cevaplanmamışsa göster
                  if (!_autoAdvanceEnabled || !isAnswered)
                    _currentQuestionIndex == _questions.length - 1
                        ? ElevatedButton.icon(
                            // Testi Bitir
                            onPressed: (isAnswered && !_isSubmitting)
                                ? _submitQuiz
                                : null, // Cevaplanmışsa aktif
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              disabledBackgroundColor: Colors.green.shade200,
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
                            // Sonraki Soru
                            onPressed: isAnswered
                                ? _nextQuestion
                                : null, // Cevaplanmışsa aktif
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
                              disabledBackgroundColor: Colors.grey.shade300,
                            ),
                          )
                  // Otomatik geçiş açıksa VE soru cevaplanmışsa, boşluk bırak
                  else
                    const SizedBox(width: 100), // Buton kadar yer kaplasın
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} // _QuizScreenState sonu
