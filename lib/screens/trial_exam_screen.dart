import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/screens/result_screen.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Grid ikonu için

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

  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<int, int> _selectedAnswers = {};
  final Map<int, int> _correctAnswers = {};
  String? _fetchError;

  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
    // _startTimer(), _fetchQuestions içinde çağrılıyor
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
        // Gelen soru sayısı > istenen ise al, değilse geleni al
        _questions = fetchedQuestions.take(widget.questionCount).toList();

        for (int i = 0; i < _questions.length; i++) {
          final data = _questions[i].data() as Map<String, dynamic>? ?? {};
          _correctAnswers[i] = (data['dogruCevapIndex'] as num?)?.toInt() ?? -1;
        }

        setState(() {
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      print("Deneme sınavı soruları çekilirken hata: $e");
      if (mounted)
        setState(() {
          _isLoading = false;
          _fetchError = "Sorular yüklenemedi: $e";
        });
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
          if (!_isSubmitting) _submitTrialExam(isTimeUp: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _selectAnswer(int questionIndex, int selectedIndex) {
    setState(() {
      _selectedAnswers[questionIndex] = selectedIndex;
    });
  }

  Future<void> _submitTrialExam({
    bool isForfeit = false,
    bool isTimeUp = false,
  }) async {
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
      if (resultDoc.exists && !isForfeit) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu deneme sınavını zaten çözdünüz.')),
          );
        if (mounted) Navigator.pop(context);
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      int correctAnswers = 0;
      int wrongAnswers = 0;
      int actualQuestionCount = _questions.length;

      if (isForfeit) {
        wrongAnswers = actualQuestionCount;
      } else {
        for (int i = 0; i < actualQuestionCount; i++) {
          int? correctIndex = _correctAnswers[i];
          int? selectedIndex = _selectedAnswers[i];
          if (selectedIndex != null && selectedIndex == correctIndex) {
            correctAnswers++;
          } else {
            wrongAnswers++;
          }
        }
      }

      int score = (correctAnswers * 100);
      if (!isTimeUp && !isForfeit) {
        score += (_secondsRemaining * 5);
      }

      String kullaniciAdi = "Kullanıcı";
      String emoji = "🙂";
      String ad = "";
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        kullaniciAdi = userDoc.data()?['kullaniciAdi'] ?? kullaniciAdi;
        ad = userDoc.data()?['ad'] ?? ''; // Adı al
        emoji = userDoc.data()?['emoji'] ?? emoji;
      }

      Map<String, dynamic> resultData = {
        'trialExamId': widget.trialExamId,
        'title': widget.title,
        'score': score,
        'correctAnswers': correctAnswers, 'wrongAnswers': wrongAnswers,
        'totalQuestions': actualQuestionCount,
        'completionTime': FieldValue.serverTimestamp(),
        'timeSpentSeconds': (widget.durationMinutes * 60) - _secondsRemaining,
        'kullaniciAdi': ad.isNotEmpty
            ? ad
            : kullaniciAdi, // Ad varsa onu, yoksa kullanıcı adını
        'emoji': emoji, 'userId': user.uid,
      };
      await resultDocRef.set(resultData);

      if (mounted) {
        if (isForfeit) {
          Navigator.pop(context, true);
        } else {
          final resultFromScreen = await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                puan: score,
                dogruSayisi: correctAnswers,
                soruSayisi: actualQuestionCount,
                fromHistory: false,
                questions: _questions,
                userAnswers: _selectedAnswers,
                correctAnswers: _correctAnswers,
              ),
            ),
          );

          if (mounted) {
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      print("Deneme sınavı sonucu kaydedilirken hata: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Sınav sonucu kaydedilemedi. $e')),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (_isSubmitting) return false;

    final bool? shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sınavdan Çıkmak Üzeresiniz'),
        content: const Text(
          'Şimdi çıkarsanız bu sınava tekrar giremezsiniz ve 0 puan alırsınız. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sınavdan Çık'),
          ),
        ],
      ),
    );

    if (shouldPop == true) {
      await _submitTrialExam(isForfeit: true);
      return true;
    }

    return false;
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // === build METODU (Değişiklik yapıldı) ===
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Chip(
                label: Text(
                  _formattedTime,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                avatar: Icon(
                  Icons.timer_outlined,
                  color: _secondsRemaining < 60
                      ? Colors.red
                      : colorScheme.onSurfaceVariant,
                ),
                backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _fetchError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_fetchError!),
                ),
              )
            : Column(
                children: [
                  // --- 1. DEĞİŞİKLİK: Soru Grid'i yerine Yeni Navigasyon Başlığı ---
                  _buildNavigationHeader(colorScheme, textTheme),

                  // --- DEĞİŞİKLİK BİTTİ ---
                  const Divider(height: 1),

                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _questions.length,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemBuilder: (context, index) {
                        return _buildQuestionPage(_questions[index], index);
                      },
                    ),
                  ),
                  _buildNavigationControls(colorScheme, textTheme),
                ],
              ),
      ),
    );
  }
  // === build METODU SONU ===

  // --- 2. DEĞİŞİKLİK: Soru Kutucukları (Grid) yerine Yeni Navigasyon Başlığı ---
  Widget _buildNavigationHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.95), // Hafif yarı şeffaf
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Soru Numarası
          Chip(
            label: Text(
              'Soru: ${_currentPage + 1} / ${_questions.length}',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            backgroundColor: colorScheme.primaryContainer.withOpacity(0.4),
            side: BorderSide.none,
          ),

          // Soru Listesi Butonu
          OutlinedButton.icon(
            icon: const FaIcon(FontAwesomeIcons.tableCells, size: 16),
            label: const Text('Soru Listesi'),
            onPressed: _showQuestionGridPicker, // <<< YENİ DİALOG'U AÇAR
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // --- DEĞİŞİKLİK BİTTİ ---

  // --- 3. YENİ: Soru Listesini Gösteren Bottom Sheet ---
  void _showQuestionGridPicker() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Ekranın %90'ına kadar büyüsün
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * 0.8, // Ekranın max %80'i
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Soruya Git',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              // Kaydırılabilir Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, // 6 sütun
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.0, // Kare
                  ),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final bool isCurrent = _currentPage == index;
                    final bool isAnswered = _selectedAnswers.containsKey(index);

                    Color boxColor = colorScheme.surface;
                    Color borderColor = colorScheme.outline.withOpacity(0.5);
                    Color textColor = colorScheme.onSurfaceVariant;

                    if (isAnswered) {
                      boxColor = colorScheme.primary.withOpacity(0.1);
                      borderColor = colorScheme.primary;
                      textColor = colorScheme.primary;
                    }
                    if (isCurrent) {
                      boxColor = colorScheme.primary;
                      borderColor = colorScheme.primary;
                      textColor = colorScheme.onPrimary;
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Sheet'i kapat
                        _pageController.jumpToPage(index); // Sayfaya atla
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: boxColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // --- YENİ FONKSİYON BİTTİ ---

  // Soru Sayfası
  Widget _buildQuestionPage(DocumentSnapshot question, int questionIndex) {
    final questionData = question.data() as Map<String, dynamic>? ?? {};
    final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
    final options = List<String>.from(questionData['secenekler'] ?? []);
    final String? imageUrl = questionData['imageUrl'] as String?;
    final int? selectedOptionIndex = _selectedAnswers[questionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soru ${questionIndex + 1}: $questionText',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => (progress == null)
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            itemBuilder: (context, optionIndex) {
              final bool isSelected = selectedOptionIndex == optionIndex;
              return Card(
                elevation: isSelected ? 2 : 0.5,
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.5)
                    : Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: RadioListTile<int>(
                  title: Text(
                    options[optionIndex],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  value: optionIndex,
                  groupValue: selectedOptionIndex,
                  onChanged: (value) {
                    if (value != null) _selectAnswer(questionIndex, value);
                  },
                  controlAffinity: ListTileControlAffinity.trailing,
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Navigasyon Kontrolleri
  Widget _buildNavigationControls(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final bool isFirst = _currentPage == 0;
    final bool isLast = _currentPage == _questions.length - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16.0,
        16.0,
        16.0,
        MediaQuery.of(context).padding.bottom + 16.0,
      ), // Güvenli alan
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border(
          top: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FilledButton.tonal(
            onPressed: isFirst
                ? null
                : () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
            child: const Row(
              children: [
                Icon(Icons.arrow_back),
                SizedBox(width: 8),
                Text('Önceki'),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isLast ? Colors.green : colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: _isSubmitting
                ? null
                : () {
                    if (isLast) {
                      _showSubmitConfirmation();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    children: [
                      Text(isLast ? 'Sınavı Bitir' : 'Sonraki'),
                      const SizedBox(width: 8),
                      Icon(isLast ? Icons.check_circle : Icons.arrow_forward),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Sınavı Bitir Onay Dialog'u
  void _showSubmitConfirmation() {
    final notAnswered = _questions.length - _selectedAnswers.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sınavı Bitir'),
        content: Text(
          notAnswered > 0
              ? '$notAnswered adet boş sorunuz var. Yine de sınavı bitirmek istediğinizden emin misiniz?'
              : 'Sınavı bitirmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              _submitTrialExam(); // Sınavı gönder
            },
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
  }
}
