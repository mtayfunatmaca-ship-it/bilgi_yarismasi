import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_list_screen.dart';
import 'package:bilgi_yarismasi/screens/trial_exams_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, int>> _categoryCompletion = {};
  bool _isCompletionLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;
    _loadCompletionStatus();
  }

  Future<void> _reloadAllData() async {
    await _loadCompletionStatus();
    // userStream zaten dinlendiği için state değişikliği onu da tetikler.
    if (mounted) {
      setState(() {}); // Build'i tetiklemek için boş setState
    }
  }

  Future<void> _loadCompletionStatus() async {
    if (!mounted || _currentUserId == null) {
      if (mounted) setState(() => _isCompletionLoading = false);
      return;
    }
    setState(() => _isCompletionLoading = true);

    try {
      final categoriesSnapshot = await _firestore
          .collection('categories')
          .get();
      if (!mounted || categoriesSnapshot.docs.isEmpty) {
        if (mounted) setState(() => _isCompletionLoading = false);
        return;
      }

      Map<String, Map<String, int>> completionData = {};
      final List<Future<void>> futures = [];
      final Map<String, int> totalQuizCounts = {};
      final Map<String, int> solvedQuizCounts = {};

      for (var categoryDoc in categoriesSnapshot.docs) {
        final categoryId = categoryDoc.id;
        futures.add(
          _firestore
              .collection('quizzes')
              .where('kategoriId', isEqualTo: categoryId)
              .count()
              .get()
              .then(
                (aggregate) =>
                    totalQuizCounts[categoryId] = aggregate.count ?? 0,
              )
              .catchError((e) {
                print("Toplam test sayısı alınırken hata ($categoryId): $e");
                totalQuizCounts[categoryId] = -1; // Hata
              }),
        );
      }

      final solvedSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('solvedQuizzes')
          .get();

      Map<String, int> solvedCountsByCategory = {};
      for (var solvedDoc in solvedSnapshot.docs) {
        final solvedData = solvedDoc.data();
        final categoryId = solvedData['kategoriId'] as String?;
        if (categoryId != null) {
          solvedCountsByCategory[categoryId] =
              (solvedCountsByCategory[categoryId] ?? 0) + 1;
        }
      }
      categoriesSnapshot.docs.forEach((categoryDoc) {
        final categoryId = categoryDoc.id;
        solvedQuizCounts[categoryId] = solvedCountsByCategory[categoryId] ?? 0;
      });

      await Future.wait(futures);

      if (!mounted) return;

      categoriesSnapshot.docs.forEach((categoryDoc) {
        final categoryId = categoryDoc.id;
        completionData[categoryId] = {
          'total': totalQuizCounts[categoryId] ?? 0,
          'solved': solvedQuizCounts[categoryId] ?? 0,
        };
      });

      setState(() {
        _categoryCompletion = completionData;
        _isCompletionLoading = false;
      });
    } catch (e) {
      print("Kategori tamamlama durumu yüklenirken genel hata: $e");
      if (mounted) {
        setState(() {
          _isCompletionLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori ilerlemesi yüklenemedi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserEmail =
        _authService.currentUser?.email ?? 'Kullanıcı';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _isCompletionLoading ? null : _reloadAllData,
          ),
        ],
      ),
      body: _currentUserId == null
          ? _buildErrorUI(
              'Kullanıcı bilgisi bulunamadı. Lütfen tekrar giriş yapın.',
            )
          : StreamBuilder<DocumentSnapshot>(
              // Kullanıcı adını dinle
              stream: _firestore
                  .collection('users')
                  .doc(_currentUserId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                Widget welcomeWidget;
                String welcomeMessage = 'Hoş Geldiniz!'; // Başlangıç değeri
                if (userSnapshot.hasError) {
                  print("Kullanıcı adı okuma hatası: ${userSnapshot.error}");
                  welcomeWidget = Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade300,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          welcomeMessage,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(Profil yüklenemedi)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                } else if (userSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  welcomeMessage = 'Yükleniyor...';
                  welcomeWidget = Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          welcomeMessage,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                } else if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  var userData =
                      userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  var username = userData['kullaniciAdi'] ?? currentUserEmail;
                  welcomeMessage = 'Hoş Geldiniz, $username!';
                  welcomeWidget = Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      welcomeMessage,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                } else {
                  // hasData false veya !exists
                  welcomeWidget = Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      welcomeMessage,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }

                return Column(
                  children: [
                    welcomeWidget,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 0,
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.assignment_outlined, size: 20),
                        label: const Text('Deneme Sınavlarını Gör'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: Theme.of(context).textTheme.labelLarge,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TrialExamsListScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 24),

                    // Kategori Listesi
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        // Kategorileri dinle
                        stream: _firestore
                            .collection('categories')
                            .orderBy('sira')
                            .snapshots(),
                        builder: (context, catSnapshot) {
                          if (catSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              _isCompletionLoading) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (catSnapshot.hasError) {
                            print(
                              "Kategori okuma hatası: ${catSnapshot.error}",
                            );
                            return _buildErrorUI(
                              'Kategoriler yüklenirken bir sorun oluştu.',
                              onRetry: _reloadAllData,
                            );
                          }
                          if (!catSnapshot.hasData ||
                              catSnapshot.data!.docs.isEmpty) {
                            return _buildErrorUI(
                              'Görsterilecek kategori bulunamadı.\nVerilerin yüklendiğinden emin olun.',
                              icon: Icons.search_off_rounded,
                            );
                          }

                          var documents = catSnapshot.data!.docs;

                          return RefreshIndicator(
                            onRefresh: _reloadAllData,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: documents.length,
                              itemBuilder: (context, index) {
                                var data =
                                    documents[index].data()
                                        as Map<String, dynamic>;
                                var docId = documents[index].id;
                                var kategoriAdi =
                                    data['ad'] ?? 'İsimsiz Kategori';

                                final completionInfo =
                                    _categoryCompletion[docId];
                                final total = completionInfo?['total'] ?? 0;
                                final solved = completionInfo?['solved'] ?? 0;
                                Widget trailingWidget = const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 18,
                                );

                                if (!_isCompletionLoading && total > 0) {
                                  if (solved == total) {
                                    trailingWidget = Tooltip(
                                      message: 'Tamamlandı',
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade600,
                                      ),
                                    );
                                  } else if (solved > 0) {
                                    trailingWidget = Tooltip(
                                      message: '$solved / $total tamamlandı',
                                      child: SizedBox(
                                        width: 60,
                                        height: 8,
                                        child: LinearProgressIndicator(
                                          value: solved / total,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                } else if (!_isCompletionLoading &&
                                    total == 0) {
                                  trailingWidget = const Tooltip(
                                    message: 'Bu kategoride henüz test yok',
                                    child: Icon(
                                      Icons.hourglass_empty,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                  );
                                } else if (total == -1) {
                                  // Hata durumunu belirt
                                  trailingWidget = const Tooltip(
                                    message: 'İlerleme yüklenemedi',
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                  );
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: const Icon(
                                      Icons.category_outlined,
                                    ),
                                    title: Text(
                                      kategoriAdi,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    trailing: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: trailingWidget,
                                      key: ValueKey(
                                        docId +
                                            solved.toString() +
                                            total.toString(),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => QuizListScreen(
                                            kategoriId: docId,
                                            kategoriAd: kategoriAdi,
                                          ),
                                        ),
                                      ).then((value) {
                                        // Geri dönüldüğünde tamamlama durumunu yenile
                                        _loadCompletionStatus();
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // Hata/Boş Durum Gösterimi Widget'ı
  Widget _buildErrorUI(
    String message, {
    VoidCallback? onRetry,
    IconData icon = Icons.error_outline,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey.shade400, size: 60),
            const SizedBox(height: 15),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
