import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:bilgi_yarismasi/services/auth_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  int _currentSegment = 0;

  @override
  void initState() {
    super.initState();
    // Analytics ile liderlik tablosu görüntülenmesini takip et
    FirebaseAnalytics.instance.logEvent(
      name: 'view_leaderboard',
      parameters: {
        'segment': _currentSegment == 0
            ? 'genel'
            : _currentSegment == 1
            ? 'haftalik'
            : 'aylik',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _authService.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Liderlik Tablosu',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Segment Kontrolü
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
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

          // Liderlik İçeriği
          Expanded(
            child: IndexedStack(
              index: _currentSegment,
              children: [
                _buildLeaderboardContent(
                  stream: _firestore
                      .collection('users')
                      .orderBy('toplamPuan', descending: true)
                      .snapshots(),
                  puanField: 'toplamPuan',
                  currentUserId: currentUserId,
                  emptyMessage:
                      'Henüz puan alan kimse yok. Bir test çözerek sıralamaya katıl!',
                ),
                _buildLeaderboardContent(
                  stream: _firestore
                      .collection('haftalikLiderlik')
                      .orderBy('puan', descending: true)
                      .snapshots(),
                  puanField: 'puan',
                  currentUserId: currentUserId,
                  emptyMessage:
                      'Bu hafta henüz kimse test çözmedi. Hemen bir test çöz!',
                ),
                _buildLeaderboardContent(
                  stream: _firestore
                      .collection('aylikLiderlik')
                      .orderBy('puan', descending: true)
                      .snapshots(),
                  puanField: 'puan',
                  currentUserId: currentUserId,
                  emptyMessage:
                      'Bu ay henüz kimse test çözmedi. Hemen bir test çöz!',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String text,
    required int index,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _currentSegment = index;
              // Segment değiştiğinde analytics olayı gönder
              FirebaseAnalytics.instance.logEvent(
                name: 'view_leaderboard',
                parameters: {'segment': text.toLowerCase()},
              );
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardContent({
    required Stream<QuerySnapshot> stream,
    required String puanField,
    required String? currentUserId,
    required String emptyMessage,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        // Hata ayıklama için log ekle
        print('Snapshot state: ${snapshot.connectionState}');
        if (snapshot.hasData) {
          print('Documents: ${snapshot.data!.docs.length}');
          for (var doc in snapshot.data!.docs) {
            print('Doc data: ${doc.data()}');
          }
        }

        // Yükleme durumu için zaman aşımı ekle
        if (snapshot.connectionState == ConnectionState.waiting) {
          return FutureBuilder(
            future: Future.delayed(const Duration(seconds: 10)),
            builder: (context, _) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Yükleniyor, lütfen bekleyin...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        }

        if (snapshot.hasError) {
          print('Error: ${snapshot.error}');
          return _buildErrorState();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(emptyMessage);
        }

        var userDocs = snapshot.data!.docs;
        final currentUserIndex = userDocs.indexWhere(
          (u) => _isCurrentUser(u, currentUserId),
        );

        // İlk 3 kullanıcıyı al
        final topThree = userDocs.take(3).toList();
        final otherUsers = userDocs.skip(3).toList();

        return SingleChildScrollView(
          child: Column(
            children: [
              // İlk 3 Kullanıcı - Podyum Tasarımı
              if (topThree.isNotEmpty)
                _buildPodiumSection(topThree, puanField, currentUserId),

              // Diğer Kullanıcılar
              if (otherUsers.isNotEmpty)
                _buildOtherUsersSection(
                  otherUsers,
                  puanField,
                  currentUserId,
                  currentUserIndex,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPodiumSection(
    List<QueryDocumentSnapshot> topThree,
    String puanField,
    String? currentUserId,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
            Theme.of(context).colorScheme.primary.withOpacity(0.02),
          ],
        ),
      ),
      child: Column(
        children: [
          // 1. sıra - Ortada
          _buildPodiumUser(
            userData: topThree[0].data() as Map<String, dynamic>,
            rank: 1,
            puanField: puanField,
            isCurrentUser: _isCurrentUser(topThree[0], currentUserId),
            height: 140,
          ),
          // 2. ve 3. sıra - Yan yana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (topThree.length > 1)
                _buildPodiumUser(
                  userData: topThree[1].data() as Map<String, dynamic>,
                  rank: 2,
                  puanField: puanField,
                  isCurrentUser: _isCurrentUser(topThree[1], currentUserId),
                  height: 120,
                ),
              const SizedBox(width: 20),
              if (topThree.length > 2)
                _buildPodiumUser(
                  userData: topThree[2].data() as Map<String, dynamic>,
                  rank: 3,
                  puanField: puanField,
                  isCurrentUser: _isCurrentUser(topThree[2], currentUserId),
                  height: 80,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumUser({
    required Map<String, dynamic> userData,
    required int rank,
    required String puanField,
    required bool isCurrentUser,
    required double height,
  }) {
    final puan = (userData[puanField] as num? ?? 0).toInt();
    final kullaniciAdi = userData['kullaniciAdi'] ?? 'İsimsiz';
    final emoji = userData['emoji'] ?? '🙂';
    final colorScheme = Theme.of(context).colorScheme;

    Color rankColor;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        break;
      case 2:
        rankColor = Colors.grey;
        break;
      case 3:
        rankColor = Colors.orange.shade300;
        break;
      default:
        rankColor = Colors.grey;
    }

    return Column(
      children: [
        // Podyum
        Container(
          width: 100,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [rankColor.withOpacity(0.8), rankColor.withOpacity(0.4)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),

              // Sıra Numarası
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Kullanıcı Bilgileri
        Container(
          width: 100,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(
                kullaniciAdi,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isCurrentUser
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '$puan Puan',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
              if (isCurrentUser)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Siz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherUsersSection(
    List<QueryDocumentSnapshot> otherUsers,
    String puanField,
    String? currentUserId,
    int currentUserIndex,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Diğer Katılımcılar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),

          // Kullanıcı Listesi
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? colorScheme.primary.withOpacity(0.1)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: colorScheme.primary, width: 1.5)
            : Border.all(color: colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.8),
                colorScheme.primary.withOpacity(0.4),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                kullaniciAdi,
                style: TextStyle(
                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                  color: isCurrentUser
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$puan',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
            const Text(
              'Puan',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  bool _isCurrentUser(DocumentSnapshot userDoc, String? currentUserId) {
    var data = userDoc.data() as Map<String, dynamic>;
    var userId = data.containsKey('userId') ? data['userId'] : userDoc.id;
    return userId == currentUserId;
  }

  Widget _buildErrorState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 64),
          const SizedBox(height: 16),
          Text(
            'Bir hata oluştu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Liderlik tablosu yüklenemedi. Lütfen tekrar deneyin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Yeniden yüklemeyi tetikle
            },
            child: const Text('Yeniden Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard_outlined,
            color: colorScheme.onSurface.withOpacity(0.3),
            size: 80,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Test ekranına yönlendir
              Navigator.pushNamed(context, '/quiz');
            },
            child: const Text('Test Çöz'),
          ),
        ],
      ),
    );
  }
}
