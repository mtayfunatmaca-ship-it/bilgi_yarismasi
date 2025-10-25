import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/screens/deneme_sinavi_sonuc_ekrani.dart'; 
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Gerekli import'lar (ResultScreen ve ReviewScreen)
import 'package:bilgi_yarismasi/screens/result_screen.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_review_screen.dart';


class TrialExamScreen extends StatefulWidget {
  final String trialExamId;
  final String title;
  final int durationMinutes;
  final int questionCount; // JSON'dan gelen toplam soru sayısı

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
  String? _fetchError;

  Timer? _timer;
  int _secondsRemaining = 0;

  List<QueryDocumentSnapshot> _achievementDefinitions = [];
  Map<String, String> _categoryNameMap = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _firestore
            .collection('questions')
            .where('trialExamId', isEqualTo: widget.trialExamId)
            .orderBy('sira')
            .get(),
        _firestore.collection('categories').get(),
        _firestore.collection('achievements').get(),
      ]);

      if (!mounted) return;

      final questionSnapshot = results[0] as QuerySnapshot;
      var fetchedQuestions = questionSnapshot.docs;
      
      _questions = fetchedQuestions.take(widget.questionCount).toList();
      
      final categoriesSnapshot = results[1] as QuerySnapshot;
      _categoryNameMap = {
        for (var doc in categoriesSnapshot.docs) doc.id: (doc.data() as Map<String, dynamic>)['ad'] as String? ?? doc.id
      };
      _categoryNameMap['diger'] = 'Diğer';

      _achievementDefinitions = (results[2] as QuerySnapshot).docs;

      if (_questions.isEmpty) {
         setState(() { _isLoading = false; _fetchError = "Bu denemeye ait soru bulunamadı."; });
      } else {
         setState(() { _isLoading = false; });
         _startTimer();
      }
    } catch (e) {
      print("Deneme sınavı verisi çekilirken hata: $e");
       if (e is FirebaseException && e.code == 'failed-precondition') {
         if (mounted) setState(() { _isLoading = false; _fetchError = "Veritabanı index hatası. Lütfen Firestore index'lerini kontrol edin."; });
      } else {
         if (mounted) setState(() { _isLoading = false; _fetchError = "Sorular yüklenemedi: $e"; });
      }
    }
  }

  void _startTimer() {
    _secondsRemaining = widget.durationMinutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
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

  // --- _submitTrialExam GÜNCELLENDİ (Puanlama Düzeltmesi) ---
  Future<void> _submitTrialExam({bool isForfeit = false, bool isTimeUp = false}) async {
    _timer?.cancel();
    if (_isSubmitting || !mounted) return;
    setState(() => _isSubmitting = true);

    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    try {
      final resultDocRef = _firestore.collection('users').doc(user.uid).collection('trialExamResults').doc(widget.trialExamId);
      final resultDoc = await resultDocRef.get();
      if (resultDoc.exists && !isForfeit) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu deneme sınavını zaten çözdünüz.')));
         if(mounted) Navigator.pop(context, true);
         if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      int totalCorrect = 0;
      int totalWrong = 0;
      int totalEmpty = 0;
      int actualQuestionCount = _questions.length;
      Map<String, Map<String, int>> statsByCategory = {};
      Map<int, int> correctAnswersMap = {};

      if(isForfeit) {
         totalWrong = actualQuestionCount;
      } else {
         for (int i = 0; i < actualQuestionCount; i++) {
           final qData = _questions[i].data() as Map<String, dynamic>;
           final String katId = qData['kategoriId'] ?? 'diger';
           final int correctIndex = (qData['dogruCevapIndex'] as num?)?.toInt() ?? -1;
           correctAnswersMap[i] = correctIndex;
           statsByCategory.putIfAbsent(katId, () => {'correct': 0, 'wrong': 0, 'empty': 0});
           final int? selectedIndex = _selectedAnswers[i];
           if (selectedIndex == null) {
             statsByCategory[katId]!['empty'] = (statsByCategory[katId]!['empty'] ?? 0) + 1;
             totalEmpty++;
           } else if (selectedIndex == correctIndex) {
             statsByCategory[katId]!['correct'] = (statsByCategory[katId]!['correct'] ?? 0) + 1;
             totalCorrect++;
           } else {
             statsByCategory[katId]!['wrong'] = (statsByCategory[katId]!['wrong'] ?? 0) + 1;
             totalWrong++;
           }
         }
      }
      
      // --- KPSS PUAN HESAPLAMASI (Taban Puanlı) ---
      double totalNet = totalCorrect - (totalWrong * 0.25);
      
      const double tabanPuan = 50.0;
      final double katsayi = (100.0 - tabanPuan) / (actualQuestionCount > 0 ? actualQuestionCount : 1);
      double kpssPuan = tabanPuan + (totalNet * katsayi);
      if (kpssPuan < 0) kpssPuan = 0.0;
      if (kpssPuan > 100) kpssPuan = 100.0;
      
      // --- DÜZELTME: Sıralama puanı = KPSS Puanı ---
      // (Sıralamada 85.5 puan 85'ten yüksek olsun diye 100 ile çarpıp int yapabiliriz)
      int rankingScore = (kpssPuan * 100).round(); // Örn: 85.125 Puan -> 85125 Sıralama Puanı
      // --- DÜZELTME BİTTİ ---
      
      String kullaniciAdi = "Kullanıcı";
      String emoji = "🙂";
      String ad = "";
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if(userDoc.exists){
         kullaniciAdi = userDoc.data()?['kullaniciAdi'] ?? kullaniciAdi;
         ad = userDoc.data()?['ad'] ?? '';
         emoji = userDoc.data()?['emoji'] ?? emoji;
      }
      
      Map<String, dynamic> resultData = {
        'trialExamId': widget.trialExamId, 'title': widget.title, 
        'score': rankingScore, // Sıralama için (örn: 85125)
        'kpssPuan': kpssPuan, // Gösterim için (örn: 85.125)
        'netSayisi': totalNet,
        'correctAnswers': totalCorrect, 'wrongAnswers': totalWrong, 'emptyAnswers': totalEmpty,
        'statsByCategory': statsByCategory,
        'totalQuestions': actualQuestionCount, 'completionTime': FieldValue.serverTimestamp(),
        'timeSpentSeconds': (widget.durationMinutes * 60) - _secondsRemaining,
        'kullaniciAdi': ad.isNotEmpty ? ad : kullaniciAdi,
        'emoji': emoji, 'userId': user.uid,
      };
      await resultDocRef.set(resultData);

      if (!isForfeit) {
        await _checkTrialExamAchievements(user.uid);
      }

      if (mounted) {
        if (isForfeit) {
           Navigator.pop(context, true);
        } else {
           await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TrialExamResultScreen(
                   title: widget.title,
                   kpssPuan: kpssPuan,
                   netSayisi: totalNet,
                   dogruSayisi: totalCorrect,
                   yanlisSayisi: totalWrong,
                   bosSayisi: totalEmpty,
                   soruSayisi: actualQuestionCount,
                   statsByCategory: statsByCategory,
                   categoryNameMap: _categoryNameMap,
                   questions: _questions, 
                   userAnswers: _selectedAnswers,
                   correctAnswers: correctAnswersMap,
                   trialExamId: widget.trialExamId, 
                   trialExamTitle: widget.title,
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: Sınav sonucu kaydedilemedi. $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  
  // --- Fonksiyonların geri kalanı (Değişiklik Yok) ---

  Future<void> _checkTrialExamAchievements(String userId) async {
    if (_achievementDefinitions.isEmpty || !mounted) return;
    try {
      final earnedSnapshot = await _firestore.collection('users').doc(userId).collection('earnedAchievements').get();
      final earnedAchievementIds = earnedSnapshot.docs.map((doc) => doc.id).toSet();
      final solvedTrialCountSnapshot = await _firestore.collection('users').doc(userId).collection('trialExamResults').count().get();
      final solvedTrialCount = solvedTrialCountSnapshot.count ?? 0;
      WriteBatch? batch;
      List<Map<String, dynamic>> newlyEarnedAchievements = [];
      for (var achievementDoc in _achievementDefinitions) {
        final achievementId = achievementDoc.id;
        if (earnedAchievementIds.contains(achievementId)) continue;
        final achievementData = achievementDoc.data() as Map<String, dynamic>?;
        if (achievementData == null) continue;
        final criteriaType = achievementData['criteria_type'] as String?;
        final criteriaValue = (achievementData['criteria_value'] as num?)?.toInt() ?? 0;
        bool earned = false;
        if (criteriaType == 'trial_exam_solved_count') {
          if (solvedTrialCount >= criteriaValue) {
            earned = true;
          }
        }
        if (earned) {
          final String achievementName = achievementData['name'] as String? ?? 'İsimsiz Başarı';
          final String achievementEmoji = achievementData['emoji'] as String? ?? '🏆';
          final String achievementDescription = achievementData['description'] as String? ?? '';
          print("🎉 Yeni Deneme Sınavı Başarısı: $achievementName");
          batch ??= _firestore.batch();
          final newEarnedRef = _firestore.collection('users').doc(userId).collection('earnedAchievements').doc(achievementId);
          batch.set(newEarnedRef, {'earnedDate': FieldValue.serverTimestamp(), 'name': achievementName, 'emoji': achievementEmoji});
          newlyEarnedAchievements.add({'name': achievementName, 'emoji': achievementEmoji, 'description': achievementDescription});
        }
      }
      if (batch != null) {
        await batch.commit();
        print("Kazanılan deneme başarıları kaydedildi.");
        if (mounted) {
          for (var achievementData in newlyEarnedAchievements) {
             await Future.delayed(const Duration(milliseconds: 500));
             if (mounted) _showAchievementEarnedDialog(achievementData);
          }
        }
      }
    } catch (e) {
      print("Deneme sınavı başarı kontrolü sırasında hata: $e");
    }
  }

  void _showAchievementEarnedDialog(Map<String, dynamic> achievementData) {
     if (!mounted) return;
     final emoji = achievementData['emoji'] as String? ?? '🏆';
     final name = achievementData['name'] as String? ?? 'Başarı';
     final description = achievementData['description'] as String? ?? '';
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
  
  Future<bool> _onWillPop() async {
    if (_isSubmitting) return false;
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sınavdan Çıkmak Üzeresiniz'),
        content: const Text('Şimdi çıkarsanız bu sınava tekrar giremezsiniz ve 0 puan alırsınız. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
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

  void _showQuestionGridPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
             maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Soruya Git', style: Theme.of(context).textTheme.titleLarge),
              ),
              const Divider(height: 1),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.0,
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
                         Navigator.pop(context);
                         _pageController.jumpToPage(index);
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
                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
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
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if(didPop) return;
         final shouldPop = await _onWillPop();
         if(shouldPop && mounted) {
            Navigator.pop(context);
         }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () async {
             final shouldPop = await _onWillPop();
             if (shouldPop && mounted) {
                Navigator.pop(context);
             }
          }),
          actions: [
             Padding(
               padding: const EdgeInsets.only(right: 16.0),
               child: Chip(
                 label: Text(_formattedTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                 avatar: Icon(Icons.timer_outlined, color: _secondsRemaining < 60 ? Colors.red : colorScheme.onSurfaceVariant),
                 backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
               ),
             )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _fetchError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_fetchError!)))
              : Column(
                  children: [
                    _buildNavigationHeader(colorScheme, textTheme),
                    const Divider(height: 1),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _questions.length,
                        onPageChanged: (page) {
                           setState(() { _currentPage = page; });
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => (progress == null) ? child : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, color: Colors.grey),
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
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                     side: BorderSide(
                       color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                       width: 1.5,
                     )
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: RadioListTile<int>(
                    title: Text(options[optionIndex], style: Theme.of(context).textTheme.bodyLarge),
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

  Widget _buildNavigationHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Chip(
            label: Text(
              'Soru: ${_currentPage + 1} / ${_questions.length}',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
            ),
            backgroundColor: colorScheme.primaryContainer.withOpacity(0.4),
            side: BorderSide.none,
          ),
          OutlinedButton.icon(
            icon: const FaIcon(FontAwesomeIcons.tableCells, size: 16),
            label: const Text('Soru Listesi'),
            onPressed: _showQuestionGridPicker,
            style: OutlinedButton.styleFrom(
               padding: const EdgeInsets.symmetric(horizontal: 12),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls(ColorScheme colorScheme, TextTheme textTheme) {
     final bool isFirst = _currentPage == 0;
     final bool isLast = _currentPage == _questions.length - 1;

     return Container(
       padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 16.0),
       decoration: BoxDecoration(
         color: colorScheme.surface,
         boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)) ],
         border: Border(top: BorderSide(color: colorScheme.outline.withOpacity(0.2))),
       ),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
            FilledButton.tonal(
              onPressed: isFirst ? null : () {
                 _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              },
              child: const Row(children: [Icon(Icons.arrow_back), SizedBox(width: 8), Text('Önceki')]),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                 backgroundColor: isLast ? Colors.green : colorScheme.primary,
                 foregroundColor: Colors.white,
              ),
              onPressed: _isSubmitting ? null : () {
                 if (isLast) {
                    _showSubmitConfirmation();
                 } else {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                 }
              },
              child: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(children: [
                    Text(isLast ? 'Sınavı Bitir' : 'Sonraki'),
                    const SizedBox(width: 8),
                    Icon(isLast ? Icons.check_circle : Icons.arrow_forward),
                  ]),
            ),
         ],
       ),
     );
  }
  
  void _showSubmitConfirmation() {
     final notAnswered = _questions.length - _selectedAnswers.length;
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
         title: const Text('Sınavı Bitir'),
         content: Text(
           notAnswered > 0 
           ? '$notAnswered adet boş sorunuz var. Yine de sınavı bitirmek istediğinizden emin misiniz?'
           : 'Sınavı bitirmek istediğinizden emin misiniz?'
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
             onPressed: () {
                Navigator.pop(context);
                _submitTrialExam();
             },
             child: const Text('Bitir'),
           ),
         ],
      ),
    );
  }
}