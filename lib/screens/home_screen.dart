import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/quiz_list_screen.dart';

// StatelessWidget -> StatefulWidget
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Key: kategoriId, Value: {'total': int, 'solved': int}
  Map<String, Map<String, int>> _categoryCompletion = {};
  bool _isCompletionLoading = true;
  String? _currentUserId; // Mevcut kullanıcı ID'sini state'de tutalım

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid; // ID'yi initState'de al
    _loadCompletionStatus();
  }

  // Kullanıcının her kategori için tamamlama durumunu hesaplar
  Future<void> _loadCompletionStatus() async {
    if (_currentUserId == null) {
      // State'deki ID'yi kontrol et
      if (mounted)
        setState(() {
          _isCompletionLoading = false;
        });
      return;
    }
    // Yüklemeye başlarken state'i ayarla (setState)
    if (mounted)
      setState(() {
        _isCompletionLoading = true;
      });

    try {
      // 1. Tüm kategorileri al
      final categoriesSnapshot = await _firestore
          .collection('categories')
          .get();
      if (categoriesSnapshot.docs.isEmpty) {
        if (mounted)
          setState(() {
            _isCompletionLoading = false;
          });
        return;
      }

      Map<String, Map<String, int>> completionData = {};

      // 2. Her kategori için async işlemler yap
      await Future.wait(
        categoriesSnapshot.docs.map((categoryDoc) async {
          final categoryId = categoryDoc.id;

          // 2a. O kategorideki toplam test sayısını al (count() sorgusu)
          final totalQuizAggregate = await _firestore
              .collection('quizzes')
              .where('kategoriId', isEqualTo: categoryId)
              .count()
              .get();
          // aggregate() sorgu sonucu .count ile alınır
          final totalQuizzes = totalQuizAggregate.count ?? 0;

          // 2b. Kullanıcının o kategoride çözdüğü test sayısını al (count() sorgusu)
          final solvedQuizAggregate = await _firestore
              .collection('users')
              .doc(_currentUserId!) // Null değilse ! kullanabiliriz
              .collection('solvedQuizzes')
              .where('kategoriId', isEqualTo: categoryId)
              .count()
              .get();
          // aggregate() sorgu sonucu .count ile alınır
          final solvedQuizzes = solvedQuizAggregate.count ?? 0;

          // Hesaplanan veriyi haritaya ekle
          completionData[categoryId] = {
            'total': totalQuizzes,
            'solved': solvedQuizzes,
          };
        }),
      ); // Future.wait bitti

      // State'i güncelle
      if (mounted) {
        setState(() {
          _categoryCompletion = completionData;
          _isCompletionLoading = false;
        });
      }
    } catch (e) {
      print("Kategori tamamlama durumu yüklenirken hata: $e");
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
    // initState'de aldığımız ID'yi kullanıyoruz
    // final String? currentUserId = _authService.currentUser?.uid; <- Buradan kaldırıldı
    final String currentUserEmail =
        _authService.currentUser?.email ?? 'Kullanıcı';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriler'),
        // Yenileme butonu eklendi (opsiyonel ama kullanışlı)
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'İlerlemeyi Yenile',
            onPressed: _isCompletionLoading
                ? null
                : _loadCompletionStatus, // Yükleniyorsa butonu kilitle
          ),
        ],
      ),
      body:
          _currentUserId ==
              null // State'deki ID kontrol ediliyor
          ? const Center(child: Text('Kullanıcı bulunamadı.'))
          : StreamBuilder<DocumentSnapshot>(
              // Kullanıcı adını dinleme
              stream: _firestore
                  .collection('users')
                  .doc(_currentUserId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                String welcomeMessage = 'Hoş Geldiniz!';
                if (userSnapshot.connectionState == ConnectionState.active &&
                    userSnapshot.hasData &&
                    userSnapshot.data!.exists) {
                  // exists kontrolü eklendi
                  var userData =
                      userSnapshot.data!.data() as Map<String, dynamic>? ??
                      {}; // Null check eklendi
                  var username = userData['kullaniciAdi'] ?? currentUserEmail;
                  welcomeMessage = 'Hoş Geldiniz, $username!';
                } else if (userSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  welcomeMessage = 'Yükleniyor...';
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        welcomeMessage,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(),

                    // Kategori Listesi
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        // Kategorileri dinleme
                        stream: _firestore
                            .collection('categories')
                            .orderBy('sira')
                            .snapshots(),
                        builder: (context, catSnapshot) {
                          // Tamamlama durumu yüklenirken de bekle
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
                            ); // Hata logu
                            return const Center(
                              child: Text(
                                'Kategoriler yüklenirken bir hata oluştu.',
                              ),
                            );
                          }
                          if (!catSnapshot.hasData ||
                              catSnapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('Gösterilecek kategori bulunamadı.'),
                            );
                          }

                          var documents = catSnapshot.data!.docs;

                          return ListView.builder(
                            itemCount: documents.length,
                            itemBuilder: (context, index) {
                              var data =
                                  documents[index].data()
                                      as Map<String, dynamic>;
                              var docId = documents[index].id;
                              var kategoriAdi =
                                  data['ad'] ?? 'İsimsiz Kategori';

                              // --- İlerleme durumunu al ---
                              final completionInfo = _categoryCompletion[docId];
                              final total = completionInfo?['total'] ?? 0;
                              final solved = completionInfo?['solved'] ?? 0;
                              Widget trailingWidget = const Icon(
                                Icons.arrow_forward_ios,
                              );

                              if (!_isCompletionLoading && total > 0) {
                                // Yükleme bittiyse ve test varsa
                                if (solved == total) {
                                  trailingWidget = const Tooltip(
                                    // Tooltip eklendi
                                    message: 'Tamamlandı',
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                  );
                                } else if (solved > 0) {
                                  trailingWidget = Tooltip(
                                    // Tooltip eklendi
                                    message: '$solved / $total tamamlandı',
                                    child: SizedBox(
                                      width: 60, // Genişlik biraz artırıldı
                                      height: 10, // Yükseklik verildi
                                      child: LinearProgressIndicator(
                                        value: solved / total,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                        borderRadius: BorderRadius.circular(
                                          5,
                                        ), // Köşeler yuvarlatıldı
                                      ),
                                    ),
                                  );
                                }
                              } else if (!_isCompletionLoading && total == 0) {
                                // Kategoride test yoksa farklı bir ikon gösterilebilir
                                trailingWidget = const Tooltip(
                                  message: 'Bu kategoride henüz test yok',
                                  child: Icon(
                                    Icons.hourglass_empty,
                                    color: Colors.grey,
                                  ),
                                );
                              }
                              // --- BİTTİ ---

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.category_outlined),
                                  title: Text(kategoriAdi),
                                  trailing: AnimatedSwitcher(
                                    // İkon değişimine animasyon eklendi
                                    duration: const Duration(milliseconds: 300),
                                    child: trailingWidget,
                                    key: ValueKey(
                                      docId + solved.toString(),
                                    ), // Animasyon için key
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
}
