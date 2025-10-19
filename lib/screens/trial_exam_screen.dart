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

  // Deneme sınavına ait soruları çek (trialExamId'ye göre)
  Future<void> _fetchQuestions() async {
    if (!mounted) return;
    try {
      final snapshot = await _firestore
          .collection('questions')
          .where('trialExamId', isEqualTo: widget.trialExamId)
          .get();
      if (mounted) {
        // Soruları çekince karıştıralım ki her seferinde farklı sırada gelsin
        var fetchedQuestions = snapshot.docs;
        fetchedQuestions.shuffle();

        setState(() {
          // Belirtilen soru sayısı kadarını alalım (eğer fazlaysa)
          _questions = fetchedQuestions.take(widget.questionCount).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Deneme sınavı soruları çekilirken hata: $e");
      if (mounted) setState(() => _isLoading = false);
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
          _submitTrialExam();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sonucu kaydetmek için giriş yapmalısınız.'),
          ),
        );
      }
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    try {
      // 1. Tekrar çözme kontrolü
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
          Navigator.pop(context); // Listeye geri dön
        }
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      // 2. Puan Hesaplama
      int correctAnswers = 0;
      int wrongAnswers = 0;
      // Soru listesini widget.questionCount'a göre değil, _questions.length'e göre dolaşalım
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
      // Puanı sadece doğru sayısına göre mi verelim, yoksa süre de etkili olsun mu?
      // Şimdilik sadece doğru * 100 yapalım denemeler için:
      int score = (correctAnswers * 100);
      // Veya süre bonuslu: int score = (correctAnswers * 100) + (_secondsRemaining * 5);

      // 3. Sonucu trialExamResults'a kaydet
      Map<String, dynamic> resultData = {
        'title': widget.title,
        'score': score,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'totalQuestions': actualQuestionCount, // Gerçek soru sayısını kaydet
        'completionTime': FieldValue.serverTimestamp(),
        'timeSpentSeconds': (widget.durationMinutes * 60) - _secondsRemaining,
      };
      await resultDocRef.set(resultData);

      // 4. Kullanıcının genel toplamPuan'ını güncelle
      final userDocRef = _firestore.collection('users').doc(user.uid);
      await userDocRef.set({
        'toplamPuan': FieldValue.increment(score),
      }, SetOptions(merge: true));

      // 5. Sonuç Ekranına Git
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              puan: score,
              dogruSayisi: correctAnswers,
              soruSayisi: actualQuestionCount, // Gerçek soru sayısını gönder
              fromHistory: false,
            ),
          ),
        ).then((_) {
          // ResultScreen kapandıktan sonra liste ekranına 'true' gönder
          if (mounted) Navigator.pop(context, true);
        });
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
        body: Center(
          child: Padding(
            // Biraz boşluk
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Bu deneme sınavına ait soru bulunamadı veya yüklenirken bir hata oluştu.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    // Gerçek soru sayısını alalım
    final int actualQuestionCount = _questions.length;

    // Soru sayısı tutarsızsa uyarı verelim ama devam edelim
    if (actualQuestionCount != widget.questionCount) {
      print(
        "Uyarı: Beklenen soru sayısı (${widget.questionCount}) ile bulunan ($actualQuestionCount) farklı!",
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final questionId = currentQuestion.id;
    final questionData = currentQuestion.data() as Map<String, dynamic>? ?? {};
    final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
    final options = List<String>.from(questionData['secenekler'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        // --- AppBar actions (Zamanlayıcı) EKLENDİ ---
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              label: Text(
                _formattedTime,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              avatar: Icon(
                Icons.timer_outlined, // İkon değiştirildi
                color: _secondsRemaining < 60
                    ? Colors.red.shade700
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant, // Renk ayarlandı
                size: 18, // Boyut ayarlandı
              ),
              backgroundColor: _secondsRemaining < 60
                  ? Colors.red.shade100.withOpacity(0.5)
                  : Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.5), // Arka plan
              side: BorderSide.none, // Kenarlık kaldırıldı
            ),
          ),
        ],
        // --- AppBar actions BİTTİ ---
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              // Gerçek soru sayısı kullanıldı
              'Soru ${_currentQuestionIndex + 1} / $actualQuestionCount',
              style: Theme.of(context).textTheme.titleMedium, // Stil ayarlandı
            ),
            const Divider(height: 20),
            // --- Expanded child (Soru Metni) EKLENDİ ---
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  questionText,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall, // Stil ayarlandı
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // --- Expanded child BİTTİ ---
            const SizedBox(height: 20),
            // --- Seçenekler ListView EKLENDİ ---
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: _selectedAnswers[questionId] == index
                        ? 2
                        : 1, // Seçiliyse hafif gölge
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                    ), // Dikey boşluk
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ), // Yuvarlak köşe
                    color: _selectedAnswers[questionId] == index
                        ? Theme.of(context).colorScheme.primaryContainer
                              .withOpacity(0.7) // Tema rengi
                        : Theme.of(context).cardColor,
                    child: RadioListTile<int>(
                      title: Text(options[index]),
                      value: index,
                      groupValue: _selectedAnswers[questionId],
                      onChanged: (value) {
                        if (value != null) {
                          _selectAnswer(questionId, value);
                        }
                      },
                      activeColor: Theme.of(
                        context,
                      ).colorScheme.primary, // Seçili radio rengi
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ), // İç boşluk
                    ),
                  );
                },
              ),
            ),
            // --- Seçenekler BİTTİ ---
            // --- Navigasyon Butonları EKLENDİ ---
            Padding(
              padding: const EdgeInsets.only(top: 16.0), // Padding artırıldı
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentQuestionIndex > 0)
                    ElevatedButton.icon(
                      onPressed: _previousQuestion,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                      ), // İkon değiştirildi
                      label: const Text('Önceki'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ), // Padding
                      ),
                    )
                  else
                    // Boşluk bırakmak için Opacity widget'ı (yer kaplar ama görünmez)
                    Opacity(
                      opacity: 0,
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.arrow_back),
                        label: Text('Önceki'),
                      ),
                    ),

                  // Sonraki Soru veya Sınavı Bitir Butonu
                  _currentQuestionIndex == _questions.length - 1
                      ? ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitTrialExam,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.green.shade600, // Renk koyulaştırıldı
                            foregroundColor: Colors.white, // Yazı rengi
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ), // Padding
                          ),
                          icon: _isSubmitting
                              ? Container(
                                  // Progress indicator boyutu
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
                                ), // İkon değiştirildi
                          label: Text(_isSubmitting ? '...' : 'Sınavı Bitir'),
                        )
                      : ElevatedButton.icon(
                          onPressed: _nextQuestion,
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ), // İkon değiştirildi
                          label: const Text('Sonraki'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ), // Padding
                          ),
                        ),
                ],
              ),
            ),
            // --- Navigasyon Butonları BİTTİ ---
          ],
        ),
      ),
    );
  }
}
