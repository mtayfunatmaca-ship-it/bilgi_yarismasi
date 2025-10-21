import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/solved_quizzes_screen.dart';
import 'package:bilgi_yarismasi/screens/achievements_screen.dart';
import 'package:bilgi_yarismasi/screens/statistics_screen.dart'; // <<< İSTATİSTİK IMPORT'U

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
  bool _isSaving = false; // Emoji veya kullanıcı adı kaydetme durumu için

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
    '🤩',
    '🥳',
    '🤯',
    '🤔',
    '🚀',
    '⭐',
    '💡',
    '📚',
    '🧠',
    '🎓',
    '🦉',
    '🦊',
  ]; // Daha fazla emoji eklendi

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- Emoji Picker ---
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
            mainAxisSize: MainAxisSize.min, // İçeriğe göre boyutlan
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Profil Emojisi Seç',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    // Boyut büyütüldü
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ), // Ayırıcı
              // Emoji Grid'i
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GridView.builder(
                  // Builder kullanmak daha verimli
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, // Sütun sayısı
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _availableEmojis.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final emoji = _availableEmojis[index];
                    bool isSelected = (_emoji == emoji);
                    return GestureDetector(
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _emoji = emoji;
                        });
                        _saveEmoji();
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        // Seçim animasyonu
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            16,
                          ), // Daha yuvarlak
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                                    .withOpacity(0.6) // Seçili rengi
                              : Theme.of(context).colorScheme.surfaceVariant
                                    .withOpacity(0.3), // Normal renk
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ) // Seçili kenarlık
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 32),
                          ), // Boyut ayarlandı
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16), // Alt boşluk
            ],
          ),
        );
      },
    );
  }

  // Emoji kaydetme (Aynı)
  Future<void> _saveEmoji() async {
    if (_isSaving || !mounted) return;
    setState(() => _isSaving = true);
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'emoji': _emoji,
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil emojisi güncellendi!'),
            duration: Duration(seconds: 2),
          ),
        );
    } catch (e) {
      print("Emoji kaydetme hatası: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: Emoji güncellenemedi.'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Kullanıcı verilerini ve liderlik sırasını yükleme (Aynı)
  Future<void> _loadUserData() async {
    if (!mounted) return;
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pop(); // Geri git
      return;
    }
    if (mounted)
      setState(() {
        _isLoading = true;
      });
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;
      if (!doc.exists) {
        print("Kullanıcı belgesi bulunamadı: ${user.uid}");
        setState(() {
          _isLoading = false;
        });
        // Belki kullanıcıyı çıkışa zorlamak veya hata göstermek daha iyi olur
        _authService.signOut(); // Belge yoksa çıkış yap
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final toplamPuan = (data['toplamPuan'] as num? ?? 0).toInt();

      // Liderlik sırası (limit ekleyerek optimize edilebilir)
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('toplamPuan', descending: true)
          .limit(500)
          .get(); // İlk 500'e bak
      if (!mounted) return;
      int sirasi = -1;
      int currentRank = 1;
      for (var userDoc in querySnapshot.docs) {
        if (userDoc.id == user.uid) {
          sirasi = currentRank;
          break;
        }
        currentRank++;
      }
      // Eğer ilk 500'de değilse -1 kalacak

      setState(() {
        _email = data['email'] ?? 'E-posta yok';
        _kullaniciAdi = data['kullaniciAdi'] ?? 'İsimsiz';
        _emoji = data['emoji'] ?? '🙂';
        _toplamPuan = toplamPuan;
        _liderlikSirasi = sirasi;
        _isLoading = false;
      });
    } catch (e) {
      print("Profil verisi yüklenirken hata: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil verileri yüklenemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Kullanıcı adını düzenleme Dialog'u
  void _showEditUsernameDialog() {
    final TextEditingController usernameController = TextEditingController(
      text: _kullaniciAdi,
    );
    showDialog(
      context: context,
      builder: (context) {
        // Dialog içeriği state tutabilsin diye StatefulWidget
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? errorText; // Hata mesajı için
            return AlertDialog(
              title: const Text('Kullanıcı Adını Düzenle'),
              content: TextField(
                controller: usernameController,
                maxLength: 15, // Max uzunluk eklendi
                decoration: InputDecoration(
                  hintText: "Yeni kullanıcı adı",
                  counterText: "", // Sayacı gizle
                  errorText: errorText, // Hata mesajını göster
                ),
                autofocus: true,
                onChanged: (value) {
                  // Yazarken hatayı temizle
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () {
                    final newUsername = usernameController.text.trim();
                    // Doğrulama
                    if (newUsername.isEmpty) {
                      setDialogState(
                        () => errorText = 'Kullanıcı adı boş olamaz.',
                      );
                      return;
                    }
                    if (newUsername.length > 15) {
                      setDialogState(
                        () => errorText = 'Maksimum 15 karakter olabilir.',
                      );
                      return;
                    }
                    if (newUsername == _kullaniciAdi) {
                      Navigator.pop(context); // Değişiklik yoksa kapat
                      return;
                    }

                    Navigator.pop(context); // Dialog'u kapat
                    _saveUsername(newUsername); // Yeni adı kaydet
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Kullanıcı adını kaydetme
  Future<void> _saveUsername(String newUsername) async {
    if (_isSaving || !mounted) return;
    setState(() => _isSaving = true); // Kaydetme başladı (UI'da gösterilebilir)
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'kullaniciAdi': newUsername,
      });
      if (mounted) {
        setState(() {
          _kullaniciAdi = newUsername;
        }); // State'i anında güncelle
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı adı güncellendi!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Kullanıcı adı kaydetme hatası: $e");
      String errorMsg = 'Kullanıcı adı güncellenemedi.';
      if (e is FirebaseException && e.code == 'permission-denied')
        errorMsg = 'İzniniz yok.';
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false); // Kaydetme bitti
    }
  }

  // === build METODU ===
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        // AppBar (Tam Kod)
        title: Text(
          'Profilim',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ), // Stil güncellendi
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            // Çıkış Yap Butonu (Tam Kod)
            icon: Icon(
              Icons.logout_rounded,
              color: colorScheme.error,
            ), // İkon değişti
            tooltip: 'Çıkış Yap',
            onPressed: () {
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
                        Navigator.pop(ctx);
                        _authService.signOut();
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
              onRefresh: _loadUserData,
              color: colorScheme.primary, // Indicator rengi
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0), // Padding azaltıldı
                child: Column(
                  children: [
                    // Profil Kartı (Tam Kod)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 28,
                      ), // Padding ayarlandı
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.6),
                            colorScheme.primaryContainer.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.primaryContainer.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Emoji ve Düzenleme Butonu (Tam Kod)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  20,
                                ), // Padding azaltıldı
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.5),
                                    width: 3,
                                  ),
                                  color:
                                      colorScheme.surface, // Arka plan eklendi
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ], // Gölge
                                ),
                                child: Text(
                                  _emoji,
                                  style: const TextStyle(fontSize: 48),
                                ), // Boyut küçültüldü
                              ),
                              Positioned(
                                bottom: -8,
                                right: -8,
                                child: Material(
                                  color: colorScheme.primary,
                                  shape: const CircleBorder(),
                                  elevation: 3,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _showEmojiPicker,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.edit_rounded,
                                        color: colorScheme.onPrimary,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20), // Boşluk azaltıldı
                          // Kullanıcı Adı ve Düzenleme Butonu (Tam Kod)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _kullaniciAdi,
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_note_rounded,
                                  size: 24,
                                  color: colorScheme.primary.withOpacity(0.8),
                                ), // Boyut/Renk ayarlandı
                                onPressed: _showEditUsernameDialog,
                                tooltip: 'Kullanıcı adını düzenle',
                                splashRadius: 20, // Tıklama efekti alanı
                              ),
                            ],
                          ),
                          const SizedBox(height: 2), // Boşluk azaltıldı
                          // E-posta (Tam Kod)
                          Text(
                            _email,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20), // Boşluk azaltıldı
                          // Puan ve Sıralama Kartları (Tam Kod)
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.star_rounded,
                                  iconColor: Colors.amber.shade600,
                                  label: 'Toplam Puan',
                                  value: '$_toplamPuan',
                                  context: context,
                                ),
                              ),
                              const SizedBox(width: 12), // Boşluk azaltıldı
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.leaderboard_rounded,
                                  iconColor: colorScheme.tertiary,
                                  label: 'Genel Sıralama',
                                  value: _liderlikSirasi > 0
                                      ? '#$_liderlikSirasi'
                                      : '-',
                                  context: context,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28), // Boşluk azaltıldı
                    // --- NAVİGASYON BUTONLARI (Tam Kod) ---
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
                    const SizedBox(height: 12), // Boşluk azaltıldı
                    _buildNavigationButton(
                      icon: Icons.emoji_events_rounded,
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
                    const SizedBox(height: 12), // Boşluk azaltıldı
                    _buildNavigationButton(
                      icon: Icons.bar_chart_rounded,
                      title: 'İstatistiklerim',
                      subtitle: 'Detaylı performans analizini gör',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StatisticsScreen(),
                          ),
                        );
                      },
                      context: context,
                    ),

                    // --- NAVİGASYON BUTONLARI BİTTİ ---
                    const SizedBox(height: 20), // Boşluk azaltıldı
                    // Emoji/Ad değiştirme yazısı (Tam Kod)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Emojiyi veya kullanıcı adını değiştirmek için düzenleme ikonlarına tıklayın.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 80), // En alta boşluk azaltıldı
                  ],
                ),
              ),
            ),
    );
  }

  // Yardımcı Widget: Puan/Sıralama Kartı (Tam Kod)
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
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ), // Padding azaltıldı
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 18), // Boyut küçültüldü
              const SizedBox(width: 6), // Boşluk azaltıldı
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ), // Boyut küçültüldü
        ],
      ),
    );
  }

  // Yardımcı Widget: Geçmiş/Başarı/İstatistik Butonu (Tam Kod)
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
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ), // Padding azaltıldı
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ), // Padding azaltıldı
                  child: Icon(
                    icon,
                    color: colorScheme.onSecondaryContainer,
                    size: 22,
                  ),
                ), // Boyut azaltıldı
                const SizedBox(width: 12), // Boşluk azaltıldı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ), // Boyut küçültüldü
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  size: 16,
                ), // Boyut azaltıldı
              ],
            ),
          ),
        ),
      ),
    );
  }
} // _ProfileScreenState sonu
