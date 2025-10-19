import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/solved_quizzes_screen.dart';
import 'package:bilgi_yarismasi/screens/achievements_screen.dart'; // <<< BAŞARI EKRANI IMPORT'U

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  String _email = '';
  String _kullaniciAdi = '';
  String _emoji = '🙂';
  int _toplamPuan = 0;
  int _liderlikSirasi = 0;

  bool _isLoading = true;
  bool _isSaving = false; // Emoji kaydetme durumu için

  final List<String> _availableEmojis = [
    '🙂',
    '😎',
    '🤓',
    '🧐',
    '😺',
    '👾',
    '🐱',
    '🐶',
    '🐵',
    '🦄',
    '🐸',
    '🐯',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Arka planı şeffaf yap
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface, // Tema rengini kullan
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Profil Emojisi Seç',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).dividerColor,
              ), // Ayırıcı
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GridView.count(
                  crossAxisCount: 6, // 6 sütunlu grid
                  shrinkWrap: true, // İçeriğe göre boyutlan
                  physics:
                      const NeverScrollableScrollPhysics(), // Kaydırmayı engelle
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: _availableEmojis.map((e) {
                    bool isSelected = (_emoji == e); // Mevcut emoji mi?
                    return GestureDetector(
                      onTap: () {
                        if (!mounted) return; // Ekran kapandıysa işlem yapma
                        setState(() {
                          _emoji = e;
                        });
                        _saveEmoji(); // Firestore'a kaydet
                        Navigator.pop(context); // Bottom sheet'i kapat
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          // Seçiliyse hafif vurgu rengi
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16), // Alt boşluk
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveEmoji() async {
    if (_isSaving || !mounted) return; // Kaydediyorsa veya ekran kapandıysa çık

    setState(() => _isSaving = true);
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'emoji': _emoji, // Yeni emojiyi güncelle
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil emojisi güncellendi!')),
        );
      }
    } catch (e) {
      print("Emoji kaydetme hatası: $e"); // Hatayı logla
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Emoji güncellenemedi. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return; // Başlamadan kontrol
    final user = _authService.currentUser;
    if (user == null) {
      // Eğer kullanıcı yoksa, çıkış yapıp Login ekranına yönlendirmek daha mantıklı olabilir
      // Veya en azından sayfayı kapatmak
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (mounted)
      setState(() {
        _isLoading = true;
      }); // Yüklemeye başla

    try {
      // Kullanıcı belgesini al
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return; // Veri geldikten sonra ekran kapandıysa

      if (!doc.exists) {
        print("Kullanıcı belgesi bulunamadı: ${user.uid}");
        setState(() {
          _isLoading = false;
        }); // Yüklemeyi bitir
        // Belki burada bir hata mesajı gösterilebilir
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final toplamPuan = (data['toplamPuan'] as num? ?? 0).toInt();

      // Liderlik sırasını bul (performans için iyileştirilebilir)
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('toplamPuan', descending: true)
          // .limit(500) // Belki bir limit eklemek iyi olabilir
          .get();

      if (!mounted) return; // Sorgu sonrası kontrol

      int sirasi = -1; // Bulunamazsa -1
      int currentRank = 1;
      for (var userDoc in querySnapshot.docs) {
        if (userDoc.id == user.uid) {
          sirasi = currentRank;
          break;
        }
        currentRank++;
      }

      // State'i güncelle
      setState(() {
        _email = data['email'] ?? 'E-posta yok';
        _kullaniciAdi = data['kullaniciAdi'] ?? 'İsimsiz';
        _emoji = data['emoji'] ?? '🙂'; // Firestore'dan emojiyi oku
        _toplamPuan = toplamPuan;
        _liderlikSirasi = sirasi;
        _isLoading = false; // Yükleme bitti
      });
    } catch (e) {
      print("Profil verisi yüklenirken hata: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        }); // Hata durumunda da yüklemeyi bitir
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil verileri yüklenemedi: $e')),
        );
      }
    }
  }

  // Kullanıcı adını düzenlemek için (Dialog ile)
  void _showEditUsernameDialog() {
    final TextEditingController usernameController = TextEditingController(
      text: _kullaniciAdi,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kullanıcı Adını Düzenle'),
          content: TextField(
            controller: usernameController,
            decoration: const InputDecoration(hintText: "Yeni kullanıcı adı"),
            autofocus: true, // Otomatik odaklanma
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                final newUsername = usernameController.text.trim();
                Navigator.pop(context); // Dialog'u kapat
                if (newUsername.isNotEmpty && newUsername != _kullaniciAdi) {
                  _saveUsername(newUsername); // Yeni adı kaydet
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  // Kullanıcı adını kaydetme fonksiyonu
  Future<void> _saveUsername(String newUsername) async {
    if (_isSaving || !mounted) return;

    setState(() => _isSaving = true);
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'kullaniciAdi': newUsername, // Yeni adı güncelle
      });
      if (mounted) {
        setState(() {
          _kullaniciAdi = newUsername; // State'i de anında güncelle
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı adı güncellendi!')),
        );
      }
    } catch (e) {
      print("Kullanıcı adı kaydetme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Kullanıcı adı güncellenemedi. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profilim',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: false, // Başlığı sola yasla
        elevation: 0, // Gölgeyi kaldır (Material 3)
        backgroundColor: Colors.transparent, // Arka planı şeffaf yap
        foregroundColor: colorScheme.onSurface, // İkon/Yazı rengi
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: colorScheme.error),
            tooltip: 'Çıkış Yap',
            onPressed: () {
              // Çıkış yapmadan önce onay sormak iyi bir fikir olabilir
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content: const Text(
                    'Çıkış yapmak istediğinizden emin misiniz?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx); // Dialog'u kapat
                        _authService.signOut(); // Çıkış yap
                      },
                      child: Text(
                        'Çıkış Yap',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              // Sayfayı yenileme özelliği eklendi
              onRefresh: _loadUserData, // Yenileyince verileri tekrar yükle
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(), // İçerik az olsa bile yenilemeyi aktif et
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // --- Profil Kartı (Görünüm İyileştirildi) ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ), // Padding ayarlandı
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          // Daha belirgin gradient
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer.withOpacity(
                              0.5,
                            ), // Tema rengi kullanıldı
                            colorScheme.primaryContainer.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          24,
                        ), // Daha yuvarlak köşeler
                        border: Border.all(
                          color: colorScheme.primaryContainer.withOpacity(
                            0.3,
                          ), // Sınır rengi
                        ),
                      ),
                      child: Column(
                        children: [
                          // Emoji ve Düzenleme
                          Stack(
                            clipBehavior:
                                Clip.none, // Butonun dışarı taşması için
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  // color: colorScheme.primary.withOpacity(0.1), // Arka plan kaldırıldı
                                  shape: BoxShape.circle, // Yuvarlak yapıldı
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    width: 3,
                                  ),
                                ),
                                child: Text(
                                  _emoji,
                                  style: const TextStyle(
                                    fontSize: 56,
                                  ), // Boyut büyütüldü
                                ),
                              ),
                              Positioned(
                                bottom: -5, // Biraz aşağıya
                                right: -5, // Biraz sağa
                                child: Material(
                                  // Tıklama efekti için Material
                                  color: colorScheme.primary,
                                  shape: const CircleBorder(),
                                  elevation: 2, // Hafif gölge
                                  child: InkWell(
                                    // Tıklama efekti
                                    customBorder: const CircleBorder(),
                                    onTap: _showEmojiPicker,
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        8,
                                      ), // İç boşluk
                                      child: Icon(
                                        Icons.edit_rounded,
                                        color: colorScheme.onPrimary,
                                        size: 18, // Boyut ayarlandı
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Kullanıcı Adı ve Düzenleme İkonu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                // Uzun isimler için
                                child: Text(
                                  _kullaniciAdi,
                                  style: textTheme.headlineMedium?.copyWith(
                                    // Boyut ayarlandı
                                    fontWeight:
                                        FontWeight.bold, // Kalın yapıldı
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow
                                      .ellipsis, // Taşarsa ... koysun
                                ),
                              ),
                              IconButton(
                                // Kullanıcı adı düzenleme butonu
                                icon: Icon(
                                  Icons.edit_note_rounded,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                                onPressed: _showEditUsernameDialog,
                                tooltip: 'Kullanıcı adını düzenle',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4), // Boşluk azaltıldı
                          // E-posta
                          Text(
                            _email,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant, // Daha uygun renk
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Puan ve Liderlik Sırası (Ayrı Kartlarda)
                          Row(
                            children: [
                              Expanded(
                                // Puan Kartı
                                child: _buildStatCard(
                                  icon: Icons.star_rounded,
                                  iconColor: Colors.amber.shade600,
                                  label: 'Toplam Puan',
                                  value: '$_toplamPuan',
                                  context: context,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                // Sıralama Kartı
                                child: _buildStatCard(
                                  icon: Icons.leaderboard_rounded,
                                  iconColor:
                                      colorScheme.tertiary, // Farklı renk
                                  label: 'Genel Sıralama',
                                  value: _liderlikSirasi > 0
                                      ? '#$_liderlikSirasi'
                                      : '-', // Bulunamadıysa -
                                  context: context,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // --- Profil Kartı Bitti ---
                    const SizedBox(height: 32),

                    // --- Butonlar (Görünüm İyileştirildi) ---
                    _buildNavigationButton(
                      icon: Icons.history_rounded,
                      title: 'Test Geçmişim',
                      subtitle: 'Çözdüğüm testleri görüntüle',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SolvedQuizzesScreen(),
                          ),
                        );
                      },
                      context: context,
                    ),
                    const SizedBox(height: 16), // Buton arası boşluk
                    // --- BAŞARILARIM BUTONU ---
                    _buildNavigationButton(
                      icon: Icons.emoji_events_rounded, // Başarı ikonu
                      title: 'Başarılarım',
                      subtitle: 'Kazandığın rozetleri görüntüle',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AchievementsScreen(),
                          ),
                        );
                      },
                      context: context,
                    ),

                    // --- BAŞARILARIM BUTONU BİTTİ ---

                    // --- Butonlar Bitti ---
                    const SizedBox(height: 24), // Alt boşluk
                    Padding(
                      // Emoji açıklama yazısı
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Emojiyi veya kullanıcı adını değiştirmek için düzenleme ikonlarına tıklayın.', // Yazı güncellendi
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant, // Renk ayarlandı
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 100), // En alta boşluk (Scroll için)
                  ],
                ),
              ),
            ),
    );
  }

  // --- YENİ YARDIMCI WIDGET: Puan/Sıralama Kartı ---
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5), // Hafif arka plan
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min, // İçeriğe göre boyutlan
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  // Daha küçük etiket
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              // Değer daha büyük
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // --- YENİ YARDIMCI WIDGET: Geçmiş/Başarı Butonu ---
  Widget _buildNavigationButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // color: colorScheme.surface, // Arka plan kaldırıldı
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(
            0.5,
          ), // Daha belirgin sınır
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ), // Padding ayarlandı
            child: Row(
              children: [
                Container(
                  // İkon Arka Planı
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer, // Tema rengi
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.onSecondaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          // Boyut ayarlandı
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2), // Boşluk azaltıldı
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          // Daha küçük alt başlık
                          color: colorScheme.onSurfaceVariant, // Renk ayarlandı
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurfaceVariant.withOpacity(
                    0.6,
                  ), // Renk ayarlandı
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
