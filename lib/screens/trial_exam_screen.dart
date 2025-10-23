import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/screens/result_screen.dart'; // Normal sonuç ekranını kullanabiliriz
import 'package:bilgi_yarismasi/services/auth_service.dart';

class TrialExamScreen extends StatefulWidget {
  final String trialExamId;
  final String title;
  final int durationMinutes;
  final int questionCount;

  const TrialExamScreen({
    super.key,
    required this.trialExamId,
    required this.title,
    required this.durationMinutes,
    required this.questionCount,
  });

  @override
  State<TrialExamScreen> createState() => _TrialExamScreenState();
}

class _TrialExamScreenState extends State<TrialExamScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<DocumentSnapshot> _questions = [];
  int _currentQuestionIndex = 0;
  Map<String, int> _selectedAnswers = {};
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
    _startTimer();
  }

  Future<void> _fetchQuestions() async {
    if (!mounted) return;
    try {
      final snapshot = await _firestore
          .collection('questions')
          .where('trialExamId', isEqualTo: widget.trialExamId)
          .get();
      if (mounted) {
        var fetchedQuestions = snapshot.docs;
        fetchedQuestions.shuffle();
        _questions = fetchedQuestions.take(widget.questionCount).toList();
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Deneme sınavı soruları çekilirken hata: $e");
      if (mounted) setState(() => _isLoading = false);
      // TODO: Hata yönetimi (fetchError state'i) eklenebilir
    }
  }

  void _startTimer() {
    _secondsRemaining = widget.durationMinutes * 60;
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
          if (!_isSubmitting) _submitTrialExam();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectAnswer(String questionId, int selectedIndex) {
    setState(() => _selectedAnswers[questionId] = selectedIndex);
  }

  Future<void> _submitTrialExam() async {
    _timer?.cancel();
    if (_isSubmitting || !mounted) return;
    setState(() => _isSubmitting = true);

    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    try {
      final resultDocRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trialExamResults')
          .doc(widget.trialExamId);

      final resultDoc = await resultDocRef.get();
      if (resultDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu deneme sınavını zaten çözdünüz.')),
          );
          Navigator.pop(context);
        }
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      int correctAnswers = 0;
      int wrongAnswers = 0;
      int actualQuestionCount = _questions.length;
      for (var question in _questions) {
        final questionId = question.id;
        final correctIndex =
            (question['dogruCevapIndex'] as num?)?.toInt() ?? -1;
        if (_selectedAnswers.containsKey(questionId) &&
            _selectedAnswers[questionId] == correctIndex) {
          correctAnswers++;
        } else {
          wrongAnswers++;
        }
      }
      int score = (correctAnswers * 100) + (_secondsRemaining * 5);

      // Kullanıcı adını ve emojisini asıl user belgesinden al
      String kullaniciAdi = "Kullanıcı";
      String emoji = "🙂";
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        kullaniciAdi = userDoc.data()?['kullaniciAdi'] ?? kullaniciAdi;
        emoji = userDoc.data()?['emoji'] ?? emoji;
      }

      // 3. Sonucu trialExamResults'a kaydet
      Map<String, dynamic> resultData = {
        'trialExamId': widget.trialExamId,
        'title': widget.title,
        'score': score,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'totalQuestions': actualQuestionCount,
        'completionTime': FieldValue.serverTimestamp(),
        'timeSpentSeconds': (widget.durationMinutes * 60) - _secondsRemaining,
        'kullaniciAdi': kullaniciAdi,
        'emoji': emoji,
        'userId': user.uid,
      };
      await resultDocRef.set(resultData);

      // --- DEĞİŞİKLİK: 'toplamPuan' GÜNCELLEMESİ KALDIRILDI ---
      // 4. Kullanıcının genel toplamPuan'ını GÜNCELLEME
      // final userDocRef = _firestore.collection('users').doc(user.uid);
      // await userDocRef.set({'toplamPuan': FieldValue.increment(score)}, SetOptions(merge: true));
      // --- DEĞİŞİKLİK BİTTİ ---

      // 5. Sonuç Ekranına Git
      if (mounted) {
        final resultFromScreen = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              puan: score,
              dogruSayisi: correctAnswers,
              soruSayisi: actualQuestionCount,
              fromHistory: false,
            ),
          ),
        );
        if (mounted) {
          Navigator.pop(context, true); // Listeyi yenilemek için 'true' döndür
        }
      }
    } catch (e) {
      print("Deneme sınavı sonucu kaydedilirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Sınav sonucu kaydedilemedi. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  void _previousQuestion() {
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
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('Bu deneme sınavına ait soru bulunamadı.'),
        ),
      );
    }
    if (_questions.length != widget.questionCount) {
      print(
        "Uyarı: Beklenen soru sayısı (${widget.questionCount}) ile bulunan (${_questions.length}) farklı!",
      );
    }

    final int actualQuestionCount = _questions.length;
    final currentQuestion = _questions[_currentQuestionIndex];
    final questionId = currentQuestion.id;
    final questionData = currentQuestion.data() as Map<String, dynamic>? ?? {};
    final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
    final options = List<String>.from(questionData['secenekler'] ?? []);
    // (Resim URL'si desteği bu kodda yoktu, istenirse QuizScreen'den eklenebilir)

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              label: Text(
                _formattedTime,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              avatar: Icon(
                Icons.timer,
                color: _secondsRemaining < 60 ? Colors.red : Colors.black,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Soru ${_currentQuestionIndex + 1} / $actualQuestionCount',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  questionText,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: _selectedAnswers[questionId] == index
                        ? Colors.blue.shade100
                        : null,
                    child: RadioListTile<int>(
                      title: Text(options[index]),
                      value: index,
                      groupValue: _selectedAnswers[questionId],
                      onChanged: (value) {
                        if (value != null) _selectAnswer(questionId, value);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentQuestionIndex > 0)
                    ElevatedButton.icon(
                      onPressed: _previousQuestion,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Önceki'),
                    )
                  else
                    const SizedBox(width: 100),
                  _currentQuestionIndex == _questions.length - 1
                      ? ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitTrialExam,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(_isSubmitting ? '...' : 'Sınavı Bitir'),
                        )
                      : ElevatedButton.icon(
                          onPressed: _nextQuestion,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Sonraki'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
