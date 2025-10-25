import 'package:bilgi_yarismasi/screens/achievements_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
import 'package:bilgi_yarismasi/screens/statistics_screen.dart';
import 'package:provider/provider.dart';
import 'package:bilgi_yarismasi/services/theme_notifier.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui' as ui; // <<< FLULAŞTIRMA (BLUR) İÇİN EKLENDİ

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
  bool _isSaving = false;

  // Başarılar (Rozetler) için state'ler
  List<QueryDocumentSnapshot> _allAchievements = [];
  Map<String, dynamic> _earnedAchievements = {};
  bool _isLoadingAchievements = true;
  late AnimationController _shimmerController;
  late List<AnimationController> _badgeAnimationControllers = [];
  late List<Animation<double>> _badgeAnimations = [];
  
  String? _currentUserId;

  final List<String> _availableEmojis = [
    '🙂', '😎', '🤓', '🧐', '😺', '👾', '🐱', '🐶', '🐵', '🦄', '🐸', '🐯',
    '🤩', '🥳', '🤯', '🤔', '🚀', '⭐', '💡', '📚', '🧠', '🎓', '🦉', '🦊',
  ];
  
  late AnimationController _animationController;
  late AnimationController _profileAnimationController;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;

    _animationController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _profileAnimationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _shimmerController = AnimationController(duration: const Duration(milliseconds: 2500), vsync: this); // Parlama için

    if (_currentUserId != null) {
      _refreshAllData(); // Hem profili hem başarıları yükle
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _profileAnimationController.dispose();
    _shimmerController.dispose();
    for (var controller in _badgeAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  Future<void> _refreshAllData() async {
    if (!mounted) return;
    setState(() { 
      _isRankLoading = true;
      _isLoadingAchievements = true; 
    });
    
    final rankFuture = _loadUserRank();
    final achievementsFuture = _loadAchievements();
    
    await Future.wait([rankFuture, achievementsFuture]);

    _animationController.forward();
    _profileAnimationController.forward();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    try {
      return DateFormat.yMd('tr_TR').format(timestamp.toDate());
    } catch (e) { return '?'; }
  }

  Future<void> _loadUserRank() async {
    if (!mounted || _currentUserId == null) return;
    if (!_isRankLoading) setState(() => _isRankLoading = true);
    try {
       final querySnapshot = await _firestore.collection('users').orderBy('toplamPuan', descending: true).limit(500).get();
       if (!mounted) return;
       int sirasi = -1; int currentRank = 1;
       for (var userDoc in querySnapshot.docs) {
         if (userDoc.id == _currentUserId) { sirasi = currentRank; break; }
         currentRank++;
       }
       if (mounted) {
         setState(() {
           _liderlikSirasi = sirasi;
           _isRankLoading = false;
         });
       }
    } catch (e) {
       print("Sıralama yüklenirken hata: $e");
       if (mounted) setState(() => _isRankLoading = false);
    }
  }

  Future<void> _loadAchievements() async {
    if (!mounted || _currentUserId == null) return;
    if (!_isLoadingAchievements) setState(() => _isLoadingAchievements = true);
    try {
      final results = await Future.wait([
        _firestore.collection('achievements').orderBy('name').get(),
        _firestore.collection('users').doc(_currentUserId!).collection('earnedAchievements').get(),
      ]);
      if (!mounted) return;
      final allSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final earnedSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      _allAchievements = allSnapshot.docs;
      Map<String, dynamic> earnedMap = {};
      for (var doc in earnedSnapshot.docs) { earnedMap[doc.id] = doc.data(); }
      _earnedAchievements = earnedMap;

      _allAchievements.sort((a, b) {
        final aIsEarned = _earnedAchievements.containsKey(a.id);
        final bIsEarned = _earnedAchievements.containsKey(b.id);
        if (aIsEarned && !bIsEarned) return -1;
        if (!aIsEarned && bIsEarned) return 1;
        return 0; 
      });

      for (var controller in _badgeAnimationControllers) { controller.dispose(); }
      _badgeAnimationControllers = List.generate(
        _allAchievements.length,
        (index) => AnimationController(duration: Duration(milliseconds: 600 + (index * 50)), vsync: this),
      );
      _badgeAnimations = _badgeAnimationControllers
          .map((controller) => Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut)))
          .toList();

      if (mounted) setState(() => _isLoadingAchievements = false);
      
      _shimmerController.repeat();
      for (int i = 0; i < _badgeAnimationControllers.length; i++) {
         Future.delayed(Duration(milliseconds: i * 100), () {
            if (mounted) _badgeAnimationControllers[i].forward();
         });
      }
    } catch (e) {
      print("Başarılar yüklenirken hata: $e");
      if (mounted) setState(() => _isLoadingAchievements = false);
    }
  }
  
  // Emoji Seçici
  void _showEmojiPicker(String currentEmoji) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) {
        String selectedEmoji = currentEmoji;
        return StatefulBuilder(
           builder: (BuildContext context, StateSetter setModalState) {
             return Container(
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                ),
                child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Profil Emojisi Seç', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ]),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 12, crossAxisSpacing: 12),
                          itemCount: _availableEmojis.length,
                          itemBuilder: (context, index) {
                             final emoji = _availableEmojis[index];
                             bool isSelected = (selectedEmoji == emoji);
                             return GestureDetector(
                              onTap: () {
                                 setModalState(() { selectedEmoji = emoji; });
                                 _saveEmoji(selectedEmoji); 
                                 Future.delayed(const Duration(milliseconds: 200), () {
                                    if (mounted) Navigator.pop(context);
                                 });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6) : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                  border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                                  boxShadow: isSelected ? [ BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                                ),
                                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
                              ),
                             );
                          },
                        ),
                      ),
                    ),
                ]),
             );
           }
        );
      },
    );
  }
  
  // Emoji kaydetme
  Future<void> _saveEmoji(String newEmoji) async {
    if (_isSaving || !mounted) return;
    setState(() => _isSaving = true);
    final user = _authService.currentUser;
    if (user == null) { if (mounted) setState(() => _isSaving = false); return; }
    try {
      await _firestore.collection('users').doc(user.uid).update({'emoji': newEmoji});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Profil emojisi güncellendi!'), backgroundColor: Theme.of(context).colorScheme.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    } catch (e) {
      print("Emoji kaydetme hatası: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: Emoji güncellenemedi.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Ad/Soyad/Kullanıcı Adı düzenleme Dialog
  void _showEditInfoDialog(String currentUsername, String currentAd, String currentSoyad) {
    final TextEditingController usernameController = TextEditingController(text: currentUsername);
    final TextEditingController adController = TextEditingController(text: currentAd);
    final TextEditingController soyadController = TextEditingController(text: currentSoyad);
    final _formKey = GlobalKey<FormState>();
    bool isDialogSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? dialogError;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Bilgileri Düzenle'),
              content: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                      controller: adController,
                      decoration: InputDecoration(labelText: 'Ad', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      autofocus: true, textCapitalization: TextCapitalization.words,
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Ad boş olamaz.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: soyadController,
                      decoration: InputDecoration(labelText: 'Soyad', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Soyad boş olamaz.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController, maxLength: 15,
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı Adı', prefixIcon: Icon(Icons.alternate_email), counterText: "",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        errorText: dialogError,
                      ),
                       validator: (value) {
                         if (value == null || value.trim().isEmpty) return 'Kullanıcı adı boş olamaz.';
                         if (value.length > 15) return 'Maksimum 15 karakter olabilir.';
                         return null;
                       },
                       onChanged: (_) {
                         if(dialogError != null) setDialogState(() => dialogError = null);
                       },
                    ),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                ElevatedButton(
                  onPressed: isDialogSaving ? null : () async {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    final newUsername = usernameController.text.trim();
                    final newAd = adController.text.trim();
                    final newSoyad = soyadController.text.trim();
                    if (newUsername == currentUsername && newAd == currentAd && newSoyad == currentSoyad) { Navigator.pop(context); return; }
                    setDialogState(() { isDialogSaving = true; dialogError = null; });
                    
                    final String? saveError = await _saveUserInfo(newUsername, currentUsername, newAd, newSoyad);

                    if (!mounted) return;
                    setDialogState(() => isDialogSaving = false);

                    if (saveError == null) {
                       Navigator.pop(context); 
                    } else {
                       if (saveError.contains('alınmış')) {
                         setDialogState(() => dialogError = saveError);
                       } else {
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saveError), backgroundColor: Colors.red));
                       }
                    }
                  },
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: isDialogSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Ad/Soyad/Kullanıcı Adı kaydetme
  Future<String?> _saveUserInfo(String newUsername, String currentUsername, String newAd, String newSoyad) async {
    final user = _authService.currentUser;
    if (user == null) return "Kullanıcı bulunamadı.";
    setState(() => _isSaving = true);
    try {
      if (newUsername != currentUsername) {
        final querySnapshot = await _firestore.collection('users').where('kullaniciAdi', isEqualTo: newUsername).limit(1).get();
        if (querySnapshot.docs.isNotEmpty) {
           print("Kullanıcı adı çakışması: $newUsername zaten alınmış.");
           return 'Bu kullanıcı adı zaten alınmış.';
        }
      }
      await _firestore.collection('users').doc(user.uid).update({
        'kullaniciAdi': newUsername,
        'ad': newAd,
        'soyad': newSoyad,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Bilgiler güncellendi!'), backgroundColor: Theme.of(context).colorScheme.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
      return null;
    } catch (e) {
      print("Kullanıcı bilgileri kaydetme hatası: $e");
      String errorMsg = 'Bilgiler güncellenemedi.';
      if (e is FirebaseException && e.code == 'permission-denied') errorMsg = 'İzniniz yok.';
      return errorMsg;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Şifre Değiştirme Dialog'u (Doğrulama Eklendi)
  void _showChangePasswordDialog() {
     final _passwordFormKey = GlobalKey<FormState>();
     final TextEditingController currentPasswordController = TextEditingController();
     final TextEditingController newPasswordController = TextEditingController();
     final TextEditingController newPasswordRepeatController = TextEditingController();
     bool isPasswordSaving = false;
     String dialogError = '';

     showDialog(
      context: context,
      builder: (context) {
         return StatefulBuilder(
           builder: (context, setDialogState) {
             return AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
               title: const Text('Şifre Değiştir'),
               content: Form(
                 key: _passwordFormKey,
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'Mevcut Şifre', prefixIcon: Icon(Icons.lock_open), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (value) => (value == null || value.isEmpty) ? 'Mevcut şifre boş olamaz.' : null,
                      ),
                      const SizedBox(height: 12),
                       TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'Yeni Şifre', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (value) {
                           if (value == null || value.isEmpty) return 'Yeni şifre boş olamaz.';
                           if (value.length < 6) return 'Yeni şifre en az 6 karakter olmalıdır.';
                           return null;
                        },
                      ),
                      const SizedBox(height: 12),
                       TextFormField(
                        controller: newPasswordRepeatController,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'Yeni Şifre Tekrar', prefixIcon: Icon(Icons.lock_reset_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (value) {
                           if (value == null || value.isEmpty) return 'Tekrar alanı boş olamaz.';
                           if (value != newPasswordController.text) return 'Yeni şifreler eşleşmiyor.';
                           return null;
                        },
                      ),
                      if(dialogError.isNotEmpty)
                         Padding(
                           padding: const EdgeInsets.only(top: 12.0),
                           child: Text(dialogError, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                         ),
                   ],
                 ),
               ),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                 ElevatedButton(
                   onPressed: isPasswordSaving ? null : () async {
                      if (_passwordFormKey.currentState?.validate() ?? false) {
                         setDialogState(() { isPasswordSaving = true; dialogError = ''; });
                         
                         final error = await _authService.changePassword(
                           currentPasswordController.text,
                           newPasswordController.text
                         );
                         
                         if (!mounted) return;
                         setDialogState(() { isPasswordSaving = false; });

                         if (error == null) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Şifreniz başarıyla güncellendi!'), backgroundColor: Colors.green),
                            );
                         } else {
                            setDialogState(() { dialogError = error; });
                         }
                      }
                   },
                   style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                   child: isPasswordSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Değiştir'),
                 )
               ],
             );
           },
         );
      },
     );
  }
  
  // Tema Seçim Dialog'u
  void _showThemePicker(BuildContext context, ColorScheme colorScheme) {
     showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tema Rengi Seç', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _buildColorChoice(context, const Color.fromARGB(255, 243, 100, 33), 'Varsayılan Turuncu'),
                  _buildColorChoice(context, Colors.blue.shade600, 'Mavi'),
                  _buildColorChoice(context, Colors.green.shade600, 'Yeşil'),
                  _buildColorChoice(context, Colors.purple.shade600, 'Mor'),
                  _buildColorChoice(context, Colors.red.shade600, 'Kırmızı'),
                  _buildColorChoice(context, Colors.teal.shade600, 'Turkuaz'),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }
  
  // Ayarlar Menüsü (Çıkış Butonu Burada)
  void _showSettingsMenu(BuildContext context, ColorScheme colorScheme, bool isGoogleUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                 width: 40, height: 4,
                 decoration: BoxDecoration(color: colorScheme.outline.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text("Ayarlar", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              if (!isGoogleUser)
                ListTile(
                  leading: Icon(Icons.lock_reset_rounded, color: colorScheme.secondary),
                  title: Text('Şifre Değiştir', style: Theme.of(context).textTheme.bodyLarge),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangePasswordDialog();
                  },
                ),
              ListTile(
                leading: Icon(Icons.palette_outlined, color: colorScheme.secondary),
                title: Text('Temayı Değiştir', style: Theme.of(context).textTheme.bodyLarge),
                onTap: () {
                   Navigator.pop(context);
                  _showThemePicker(context, colorScheme);
                },
              ),
              ListTile(
                leading: Icon(Icons.bar_chart_rounded, color: colorScheme.secondary),
                title: Text('İstatistiklerim', style: Theme.of(context).textTheme.bodyLarge),
                onTap: () {
                   Navigator.pop(context);
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const StatisticsScreen()));
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: colorScheme.error),
                title: Text('Çıkış Yap', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(context: context, builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Çıkış Yap'),
                      content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                        ElevatedButton(
                          onPressed: () { 
                             Navigator.of(ctx).pop();
                             _authService.signOut();
                           },
                          style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Çıkış Yap'),
                        ),
                      ],
                  ));
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
            ],
          ),
        );
      },
    );
  }
  

  // === build METODU (YENİ TASARIM) ===
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: _currentUserId == null
          ? const Center(child: Text("Kullanıcı bulunamadı."))
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(_currentUserId).snapshots(),
              builder: (context, snapshot) {
                
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return _buildLoadingState(colorScheme, textTheme);
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Hata: Profil verisi okunamadı. ${snapshot.error}"));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                   return _buildLoadingState(colorScheme, textTheme);
                }
                
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final String email = data['email'] ?? 'E-posta yok';
                final String kullaniciAdi = data['kullaniciAdi'] ?? 'İsimsiz';
                final String ad = data['ad'] ?? '';
                final String soyad = data['soyad'] ?? '';
                final String displayName = (ad.isNotEmpty || soyad.isNotEmpty) ? '$ad $soyad' : kullaniciAdi;
                final String emoji = data['emoji'] ?? '🙂';
                final int toplamPuan = (data['toplamPuan'] as num? ?? 0).toInt();
                
                if (_liderlikSirasi == -1 && !_isRankLoading) {
                   Future.microtask(() => _loadUserRank());
                }

                final bool isGoogleUser = _authService.currentUser?.providerData
                        .any((provider) => provider.providerId == 'google.com') ?? false;

                return RefreshIndicator(
                    onRefresh: _refreshAllData,
                    color: colorScheme.primary,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        SliverAppBar(
                          backgroundColor: colorScheme.background,
                          foregroundColor: colorScheme.onSurface,
                          elevation: 0,
                          pinned: true,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                          title: Text('Profile', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          centerTitle: true,
                          actions: [
                            IconButton(
                              onPressed: () {
                                 _showSettingsMenu(context, colorScheme, isGoogleUser);
                              },
                              icon: const Icon(Icons.settings_outlined),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),

                        // Ana Profil İçeriği
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              _buildProfileAvatar(emoji, () => _showEmojiPicker(emoji), colorScheme),
                              const SizedBox(height: 16),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(child: Text(displayName, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
                                  IconButton(
                                    onPressed: _isSaving ? null : () => _showEditInfoDialog(kullaniciAdi, ad, soyad),
                                    icon: Icon(Icons.edit_note_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.7), size: 24),
                                    padding: const EdgeInsets.only(left: 8, top: 4),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              _buildLevelAndXP(toplamPuan, textTheme, colorScheme),
                              const SizedBox(height: 32),
                              _buildStatCardsRow(toplamPuan, colorScheme, textTheme),
                              const SizedBox(height: 32),
                               Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Text("Başarılarım", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                     
                                     // --- "Tümünü Gör" Butonu (Sabit, artık gizli değil) ---
                                     TextButton(
                                        onPressed: (){
                                           // Ayrı bir başarılar ekranı aç
                                           Navigator.push(context, MaterialPageRoute(builder: (context) => const AchievementsScreen()));
                                        },
                                        child: const Text("Tümünü Gör")
                                     )
                                     // --- BİTTİ ---
                                   ],
                                 ),
                               ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        
                        // --- GÜNCELLENDİ: Başarılar Grid'i (TÜMÜNÜ gösterir) ---
                        _buildAchievementsGrid(colorScheme, textTheme),
                        
                        SliverToBoxAdapter(
                          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
                        )
                      ],
                    ),
                  );
              },
            ),
    );
  }

  // Yükleniyor Ekranı
  Widget _buildLoadingState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colorScheme.primary.withOpacity(0.2), colorScheme.primary.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary), strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text('Profil Yükleniyor', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.8), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Profil Avatarı
  Widget _buildProfileAvatar(String emoji, VoidCallback onTap, ColorScheme colorScheme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(color: colorScheme.primaryContainer, width: 4),
            boxShadow: [ BoxShadow(color: colorScheme.shadow.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)) ],
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
        ),
        Positioned(
          bottom: 0, right: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.background, width: 3),
              ),
              child: Icon(Icons.edit_rounded, color: colorScheme.onPrimary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  // Seviye/XP Barı
  Widget _buildLevelAndXP(int toplamPuan, TextTheme textTheme, ColorScheme colorScheme) {
    final int level = (toplamPuan / 1000).floor() + 1;
    final double currentXp = (toplamPuan % 1000).toDouble();
    const double nextLevelXp = 1000;
    final double progress = currentXp / nextLevelXp;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   Text('LVL:', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                   const SizedBox(width: 8),
                   Text('$level', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.orange.shade600, Colors.red.shade600]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Next LVL', style: textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
             borderRadius: BorderRadius.circular(10),
             child: LinearProgressIndicator(
               value: progress,
               minHeight: 8,
               backgroundColor: colorScheme.surfaceVariant,
               valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
             ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${currentXp.toInt()}xp / ${nextLevelXp.toInt()}xp',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // 3'lü İstatistik Kartları
  Widget _buildStatCardsRow(int toplamPuan, ColorScheme colorScheme, TextTheme textTheme) {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16.0),
       child: Row(
         children: [
           Expanded(child: _buildStatCard(
             label: 'Sıralama', 
             value: _isRankLoading ? '...' : (_liderlikSirasi > 0 ? '#$_liderlikSirasi' : '-'), 
             icon: FontAwesomeIcons.trophy,
             color: const Color(0xFF6A5AE0),
             textTheme: textTheme,
           )),
           const SizedBox(width: 12),
           Expanded(child: _buildStatCard(
             label: 'Puan', 
             value: NumberFormat.compact().format(toplamPuan), 
             icon: FontAwesomeIcons.solidStar,
             color: const Color(0xFFF27A54),
             textTheme: textTheme,
           )),
           const SizedBox(width: 12),
           Expanded(child: _buildStatCard(
             label: 'Rozetler', 
             value: _isLoadingAchievements ? '...' : '${_earnedAchievements.length}', 
             icon: FontAwesomeIcons.shieldHalved,
             color: const Color(0xFF33CC99),
             textTheme: textTheme,
           )),
         ],
       ),
     );
  }

  // Tek bir istatistik kartı
  Widget _buildStatCard({required String label, required String value, required IconData icon, required Color color, required TextTheme textTheme}) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
       decoration: BoxDecoration(
         color: color.withOpacity(0.1),
         borderRadius: BorderRadius.circular(20),
       ),
       child: Column(
         children: [
           FaIcon(icon, color: color, size: 24),
           const SizedBox(height: 8),
           Text(value, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
           const SizedBox(height: 2),
           Text(label, style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
         ],
       ),
     );
  }

  // Başarılar Grid'i (SliverGrid) - TÜMÜNÜ GÖSTERİR
  Widget _buildAchievementsGrid(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoadingAchievements) {
       return SliverPadding(
         padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
         sliver: SliverGrid(
           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16),
           delegate: SliverChildBuilderDelegate((context, index) => _buildAchievementBadgePlaceholder(colorScheme), childCount: 8), // 8'li placeholder
         ),
       );
    }
    if (_allAchievements.isEmpty) {
      return SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text("Başarı bulunamadı.", style: textTheme.bodyMedium))));
    }

    // --- DEĞİŞİKLİK: Artık TÜM başarıları göster (take(8) kaldırıldı) ---
    // final achievementsToShow = _allAchievements.take(8).toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= _allAchievements.length) return null;
          
          final achievementDoc = _allAchievements[index];
          final achievementId = achievementDoc.id;
          final achievementData = achievementDoc.data() as Map<String, dynamic>? ?? {};
          final bool isEarned = _earnedAchievements.containsKey(achievementId);
          final earnedData = isEarned ? _earnedAchievements[achievementId] : null;
          final String earnedDate = isEarned ? _formatTimestamp(earnedData?['earnedDate']) : '';
          final String emoji = achievementData['emoji'] ?? '🏆';
          final String name = achievementData['name'] ?? 'Başarı';
          final String description = achievementData['description'] ?? 'Açıklama yok';
          
          Animation<double>? animation;
          if(index < _badgeAnimations.length) {
            animation = _badgeAnimations[index];
          }

          return _buildAchievementBadge(emoji, name, description, isEarned, earnedDate, colorScheme, textTheme, animation);
        }, childCount: _allAchievements.length), // <<< Bütün listeyi göster
      ),
    );
  }
  
  // Yükleniyor Placeholder
  Widget _buildAchievementBadgePlaceholder(ColorScheme colorScheme) {
     return Container(
       decoration: BoxDecoration(
         shape: BoxShape.circle,
         color: colorScheme.surfaceVariant.withOpacity(0.3),
       ),
     );
  }

  // Rozet Widget'ı (Tasarım GÜNCELLENDİ: Flulaştırma)
  Widget _buildAchievementBadge(
    String emoji, String name, String description,
    bool isEarned, String earnedDate,
    ColorScheme colorScheme, TextTheme textTheme, Animation<double>? animation
  ) {
    
    Widget emojiContent;
    if (isEarned) {
      // KAZANILDI: Parlak, canlı, net
      emojiContent = Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 32), // Tam renkli emoji
        ),
      );
    } else {
      // KİLİTLİ: Gri, Flulaştırılmış
      emojiContent = Opacity(
        opacity: 0.6, // Hafif soluk
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5), // <<< FLULAŞTIRMA
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: 32,
                color: Colors.grey.shade400, // <<< GRİ/RENKSİZ
              ),
            ),
          ),
        ),
      );
    }

    Widget badge = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isEarned ? colorScheme.surface : colorScheme.surfaceVariant.withOpacity(0.5),
        gradient: isEarned ? LinearGradient(
            colors: [colorScheme.primaryContainer, colorScheme.primary.withOpacity(0.4)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        border: Border.all(
          color: isEarned ? colorScheme.primary.withOpacity(0.3) : colorScheme.outline.withOpacity(0.2),
          width: 1.5
        ),
        boxShadow: [
          if (isEarned) // Kazanılana gölge
            BoxShadow(color: colorScheme.primary.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: emojiContent, // Flulaştırılmış veya net emojiyi bas
    );

    return Tooltip(
      message: isEarned ? '$name\nKazanıldı: $earnedDate' : 'Kilitli: $name\n$description',
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _showAchievementDetails(emoji, name, description, isEarned, earnedDate, colorScheme, textTheme),
        child: (animation != null && !_isLoadingAchievements)
          ? ScaleTransition(scale: animation, child: badge) 
          : badge,
      ),
    );
  }

  // Rozet Detay Dialog'u
  void _showAchievementDetails(String emoji, String name, String description, bool isEarned, String earnedDate, ColorScheme colorScheme, TextTheme textTheme) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: colorScheme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isEarned
                          ? LinearGradient(colors: [colorScheme.primary.withOpacity(0.9), colorScheme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade500]),
                      boxShadow: [ BoxShadow(color: (isEarned ? colorScheme.primary : Colors.grey).withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 8)) ],
                    ),
                  ),
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isEarned ? colorScheme.primaryContainer : Colors.grey.shade100.withOpacity(0.8),
                    ),
                    child: Center(
                      child: Text(emoji, style: TextStyle(fontSize: 48, color: isEarned ? colorScheme.onPrimaryContainer : Colors.grey.shade600.withOpacity(0.7))),
                    ),
                  ),
                  if (isEarned)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.yellow.shade400, Colors.orange.shade400]),
                          shape: BoxShape.circle,
                          boxShadow: [ BoxShadow(color: Colors.orange.withOpacity(0.6), blurRadius: 10, spreadRadius: 1) ],
                        ),
                        child: const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Text(name, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(description, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7), height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isEarned ? Colors.green.withOpacity(0.1) : colorScheme.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isEarned ? Colors.green.withOpacity(0.3) : colorScheme.outline.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isEarned ? Icons.emoji_events_rounded : Icons.hourglass_empty_rounded, color: isEarned ? Colors.green : colorScheme.onSurface.withOpacity(0.6), size: 20),
                    const SizedBox(width: 12),
                    Text(isEarned ? 'Kazanıldı: $earnedDate' : 'Henüz Kazanılmadı', style: textTheme.bodyMedium?.copyWith(color: isEarned ? Colors.green : colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Tema Seçim Widget'ı
  Widget _buildColorChoice(BuildContext context, Color color, String colorName) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isSelected = themeNotifier.seedColor.value == color.value;
    return Tooltip(
      message: colorName,
      child: GestureDetector(
        onTap: () {
          Provider.of<ThemeNotifier>(context, listen: false).setThemeColor(color);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 4 : 1.5,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)]
                : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
          ),
          child: isSelected
              ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.surface, size: 24)
              : null,
        ),
      ),
    );
  }
}