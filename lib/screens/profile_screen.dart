import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/solved_quizzes_screen.dart';
import 'package:bilgi_yarismasi/screens/achievements_screen.dart';
import 'package:bilgi_yarismasi/screens/statistics_screen.dart';
import 'package:provider/provider.dart';
import 'package:bilgi_yarismasi/services/theme_notifier.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // State değişkenleri
  int _liderlikSirasi = -1;
  bool _isRankLoading = false;
  bool _isSaving = false; // Kaydetme durumu (emoji, ad/soyad, şifre)

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

  // Animasyon controller'ları
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

    _animationController.forward();
    _profileAnimationController.forward();

    if (_currentUserId != null) {
      _loadUserRank(); // Liderlik sırasını ayrı yükle
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _profileAnimationController.dispose();
    super.dispose();
  }

  // Sadece liderlik sırasını hesaplayan fonksiyon
  Future<void> _loadUserRank() async {
    if (!mounted || _currentUserId == null || _isRankLoading) return;
    setState(() => _isRankLoading = true);

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('toplamPuan', descending: true)
          .limit(500)
          .get();
      if (!mounted) return;
      int sirasi = -1;
      int currentRank = 1;
      for (var userDoc in querySnapshot.docs) {
        if (userDoc.id == _currentUserId) {
          sirasi = currentRank;
          break;
        }
        currentRank++;
      }
      setState(() {
        _liderlikSirasi = sirasi;
        _isRankLoading = false;
      });
    } catch (e) {
      print("Sıralama yüklenirken hata: $e");
      if (mounted) setState(() => _isRankLoading = false);
    }
  }

  // Emoji seçici
  void _showEmojiPicker(String currentEmoji) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String selectedEmoji = currentEmoji;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                          bool isSelected = (selectedEmoji == emoji);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedEmoji = emoji;
                              });
                              _saveEmoji(selectedEmoji);
                              Future.delayed(
                                const Duration(milliseconds: 200),
                                () {
                                  if (mounted) Navigator.pop(context);
                                },
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isSelected
                                    ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.6)
                                    : Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant
                                          .withOpacity(0.3),
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.3),
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
      },
    );
  }

  // Emoji kaydetme
  Future<void> _saveEmoji(String newEmoji) async {
    if (_isSaving || !mounted) return;
    setState(() => _isSaving = true);
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'emoji': newEmoji,
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

  // --- GÜNCELLENDİ: Ad/Soyad/Kullanıcı Adı düzenleme Dialog ---
  void _showEditInfoDialog(
    String currentUsername,
    String currentAd,
    String currentSoyad,
  ) {
    final TextEditingController usernameController = TextEditingController(
      text: currentUsername,
    );
    final TextEditingController adController = TextEditingController(
      text: currentAd,
    );
    final TextEditingController soyadController = TextEditingController(
      text: currentSoyad,
    );
    final _formKey = GlobalKey<FormState>();
    bool isDialogSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? dialogError; // Hata mesajı için

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Bilgileri Düzenle'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: adController,
                      decoration: InputDecoration(
                        labelText: 'Ad',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Ad boş olamaz.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: soyadController,
                      decoration: InputDecoration(
                        labelText: 'Soyad',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Soyad boş olamaz.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController,
                      maxLength: 15,
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        prefixIcon: Icon(Icons.alternate_email),
                        counterText: "",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: dialogError, // Hata mesajını göster
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Kullanıcı adı boş olamaz.';
                        if (value.length > 15)
                          return 'Maksimum 15 karakter olabilir.';
                        return null;
                      },
                      onChanged: (_) {
                        if (dialogError != null)
                          setDialogState(() => dialogError = null);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isDialogSaving
                      ? null
                      : () async {
                          if (!(_formKey.currentState?.validate() ?? false))
                            return;

                          final newUsername = usernameController.text.trim();
                          final newAd = adController.text.trim();
                          final newSoyad = soyadController.text.trim();

                          if (newUsername == currentUsername &&
                              newAd == currentAd &&
                              newSoyad == currentSoyad) {
                            Navigator.pop(context);
                            return;
                          }

                          setDialogState(() {
                            isDialogSaving = true;
                            dialogError = null;
                          });

                          final String? saveError = await _saveUserInfo(
                            newUsername,
                            currentUsername,
                            newAd,
                            newSoyad,
                          );

                          if (!mounted) return;
                          setDialogState(() => isDialogSaving = false);

                          if (saveError == null) {
                            Navigator.pop(context);
                          } else {
                            // Hata "alınmış" ise dialogda göster, değilse SnackBar'da
                            if (saveError.contains('alınmış')) {
                              setDialogState(() => dialogError = saveError);
                            } else {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(saveError),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isDialogSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- GÜNCELLENDİ: Ad/Soyad/Kullanıcı Adı kaydetme ---
  Future<String?> _saveUserInfo(
    String newUsername,
    String currentUsername,
    String newAd,
    String newSoyad,
  ) async {
    final user = _authService.currentUser;
    if (user == null) return "Kullanıcı bulunamadı.";

    setState(() => _isSaving = true); // Ana ekran state'ini kilitle

    try {
      // Sadece kullanıcı adı değiştiyse çakışma kontrolü yap
      if (newUsername != currentUsername) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('kullaniciAdi', isEqualTo: newUsername)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          print("Kullanıcı adı çakışması: $newUsername zaten alınmış.");
          return 'Bu kullanıcı adı zaten alınmış.'; // <<< HATA DÖNDÜR
        }
      }

      // Kullanıcı adı müsaitse veya değişmediyse tüm verileri güncelle
      await _firestore.collection('users').doc(user.uid).update({
        'kullaniciAdi': newUsername,
        'ad': newAd,
        'soyad': newSoyad,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bilgiler güncellendi!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return null; // Başarılı
    } catch (e) {
      print("Kullanıcı bilgileri kaydetme hatası: $e");
      String errorMsg = 'Bilgiler güncellenemedi.';
      if (e is FirebaseException && e.code == 'permission-denied')
        errorMsg = 'İzniniz yok.';
      return errorMsg;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Şifre Değiştirme Dialog'u ---
  void _showChangePasswordDialog() {
    final _passwordFormKey = GlobalKey<FormState>();
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    bool isPasswordSaving = false;
    String dialogError = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Şifre Değiştir'),
              content: Form(
                key: _passwordFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mevcut Şifre',
                        prefixIcon: Icon(Icons.lock_open),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Mevcut şifre boş olamaz.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Yeni Şifre',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Yeni şifre boş olamaz.';
                        if (value.length < 6)
                          return 'Yeni şifre en az 6 karakter olmalıdır.';
                        return null;
                      },
                    ),
                    if (dialogError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          dialogError,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isPasswordSaving
                      ? null
                      : () async {
                          if (_passwordFormKey.currentState?.validate() ??
                              false) {
                            setDialogState(() {
                              isPasswordSaving = true;
                              dialogError = '';
                            });

                            final error = await _authService.changePassword(
                              currentPasswordController.text,
                              newPasswordController.text,
                            );

                            if (!mounted) return;
                            setDialogState(() {
                              isPasswordSaving = false;
                            });

                            if (error == null) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Şifreniz başarıyla güncellendi!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              setDialogState(() {
                                dialogError = error;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isPasswordSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Değiştir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- YENİ: Ayarlar Menüsü ---
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              // Başlık
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ayarlar',
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
              const Divider(height: 1),

              // İçerik
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    // Şifre Değiştir
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      title: const Text('Şifre Değiştir'),
                      subtitle: const Text('Giriş şifreni güvenle güncelle'),
                      onTap: () {
                        Navigator.pop(context);
                        // Sadece e-posta ile giriş yapanlar şifre değiştirebilir
                        final userProvider = _authService
                            .currentUser
                            ?.providerData
                            .first
                            .providerId;
                        if (userProvider == 'password') {
                          _showChangePasswordDialog();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Google ile giriş yaptığınız için şifre değiştiremezsiniz.',
                              ),
                              backgroundColor: Colors.orange.shade800,
                            ),
                          );
                        }
                      },
                    ),

                    // Tema Rengi
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.palette_rounded,
                          color: Colors.purple.shade600,
                        ),
                      ),
                      title: const Text('Tema Rengi'),
                      subtitle: const Text('Uygulama görünümünü kişiselleştir'),
                      onTap: () {
                        Navigator.pop(context);
                        _showThemeSelector();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- YENİ: Tema Seçici ---
  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              // Başlık
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tema Rengi',
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
              const Divider(height: 1),

              // Renk Seçenekleri
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildColorChoice(
                        context,
                        const Color.fromARGB(255, 243, 100, 33),
                        'Turuncu',
                      ), // Turuncu
                      _buildColorChoice(
                        context,
                        Colors.blue.shade600,
                        'Mavi',
                      ), // Mavi
                      _buildColorChoice(
                        context,
                        Colors.green.shade600,
                        'Yeşil',
                      ), // Yeşil
                      _buildColorChoice(
                        context,
                        Colors.purple.shade600,
                        'Mor',
                      ), // Mor
                      _buildColorChoice(
                        context,
                        Colors.red.shade600,
                        'Kırmızı',
                      ), // Kırmızı
                      _buildColorChoice(
                        context,
                        Colors.teal.shade600,
                        'Turkuaz',
                      ), // Turkuaz
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // --- Fonksiyonlar Bitti ---

  // === build METODU (StreamBuilder ile) ===
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
          // Ayarlar Butonu
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.settings_rounded, color: colorScheme.primary),
              tooltip: 'Ayarlar',
              onPressed: _showSettingsMenu,
            ),
          ),
          // Çıkış Butonu
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
      body: _currentUserId == null
          ? const Center(child: Text("Kullanıcı bulunamadı."))
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
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
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Hata: Profil verisi okunamadı. ${snapshot.error}",
                    ),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: Text("Kullanıcı verisi bekleniyor..."),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final String email = data['email'] ?? 'E-posta yok';
                final String kullaniciAdi = data['kullaniciAdi'] ?? 'İsimsiz';
                final String ad = data['ad'] ?? '';
                final String soyad = data['soyad'] ?? '';
                final String emoji = data['emoji'] ?? '🙂';
                final int toplamPuan = (data['toplamPuan'] as num? ?? 0)
                    .toInt();

                if (_liderlikSirasi == -1 && !_isRankLoading) {
                  Future.microtask(() => _loadUserRank());
                }

                _animationController.forward();
                _profileAnimationController.forward();

                return RefreshIndicator(
                  onRefresh: _loadUserRank,
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
                                            emoji,
                                            style: const TextStyle(
                                              fontSize: 48,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: -5,
                                          right: -5,
                                          child: GestureDetector(
                                            onTap: () =>
                                                _showEmojiPicker(emoji),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: colorScheme.onPrimary,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
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
                                          '$ad $soyad',
                                          style: textTheme.headlineMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onPrimary,
                                              ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _showEditInfoDialog(
                                          kullaniciAdi,
                                          ad,
                                          soyad,
                                        ), // <<< GÜNCELLENDİ
                                        child: Icon(
                                          Icons.edit_note_rounded,
                                          size: 24,
                                          color: colorScheme.onPrimary
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "@$kullaniciAdi",
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onPrimary.withOpacity(
                                        0.9,
                                      ),
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
                                          label: 'Genel Puan',
                                          value: NumberFormat.decimalPattern(
                                            'tr',
                                          ).format(toplamPuan),
                                          context: context,
                                        ),
                                      ), // 'Genel Puan'
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildStatCard(
                                          icon: Icons.leaderboard_rounded,
                                          iconColor: colorScheme.onPrimary,
                                          label: 'Genel Sıralama',
                                          value: _isRankLoading
                                              ? '...'
                                              : (_liderlikSirasi > 0
                                                    ? '#$_liderlikSirasi'
                                                    : '-'),
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
                            color: Colors.amber.shade700,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AchievementsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildModernNavigationButton(
                            icon: Icons.bar_chart_rounded,
                            title: 'İstatistiklerim',
                            subtitle: 'Detaylı performans analizini gör',
                            color: Colors.teal.shade600,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StatisticsScreen(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Bilgilendirme Metni
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(
                                0.3,
                              ),
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
                                    'Emoji veya bilgilerinizi düzenlemek için kalem ikonlarına tıklayın. Şifre değiştirme ve tema ayarları için üstteki ayarlar ikonunu kullanın.',
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
                );
              },
            ),
    );
  }

  // Yardımcı Widget: Puan/Sıralama Kartı
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

  // Yardımcı Widget: Navigasyon Butonu
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
        color: colorScheme.surface,
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
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

  // Tema Seçim Widget'ı
  Widget _buildColorChoice(
    BuildContext context,
    Color color,
    String colorName,
  ) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isSelected = themeNotifier.seedColor.value == color.value;
    return Tooltip(
      message: colorName,
      child: GestureDetector(
        onTap: () {
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
