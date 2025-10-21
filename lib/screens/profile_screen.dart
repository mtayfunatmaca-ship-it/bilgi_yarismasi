import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/solved_quizzes_screen.dart';
import 'package:bilgi_yarismasi/screens/achievements_screen.dart';
import 'package:bilgi_yarismasi/screens/statistics_screen.dart';
import 'package:provider/provider.dart'; // Tema için
import 'package:bilgi_yarismasi/services/theme_notifier.dart'; // Tema için

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  String _email = '';
  String _kullaniciAdi = '';
  String _emoji = '🙂';
  int _toplamPuan = 0;
  int _liderlikSirasi = 0;

  bool _isLoading = true;
  bool _isSaving = false;

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
  ];

  late AnimationController _animationController;
  late AnimationController _profileAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _profileScaleAnimation;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _profileAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _profileScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _profileAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _profileAnimationController.dispose();
    super.dispose();
  }

  // --- Emoji Seçici ---
  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profil Emojisi Seç',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: _availableEmojis.length,
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
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                      .withOpacity(0.6)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Emoji Kaydetme ---
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
          SnackBar(
            content: const Text('Profil emojisi güncellendi!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    } catch (e) {
      print("Emoji kaydetme hatası: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: Emoji güncellenemedi.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Kullanıcı Verisi Yükleme ---
  Future<void> _loadUserData() async {
    if (!mounted) return;
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pop();
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
        _authService.signOut();
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final toplamPuan = (data['toplamPuan'] as num? ?? 0).toInt();

      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('toplamPuan', descending: true)
          .limit(500)
          .get();
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

      setState(() {
        _email = data['email'] ?? 'E-posta yok';
        _kullaniciAdi = data['kullaniciAdi'] ?? 'İsimsiz';
        _emoji = data['emoji'] ?? '🙂';
        _toplamPuan = toplamPuan;
        _liderlikSirasi = sirasi;
        _isLoading = false;
      });

      _animationController.forward();
      _profileAnimationController.forward();
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // --- Kullanıcı Adı Düzenleme Dialog ---
  void _showEditUsernameDialog() {
    final TextEditingController usernameController = TextEditingController(
      text: _kullaniciAdi,
    );
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? errorText;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Kullanıcı Adını Düzenle'),
              content: TextField(
                controller: usernameController,
                maxLength: 15,
                decoration: InputDecoration(
                  hintText: "Yeni kullanıcı adı",
                  counterText: "",
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                autofocus: true,
                onChanged: (value) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newUsername = usernameController.text.trim();
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
                      Navigator.pop(context);
                      return;
                    }
                    Navigator.pop(context);
                    _saveUsername(newUsername);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Kullanıcı Adı Kaydetme ---
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
        'kullaniciAdi': newUsername,
      });
      if (mounted) {
        setState(() {
          _kullaniciAdi = newUsername;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kullanıcı adı güncellendi!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // === build METODU (Tam Kod) ===
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Profilim',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.logout_rounded, color: colorScheme.error),
              tooltip: 'Çıkış Yap',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('Çıkış Yap'),
                    content: const Text(
                      'Çıkış yapmak istediğinizden emin misiniz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('İptal'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _authService.signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Çıkış Yap'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Profil Yükleniyor...',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadUserData,
              color: colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Profil Kartı
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withOpacity(0.8),
                                colorScheme.secondary.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ScaleTransition(
                                scale: _profileScaleAnimation,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colorScheme.onPrimary
                                              .withOpacity(0.5),
                                          width: 3,
                                        ),
                                        color: colorScheme.onPrimary,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _emoji,
                                        style: const TextStyle(fontSize: 48),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -5,
                                      right: -5,
                                      child: GestureDetector(
                                        onTap: _showEmojiPicker,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: colorScheme.onPrimary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.edit_rounded,
                                            color: colorScheme.primary,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _kullaniciAdi,
                                      style: textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimary,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _showEditUsernameDialog,
                                    child: Icon(
                                      Icons.edit_note_rounded,
                                      size: 24,
                                      color: colorScheme.onPrimary.withOpacity(
                                        0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _email,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimary.withOpacity(0.9),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.star_rounded,
                                      iconColor: Colors.amber,
                                      label: 'Toplam Puan',
                                      value: '$_toplamPuan',
                                      context: context,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.leaderboard_rounded,
                                      iconColor: colorScheme.onPrimary,
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
                      ),
                      const SizedBox(height: 32),

                      // Navigasyon Başlığı
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 16.0,
                          ),
                          child: Text(
                            'Hızlı Erişim',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Navigasyon Butonları
                      _buildModernNavigationButton(
                        icon: Icons.history_rounded,
                        title: 'Test Geçmişim',
                        subtitle: 'Çözdüğüm testleri görüntüle',
                        color: colorScheme.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SolvedQuizzesScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModernNavigationButton(
                        icon: Icons.emoji_events_rounded,
                        title: 'Başarılarım',
                        subtitle: 'Kazandığın rozetleri görüntüle',
                        color: Colors.amber.shade700, // Renk ayarlandı
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AchievementsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- İSTATİSTİKLERİM BUTONU (EKLENDİ) ---
                      _buildModernNavigationButton(
                        icon: Icons.bar_chart_rounded,
                        title: 'İstatistiklerim',
                        subtitle: 'Detaylı performans analizini gör',
                        color: Colors.teal.shade600, // Renk ayarlandı
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StatisticsScreen(),
                            ),
                          );
                        },
                      ),

                      // --- İSTATİSTİK BUTONU BİTTİ ---
                      const SizedBox(height: 32),

                      // --- TEMA RENGİ SEÇİMİ (EKLENDİ) ---
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 16.0,
                          ),
                          child: Text(
                            'Tema Rengi',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: GridView.count(
                          crossAxisCount: 6,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            _buildColorChoice(
                              context,
                              const Color.fromARGB(255, 243, 100, 33),
                            ), // Turuncu
                            _buildColorChoice(
                              context,
                              Colors.blue.shade600,
                            ), // Mavi
                            _buildColorChoice(
                              context,
                              Colors.green.shade600,
                            ), // Yeşil
                            _buildColorChoice(
                              context,
                              Colors.purple.shade600,
                            ), // Mor
                            _buildColorChoice(
                              context,
                              Colors.red.shade600,
                            ), // Kırmızı
                            _buildColorChoice(
                              context,
                              Colors.teal.shade600,
                            ), // Turkuaz
                          ],
                        ),
                      ),

                      // --- TEMA SEÇİMİ BİTTİ ---
                      const SizedBox(height: 32), // Aralık ayarlandı
                      // Bilgilendirme Metni
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Emojiyi veya kullanıcı adını değiştirmek için düzenleme ikonlarına tıklayın.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onPrimary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Yardımcı Widget: Navigasyon Butonu (Tam Kod)
  Widget _buildModernNavigationButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surface, // Düz renk
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ), // Renkli kenarlık
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1), // Renkli gölge
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TEMA SEÇİMİ İÇİN YENİ YARDIMCI WIDGET (Tam Kod) ---
  Widget _buildColorChoice(BuildContext context, Color color) {
    // Notifier'ı dinleyerek mevcut seçili rengi al
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isSelected = themeNotifier.seedColor.value == color.value;

    return Tooltip(
      message: 'Bu temayı seç',
      child: GestureDetector(
        onTap: () {
          // Tıklandığında rengi güncelle
          Provider.of<ThemeNotifier>(
            context,
            listen: false,
          ).setThemeColor(color);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 4 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                    ),
                  ],
          ),
          child: isSelected
              ? Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.surface,
                  size: 24,
                )
              : null,
        ),
      ),
    );
  }
}
