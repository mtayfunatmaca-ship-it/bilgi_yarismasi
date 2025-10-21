import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';
// Gerekirse import edilecek: import 'package:bilgi_yarismasi/screens/main_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  // <<< TickerProviderStateMixin önemli
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  int _currentSegment = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _podiumAnimationController;
  late List<Animation<double>> _podiumAnimations;

  // Stream'leri tutmak için değişkenler (yenileme için)
  Stream<QuerySnapshot>? _generalStream;
  Stream<QuerySnapshot>? _weeklyStream;
  Stream<QuerySnapshot>? _monthlyStream;

  @override
  void initState() {
    super.initState();

    // Stream'leri başlat
    _initializeStreams();

    // Fade animasyonu
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Podyum animasyonu
    _podiumAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _podiumAnimations = List.generate(3, (index) {
      double beginInterval = index == 0 ? 0.4 : (index == 1 ? 0.2 : 0.0);
      double endInterval = index == 0 ? 1.0 : (index == 1 ? 0.8 : 0.6);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _podiumAnimationController,
          curve: Interval(beginInterval, endInterval, curve: Curves.elasticOut),
        ),
      );
    });

    // Animasyonları initState'de başlat
    _animationController.forward();
    _podiumAnimationController.forward(); // <<< Animasyonu initState'de başlat

    // Analytics (aynı)
    _logLeaderboardView(_currentSegment);
  }

  // Stream'leri başlatan veya yeniden oluşturan fonksiyon
  void _initializeStreams() {
    _generalStream = _firestore
        .collection('users')
        .orderBy('toplamPuan', descending: true)
        .limit(100) // Limit eklendi
        .snapshots();
    _weeklyStream = _firestore
        .collection('haftalikLiderlik')
        .orderBy('puan', descending: true)
        .limit(100) // Limit eklendi
        .snapshots();
    _monthlyStream = _firestore
        .collection('aylikLiderlik')
        .orderBy('puan', descending: true)
        .limit(100) // Limit eklendi
        .snapshots();
  }

  // Analytics loglama fonksiyonu
  void _logLeaderboardView(int segmentIndex) {
    String segmentName;
    switch (segmentIndex) {
      case 1:
        segmentName = 'haftalik';
        break;
      case 2:
        segmentName = 'aylik';
        break;
      default:
        segmentName = 'genel';
    }
    FirebaseAnalytics.instance.logEvent(
      name: 'view_leaderboard',
      parameters: {'segment': segmentName},
    );
  }

  // Yenileme fonksiyonu (Animasyonları da sıfırlar)
  Future<void> _refreshData() async {
    // Animasyonları sıfırla ve başlat
    _animationController.reset();
    _podiumAnimationController.reset(); // <<< Podyum animasyonunu da sıfırla
    _animationController.forward();
    _podiumAnimationController.forward(); // <<< Podyum animasyonunu da başlat

    // Stream'leri yeniden oluştur
    setState(() {
      _initializeStreams();
    });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _podiumAnimationController.dispose();
    super.dispose();
  }

  // === build METODU ===
  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: RefreshIndicator(
        // Ana yapıya RefreshIndicator eklendi
        onRefresh: _refreshData,
        color: colorScheme.primary,
        child: CustomScrollView(
          slivers: [
            // AppBar (Görünüm biraz ayarlandı)
            SliverAppBar(
              floating: true, // Scroll yukarı yapınca hemen görünsün
              pinned: true,
              snap: true, // floating ile birlikte kullanılır
              elevation: 1, // Hafif gölge
              backgroundColor: colorScheme.surface, // Arka plan rengi
              foregroundColor: colorScheme.onSurface, // İkon/Yazı rengi
              centerTitle: true,
              title: Text(
                'Liderlik Tablosu',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Segment Kontrolü
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16.0,
                    16.0,
                    16.0,
                    8.0,
                  ), // Padding ayarlandı
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                      ), // Sınır eklendi
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildSegmentButton(
                          text: 'Genel',
                          index: 0,
                          isSelected: _currentSegment == 0,
                        ),
                        _buildSegmentButton(
                          text: 'Haftalık',
                          index: 1,
                          isSelected: _currentSegment == 1,
                        ),
                        _buildSegmentButton(
                          text: 'Aylık',
                          index: 2,
                          isSelected: _currentSegment == 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Liderlik İçeriği
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ), // Alt boşluk
              sliver: SliverToBoxAdapter(
                child: IndexedStack(
                  index: _currentSegment,
                  children: [
                    // Stream'leri state değişkenlerinden alıyoruz
                    if (_generalStream != null)
                      _buildLeaderboardContent(
                        stream: _generalStream!,
                        puanField: 'toplamPuan',
                        currentUserId: currentUserId,
                        emptyMessage:
                            'Henüz puan alan kimse yok. Bir test çözerek sıralamaya katıl!',
                      )
                    else
                      const Center(
                        child: CircularProgressIndicator(),
                      ), // Stream null ise yükleniyor göster
                    if (_weeklyStream != null)
                      _buildLeaderboardContent(
                        stream: _weeklyStream!,
                        puanField: 'puan',
                        currentUserId: currentUserId,
                        emptyMessage:
                            'Bu hafta henüz kimse test çözmedi. Hemen bir test çöz!',
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                    if (_monthlyStream != null)
                      _buildLeaderboardContent(
                        stream: _monthlyStream!,
                        puanField: 'puan',
                        currentUserId: currentUserId,
                        emptyMessage:
                            'Bu ay henüz kimse test çözmedi. Hemen bir test çöz!',
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // === build METODU SONU ===

  // === YARDIMCI WIDGET'LAR ===

  // Segment Butonu
  Widget _buildSegmentButton({
    required String text,
    required int index,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentSegment != index) {
            setState(() {
              _currentSegment = index;
              _logLeaderboardView(index);
              _podiumAnimationController.reset();
              _podiumAnimationController.forward();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // Liderlik İçeriği Oluşturucu
  Widget _buildLeaderboardContent({
    required Stream<QuerySnapshot> stream,
    required String puanField,
    required String? currentUserId,
    required String emptyMessage,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator()); // Yükleniyor
        }
        if (snapshot.hasError) {
          print(
            'Leaderboard Stream Error (${stream.hashCode}): ${snapshot.error}',
          );
          return _buildErrorState(_refreshData); // Hata durumu
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Animasyon başlatma KODU BURADA YOK (initState/refresh/segment'te var)
          return _buildEmptyState(emptyMessage, context); // Boş durum
        }

        // Veri varsa
        var userDocs = snapshot.data!.docs;
        final currentUserIndex = userDocs.indexWhere(
          (u) => _isCurrentUser(u, currentUserId),
        );
        final topThree = userDocs.take(3).toList();
        final otherUsers = userDocs.skip(3).toList();

        // Animasyon başlatma KODU BURADA YOK (initState/refresh/segment'te var)

        // Column içinde Podyum ve Liste
        return Column(
          children: [
            if (topThree.isNotEmpty)
              _buildPodiumSection(topThree, puanField, currentUserId),
            if (otherUsers.isNotEmpty)
              _buildOtherUsersSection(
                otherUsers,
                puanField,
                currentUserId,
                currentUserIndex >= 3 ? currentUserIndex : -1,
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // Podyum Bölümü
  Widget _buildPodiumSection(
    List<QueryDocumentSnapshot> topThree,
    String puanField,
    String? currentUserId,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    List<Widget> podiumItems = [];
    if (topThree.isNotEmpty) {
      podiumItems.add(
        ScaleTransition(
          scale: _podiumAnimations[0],
          child: _buildPodiumUser(
            userData: topThree[0].data() as Map<String, dynamic>,
            rank: 1,
            puanField: puanField,
            isCurrentUser: _isCurrentUser(topThree[0], currentUserId),
          ),
        ),
      );
    }
    if (topThree.length > 1) {
      podiumItems.add(
        ScaleTransition(
          scale: _podiumAnimations[1],
          child: _buildPodiumUser(
            userData: topThree[1].data() as Map<String, dynamic>,
            rank: 2,
            puanField: puanField,
            isCurrentUser: _isCurrentUser(topThree[1], currentUserId),
          ),
        ),
      );
    }
    if (topThree.length > 2) {
      podiumItems.add(
        ScaleTransition(
          scale: _podiumAnimations[2],
          child: _buildPodiumUser(
            userData: topThree[2].data() as Map<String, dynamic>,
            rank: 3,
            puanField: puanField,
            isCurrentUser: _isCurrentUser(topThree[2], currentUserId),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (podiumItems.length > 1)
            Flexible(child: podiumItems[1])
          else
            const Spacer(),
          const SizedBox(width: 8),
          if (podiumItems.isNotEmpty)
            Flexible(child: podiumItems[0])
          else
            const Spacer(),
          const SizedBox(width: 8),
          if (podiumItems.length > 2)
            Flexible(child: podiumItems[2])
          else
            const Spacer(),
        ],
      ),
    );
  }

  // Podyum Kullanıcısı Widget'ı
  Widget _buildPodiumUser({
    required Map<String, dynamic> userData,
    required int rank,
    required String puanField,
    required bool isCurrentUser,
  }) {
    final puan = (userData[puanField] as num? ?? 0).toInt();
    final kullaniciAdi = userData['kullaniciAdi'] ?? 'İsimsiz';
    final emoji = userData['emoji'] ?? '🙂';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    double heightFactor = rank == 1 ? 1.0 : (rank == 2 ? 0.85 : 0.7);
    Color rankColor;
    IconData rankIcon;
    switch (rank) {
      case 1:
        rankColor = Colors.amber.shade600;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey.shade500;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = Colors.brown.shade400;
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.grey;
        rankIcon = Icons.military_tech;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCurrentUser)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Icon(
              Icons.person_pin_circle_rounded,
              color: colorScheme.primary,
              size: 18,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            kullaniciAdi,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isCurrentUser ? colorScheme.primary : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 110),
          height: 100 * heightFactor,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [rankColor.withOpacity(0.9), rankColor.withOpacity(0.6)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: 24 + (4 * (4 - rank)).toDouble()),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$puan',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 110),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(rankIcon, color: rankColor, size: 16),
              const SizedBox(width: 4),
              Text(
                '$rank.',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Diğer Kullanıcılar Bölümü
  Widget _buildOtherUsersSection(
    List<QueryDocumentSnapshot> otherUsers,
    String puanField,
    String? currentUserId,
    int currentUserRankInOthers,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
            child: Text(
              'Diğer Sıralamalar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: otherUsers.length,
            itemBuilder: (context, index) {
              final userData = otherUsers[index].data() as Map<String, dynamic>;
              final rank = 4 + index;
              final isCurrentUser = _isCurrentUser(
                otherUsers[index],
                currentUserId,
              );
              return _buildUserListItem(
                userData: userData,
                rank: rank,
                puanField: puanField,
                isCurrentUser: isCurrentUser,
              );
            },
          ),
        ],
      ),
    );
  }

  // Liste Elemanı Widget'ı
  Widget _buildUserListItem({
    required Map<String, dynamic> userData,
    required int rank,
    required String puanField,
    required bool isCurrentUser,
  }) {
    final puan = (userData[puanField] as num? ?? 0).toInt();
    final kullaniciAdi = userData['kullaniciAdi'] ?? 'İsimsiz';
    final emoji = userData['emoji'] ?? '🙂';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: colorScheme.primary, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Text(
          '$rank.',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                kullaniciAdi,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: isCurrentUser
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Text(
          '$puan Puan',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // Mevcut Kullanıcı mı?
  bool _isCurrentUser(DocumentSnapshot userDoc, String? currentUserId) {
    var data = userDoc.data() as Map<String, dynamic>? ?? {}; // Null check
    var userId = data.containsKey('userId') ? data['userId'] : userDoc.id;
    return userId == currentUserId;
  }

  // Hata Durumu Widget'ı
  Widget _buildErrorState(VoidCallback onRetry) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: colorScheme.error,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bir hata oluştu',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Liderlik tablosu yüklenemedi. Lütfen tekrar deneyin.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }

  // Boş Durum Widget'ı
  Widget _buildEmptyState(String message, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.leaderboard_outlined,
                color: colorScheme.primary,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              }, // Güvenli pop
              icon: const Icon(Icons.quiz),
              label: const Text('Test Çözmeye Başla'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} // _LeaderboardScreenState sonu
