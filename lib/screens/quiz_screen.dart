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

  const QuizScreen({
    super.key,
    required this.quizId,
    required this.quizBaslik,
    required this.soruSayisi,
    required this.sureDakika,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
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
    try {
      final snapshot = await _firestore
          .collection('questions')
          .where('quizId', isEqualTo: widget.quizId)
          .get();

      setState(() {
        _questions = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print("Soruları çekerken hata: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _secondsRemaining = widget.sureDakika * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _submitQuiz();
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
    setState(() {
      _selectedAnswers[questionId] = selectedIndex;
    });
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puanı kaydetmek için giriş yapmalısınız.'),
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    try {
      // PUAN KORUMASI KONTROLÜ
      final solvedDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('solvedQuizzes')
          .doc(widget.quizId)
          .get();

      if (solvedDoc.exists) {
        // TEST ZATEN ÇÖZÜLMÜŞ!
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                fromHistory: true, // Geçmiş sonucu göster
                solvedData: solvedDoc.data(), // Mevcut sonucu yolla
              ),
            ),
          );
        }
        return; // Fonksiyondan çık, puan kaydetme
      }

      // (Test daha önce çözülmemiş, normal devam et)
      int dogruSayisi = 0;
      int yanlisSayisi = 0;
      for (var question in _questions) {
        final questionId = question.id;
        final correctIndex = question['dogruCevapIndex'];

        if (_selectedAnswers.containsKey(questionId) &&
            _selectedAnswers[questionId] == correctIndex) {
          dogruSayisi++;
        } else {
          yanlisSayisi++;
        }
      }
      int puan = (dogruSayisi * 100) + (_secondsRemaining * 5);

      // 1. KAYIT: Çözülen testin belgesini oluştur
      Map<String, dynamic> newSolvedData = {
        'puan': puan,
        'tarih': FieldValue.serverTimestamp(),
        'dogruSayisi': dogruSayisi,
        'yanlisSayisi': yanlisSayisi,
        'harcananSureSn': (widget.sureDakika * 60) - _secondsRemaining,
      };
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('solvedQuizzes')
          .doc(widget.quizId)
          .set(newSolvedData);

      // 2. KAYIT: Kullanıcının toplam puanını güncelle
      await _firestore.collection('users').doc(user.uid).set({
        'toplamPuan': FieldValue.increment(puan),
      }, SetOptions(merge: true));

      // Kayıt başarılı, Sonuç Ekranına Git
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              quizId: widget.quizId,
              puan: puan,
              dogruSayisi: dogruSayisi,
              soruSayisi: widget.soruSayisi,
              fromHistory: false, // Yeni çözüldü
            ),
          ),
        );
      }
    } catch (e) {
      print("Sonuçları kaydederken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Puanınız kaydedilemedi. $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
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
        appBar: AppBar(title: Text(widget.quizBaslik)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizBaslik)),
        body: const Center(child: Text('Bu teste ait soru bulunamadı.')),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final questionId = currentQuestion.id;
    final questionData = currentQuestion.data() as Map<String, dynamic>;
    final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
    final options = List<String>.from(questionData['secenekler'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizBaslik),
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
              'Soru ${_currentQuestionIndex + 1} / ${widget.soruSayisi}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(height: 20),

            Text(questionText, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),

            Expanded(
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
                        if (value != null) {
                          _selectAnswer(questionId, value);
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentQuestionIndex > 0)
                  ElevatedButton(
                    onPressed: _previousQuestion,
                    child: const Text('Önceki'),
                  )
                else
                  Container(),

                _currentQuestionIndex == _questions.length - 1
                    ? ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitQuiz,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Testi Bitir'),
                      )
                    : ElevatedButton(
                        onPressed: _nextQuestion,
                        child: const Text('Sonraki'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
