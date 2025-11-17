import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/screens/trial_exam_result.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// --- YENİ IMPORTLAR (Reklam ve PRO Kontrolü için) ---
import 'package:provider/provider.dart';
import 'package:bilgi_yarismasi/services/user_data_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;
// --- BİTTİ ---

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
  String? _fetchError;
  Timer? _timer;
  int _secondsRemaining = 0;
  List<QueryDocumentSnapshot> _achievementDefinitions = [];
  Map<String, String> _categoryNameMap = {};

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  // !!! ÖNEMLİ: Bunlar TEST ID'leridir. AdMob'dan BANNER ID alıp değiştir.
  final String _bannerAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';
  // --- BİTTİ ---

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // PRO değilse reklamı yükle
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bool isPro = context.watch<UserDataProvider>().isPro;

    if (!isPro && _bannerAd == null) {
      _loadBannerAd();
    }
  }

  // Banner Reklamı Yükle
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          print('Banner Ad (TrialExam) yüklendi.');
          if (mounted) {
            setState(() {
              _isBannerLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('Banner Ad (TrialExam) yüklenemedi: $error');
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
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
        for (var doc in categoriesSnapshot.docs)
          doc.id:
              (doc.data() as Map<String, dynamic>)['ad'] as String? ?? doc.id,
      };
      _categoryNameMap['diger'] = 'Diğer';
      _achievementDefinitions = (results[2] as QuerySnapshot).docs;
      if (_questions.isEmpty) {
        setState(() {
          _isLoading = false;
          _fetchError = "Bu denemeye ait soru bulunamadı.";
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      print("Deneme sınavı verisi çekilirken hata: $e");
      if (e is FirebaseException && e.code == 'failed-precondition') {
        if (mounted)
          setState(() {
            _isLoading = false;
            _fetchError =
                "Veritabanı index hatası. Lütfen Firestore index'lerini kontrol edin.";
          });
      } else {
        if (mounted)
          setState(() {
            _isLoading = false;
            _fetchError = "Sorular yüklenemedi: $e";
          });
      }
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
          // Süre bittiğinde submitForfeit: false (Normal hesaplama)
          if (!_isSubmitting) _submitTrialExam(isTimeUp: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _selectAnswer(int questionIndex, int selectedIndex) {
    setState(() {
      _selectedAnswers[questionIndex] = selectedIndex;
    });
  }

  // --- GÜNCELLENMİŞ FONKSİYON: Sınavı Gönder / Terk Et Durumu Kaldırıldı ---
  // isTimeUp: Sadece süre bittiğinde true olur. Manuel çıkışta false'tur.
  Future<void> _submitTrialExam({bool isTimeUp = false}) async {
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

      // Çözülmüş mü kontrol et
      final resultDoc = await resultDocRef.get();
      if (resultDoc.exists) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu deneme sınavını zaten çözdünüz.')),
          );
        if (mounted) Navigator.pop(context, true);
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      int totalCorrect = 0, totalWrong = 0, totalEmpty = 0;
      int actualQuestionCount = _questions.length;
      Map<String, Map<String, int>> statsByCategory = {};
      Map<int, int> correctAnswersMap = {};

      // Normal Hesaplama: Tüm işaretli/işaretsiz soruları değerlendir
      for (int i = 0; i < actualQuestionCount; i++) {
        final qData = _questions[i].data() as Map<String, dynamic>;
        final String katId = qData['kategoriId'] ?? 'diger';
        final int correctIndex =
            (qData['dogruCevapIndex'] as num?)?.toInt() ?? -1;
        correctAnswersMap[i] = correctIndex;
        statsByCategory.putIfAbsent(
          katId,
          () => {'correct': 0, 'wrong': 0, 'empty': 0},
        );
        final int? selectedIndex = _selectedAnswers[i];

        if (selectedIndex == null) {
          statsByCategory[katId]!['empty'] =
              (statsByCategory[katId]!['empty'] ?? 0) + 1;
          totalEmpty++;
        } else if (selectedIndex == correctIndex) {
          statsByCategory[katId]!['correct'] =
              (statsByCategory[katId]!['correct'] ?? 0) + 1;
          totalCorrect++;
        } else {
          statsByCategory[katId]!['wrong'] =
              (statsByCategory[katId]!['wrong'] ?? 0) + 1;
          totalWrong++;
        }
      }

      // Puan Hesaplama
      double totalNet = totalCorrect - (totalWrong * 0.25);
      const double tabanPuan = 50.0;
      final double katsayi =
          (100.0 - tabanPuan) /
          (actualQuestionCount > 0 ? actualQuestionCount : 1);
      double kpssPuan = tabanPuan + (totalNet * katsayi);
      if (kpssPuan < 0) kpssPuan = 0.0;
      if (kpssPuan > 100) kpssPuan = 100.0;
      int rankingScore = (kpssPuan * 100).round();

      // Kullanıcı verilerini çek
      String kullaniciAdi = "Kullanıcı";
      String emoji = "🙂";
      String ad = "";
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        kullaniciAdi = userDoc.data()?['kullaniciAdi'] ?? kullaniciAdi;
        ad = userDoc.data()?['ad'] ?? '';
        emoji = userDoc.data()?['emoji'] ?? emoji;
      }

      // Sonucu Kaydet
      Map<String, dynamic> resultData = {
        'trialExamId': widget.trialExamId,
        'title': widget.title,
        'score': rankingScore,
        'kpssPuan': kpssPuan,
        'netSayisi': totalNet,
        'correctAnswers': totalCorrect,
        'wrongAnswers': totalWrong,
        'emptyAnswers': totalEmpty,
        'statsByCategory': statsByCategory,
        'totalQuestions': actualQuestionCount,
        'completionTime': FieldValue.serverTimestamp(),
        'timeSpentSeconds': (widget.durationMinutes * 60) - _secondsRemaining,
        'kullaniciAdi': ad.isNotEmpty ? ad : kullaniciAdi,
        'emoji': emoji,
        'userId': user.uid,
      };
      await resultDocRef.set(resultData);

      // Başarımları Kontrol Et
      List<Map<String, dynamic>> newAchievements =
          await _checkTrialExamAchievements(user.uid);

      if (mounted) {
        // Sonuç ekranına yönlendir
        final result = await Navigator.push(
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
              newAchievements: newAchievements,
            ),
          ),
        );
        if (mounted && (result == true)) {
          Navigator.pop(context, true);
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

  Future<List<Map<String, dynamic>>> _checkTrialExamAchievements(
    String userId,
  ) async {
    List<Map<String, dynamic>> newlyEarnedAchievements = [];
    if (_achievementDefinitions.isEmpty || !mounted)
      return newlyEarnedAchievements;
    try {
      final earnedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('earnedAchievements')
          .get();
      final earnedAchievementIds = earnedSnapshot.docs
          .map((doc) => doc.id)
          .toSet();
      final solvedTrialCountSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('trialExamResults')
          .count()
          .get();
      final solvedTrialCount = solvedTrialCountSnapshot.count ?? 0;
      WriteBatch? batch;
      for (var achievementDoc in _achievementDefinitions) {
        final achievementId = achievementDoc.id;
        if (earnedAchievementIds.contains(achievementId)) continue;
        final achievementData = achievementDoc.data() as Map<String, dynamic>?;
        if (achievementData == null) continue;
        final criteriaType = achievementData['criteria_type'] as String?;
        final criteriaValue =
            (achievementData['criteria_value'] as num?)?.toInt() ?? 0;
        bool earned = false;
        if (criteriaType == 'trial_exam_solved_count') {
          if (solvedTrialCount >= criteriaValue) {
            earned = true;
          }
        }
        if (earned) {
          final String achievementName =
              achievementData['name'] as String? ?? 'İsimsiz Başarı';
          final String achievementEmoji =
              achievementData['emoji'] as String? ?? '🏆';
          final String achievementDescription =
              achievementData['description'] as String? ?? '';
          print("🎉 Yeni Deneme Sınavı Başarısı: $achievementName");
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
        print("Kazanılan deneme başarıları kaydedildi.");
      }
    } catch (e) {
      print("Deneme sınavı başarı kontrolü sırasında hata: $e");
    }
    return newlyEarnedAchievements;
  }

  // --- GÜNCELLENMİŞ FONKSİYON: Sınavdan Çıkma Uyarısı ---
  Future<bool> _onWillPop() async {
    if (_isSubmitting) return false;
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sınavdan Çıkmak Üzeresiniz'),
        content: Text(
          // Metin Güncellendi
          'Şimdi çıkarsanız bu sınava tekrar giremezsiniz. O ana kadar çözdüğünüz soruların sonuçları hesaplanacaktır. Emin misiniz?',
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
            child: const Text(
              'Sınavdan Çık', // Buton metni güncellendi
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (shouldPop == true) {
      // isForfeit: false olarak (ya da parametresiz) çağır
      await _submitTrialExam();
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sorulara Git',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.0,
                            ),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final bool isCurrent = _currentPage == index;
                          final bool isAnswered = _selectedAnswers.containsKey(
                            index,
                          );
                          Color boxColor = colorScheme.surface;
                          Color borderColor = colorScheme.outline.withOpacity(
                            0.3,
                          );
                          Color textColor = colorScheme.onSurfaceVariant;

                          if (isAnswered) {
                            boxColor = colorScheme.primaryContainer;
                            borderColor = colorScheme.primary;
                            textColor = colorScheme.onPrimaryContainer;
                          }

                          if (isCurrent) {
                            boxColor = colorScheme.primary;
                            borderColor = colorScheme.primary;
                            textColor = colorScheme.onPrimary;
                          }

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: boxColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: borderColor,
                                  width: 2,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: colorScheme.primary
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubmitConfirmation() {
    final notAnswered = _questions.length - _selectedAnswers.length;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.task_alt_rounded, color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            const Text('Sınavı Bitir'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notAnswered > 0
                  ? '$notAnswered adet boş sorunuz var. Yine de sınavı bitirmek istediğinizden emin misiniz?'
                  : 'Sınavı bitirmek istediğinizden emin misiniz?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (notAnswered > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Boş sorular yanlış sayılacaktır.',
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _submitTrialExam();
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Bitir'),
          ),
        ],
      ),
    );
  }

  // === build METODU (Değişiklik yok) ===
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
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _secondsRemaining < 60
                    ? colorScheme.errorContainer.withOpacity(0.9)
                    : colorScheme.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: _secondsRemaining < 60
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formattedTime,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondsRemaining < 60
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: _isLoading
            ? Container(
                color: colorScheme.surface,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: colorScheme.primary,
                        strokeWidth: 4,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sorular Yükleniyor...',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _fetchError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: colorScheme.error,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _fetchError!,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _loadInitialData(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Dene'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  _buildNavigationHeader(colorScheme, textTheme),
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
        bottomNavigationBar: _buildBannerAdWidget(),
      ),
    );
  }

  Widget? _buildBannerAdWidget() {
    if (_isBannerLoaded && _bannerAd != null) {
      return Container(
        height: _bannerAd!.size.height.toDouble(),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return null;
  }

  // Soru Sayfası (Değişiklik yok)
  Widget _buildQuestionPage(DocumentSnapshot question, int questionIndex) {
    final questionData = question.data() as Map<String, dynamic>? ?? {};
    final questionText = questionData['soruMetni'] ?? 'Soru yüklenemedi';
    final options = List<String>.from(questionData['secenekler'] ?? []);
    final String? imageUrl = questionData['imageUrl'] as String?;
    final int? selectedOptionIndex = _selectedAnswers[questionIndex];
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    questionText,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (imageUrl != null && imageUrl.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) =>
                      (progress == null)
                      ? child
                      : Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                  errorBuilder: (context, error, stack) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_rounded,
                            color: colorScheme.onSurfaceVariant,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Görsel yüklenemedi',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            itemBuilder: (context, optionIndex) {
              final bool isSelected = selectedOptionIndex == optionIndex;
              final optionLetter = String.fromCharCode(
                65 + optionIndex,
              ); // A, B, C, D

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _selectAnswer(questionIndex, optionIndex),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.surfaceVariant,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outline.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              optionLetter,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            options[optionIndex],
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w400
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Navigasyon Başlığı (Değişiklik yok)
  Widget _buildNavigationHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Soru: ${_currentPage + 1} / ${_questions.length}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            icon: const FaIcon(FontAwesomeIcons.tableCells, size: 16),
            label: const Text('Soru Listesi'),
            onPressed: _showQuestionGridPicker,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  // Navigasyon Kontrolleri (Değişiklik yok)
  Widget _buildNavigationControls(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final bool isFirst = _currentPage == 0;
    final bool isLast = _currentPage == _questions.length - 1;

    final double bottomPadding = _isBannerLoaded
        ? 16.0
        : MediaQuery.of(context).padding.bottom + 16.0;

    return Container(
      padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, bottomPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: isFirst
                    ? null
                    : () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Önceki'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLast ? Colors.green : colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
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
                icon: _isSubmitting
                    ? Container(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        isLast
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(
                  _isSubmitting
                      ? 'İşleniyor...'
                      : (isLast ? 'Sınavı Bitir' : 'Sonraki'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
