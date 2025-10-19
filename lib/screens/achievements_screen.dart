import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<QueryDocumentSnapshot> _allAchievements = []; // Tüm başarı tanımları
  Map<String, dynamic> _earnedAchievements =
      {}; // Kazanılan başarılar (ID -> Veri)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    // Başlamadan önce mounted kontrolü
    if (!mounted) return;
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
      // Giriş yapmamış kullanıcı için mesaj gösterilebilir
      return;
    }

    if (mounted)
      setState(() {
        _isLoading = true;
      }); // Yüklemeye başla

    try {
      // Future'ları aynı anda başlat
      final allSnapshotFuture = _firestore.collection('achievements').get();
      final earnedSnapshotFuture = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('earnedAchievements')
          .get();

      // İki sorgunun da bitmesini bekle
      final results = await Future.wait([
        allSnapshotFuture,
        earnedSnapshotFuture,
      ]);

      if (!mounted) return; // Sonuçlar geldikten sonra kontrol

      // Sonuçları işle
      final allSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final earnedSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

      _allAchievements = allSnapshot.docs;
      // İleride sıralama için _allAchievements.sort(...) eklenebilir

      Map<String, dynamic> earnedMap = {};
      for (var doc in earnedSnapshot.docs) {
        earnedMap[doc.id] = doc.data();
      }
      _earnedAchievements = earnedMap;

      setState(() {
        _isLoading = false; // Yükleme bitti
      });
    } catch (e) {
      print("Başarılar yüklenirken hata: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Başarılar yüklenemedi: $e')));
      }
    }
  }

  // Tarihi formatlamak için yardımcı fonksiyon
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    try {
      // 'intl' paketinin başlatıldığından emin olun (main.dart içinde)
      return DateFormat.yMd(
        'tr_TR',
      ).format(timestamp.toDate()); // Kısa format: 19.10.2025
    } catch (e) {
      print("Tarih formatlama hatası: $e");
      return '?'; // Hata durumunda soru işareti göster
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Başarılarım')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allAchievements.isEmpty
          ? Center(
              child: Padding(
                // Biraz boşluk ekleyelim
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Henüz tanımlanmış bir başarı bulunmuyor. Yakında eklenecek!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : RefreshIndicator(
              // Listeyi yenileme özelliği
              onRefresh: _loadAchievements,
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _allAchievements.length,
                itemBuilder: (context, index) {
                  final achievementDoc = _allAchievements[index];
                  final achievementId = achievementDoc.id;
                  final achievementData =
                      achievementDoc.data() as Map<String, dynamic>? ??
                      {}; // Null check

                  final bool isEarned = _earnedAchievements.containsKey(
                    achievementId,
                  );
                  final earnedData = isEarned
                      ? _earnedAchievements[achievementId]
                      : null;
                  final String earnedDate = isEarned
                      ? _formatTimestamp(earnedData?['earnedDate'])
                      : '';

                  final String emoji = achievementData['emoji'] ?? '🏆';
                  final String name = achievementData['name'] ?? 'Başarı';
                  final String description =
                      achievementData['description'] ?? 'Açıklama yok';

                  return Opacity(
                    // Kazanılmayanları soluk göster
                    opacity: isEarned ? 1.0 : 0.6,
                    child: Card(
                      elevation: isEarned ? 3 : 1, // Kazanılan daha belirgin
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // Daha yuvarlak
                        side: BorderSide(
                          color: isEarned
                              ? Colors
                                    .green
                                    .shade200 // Daha yumuşak yeşil
                              : Colors.grey.shade300,
                          width: isEarned
                              ? 2
                              : 1, // Kazanılanın sınırı daha kalın
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        leading: Container(
                          // Emoji için arka plan
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isEarned
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(
                              fontSize: 30,
                            ), // Boyut ayarlandı
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16, // Boyut ayarlandı
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              height: 4,
                            ), // Başlık ile açıklama arasına boşluk
                            Text(description),
                            if (isEarned) // Kazanıldıysa tarihi göster
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Row(
                                  // İkon ile birlikte göster
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green.shade700,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Kazanıldı: $earnedDate',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.green.shade700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
