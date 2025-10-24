import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isConnected = true; // Başlangıçta bağlı varsayalım

  @override
  void initState() {
    super.initState();

    // 1. Uygulama açılırken anlık durumu hemen kontrol et
    _checkCurrentConnectivity();

    // 2. Bağlantı değişikliklerini dinlemeye başla
    _subscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // Başlangıçtaki bağlantı durumunu kontrol eden fonksiyon
  Future<void> _checkCurrentConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    _updateConnectionStatus(connectivityResult);
  }

  // --- DÜZELTİLMİŞ MANTIK BURADA ---
  // Bu fonksiyon, bağlantı durumu değiştiğinde çağrılır
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // connectivity_plus artık bir liste döndürebilir (örn: hem Wifi hem Mobil açık)

    bool currentConnectionStatus;

    // Eğer liste 'none' içeriyorsa VEYA boşsa internet yok demektir.
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      currentConnectionStatus = false;
    } else {
      // Eğer 'none' içermiyorsa (yani wifi, mobile, ethernet vb. varsa)
      // internet VAR sayılır.
      currentConnectionStatus = true;
    }

    // Sadece durum değiştiyse ekranı yeniden çiz
    if (mounted && _isConnected != currentConnectionStatus) {
      setState(() {
        _isConnected = currentConnectionStatus;
      });
    }
  }
  // --- DÜZELTME BİTTİ ---

  @override
  Widget build(BuildContext context) {
    // Stack kullanarak ana uygulamayı (child) ve banner'ı üst üste bindiriyoruz
    return Stack(
      children: [
        // 1. Katman: Ana uygulaman (AuthWrapper -> MainScreen vs.)
        widget.child,

        // 2. Katman: İnternet Yok Banner'ı
        // (AnimatedPositioned ile ekranın altından kayarak gelir/gider)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          // Bağlıysa ekranın dışına (-100), bağlı değilse ekranın altına (0)
          bottom: _isConnected ? -100 : 0,
          left: 0,
          right: 0,
          child: _buildBanner(context),
        ),
      ],
    );
  }

  // İnternet yokken gösterilecek banner'ın tasarımı
  Widget _buildBanner(BuildContext context) {
    // Material widget'ı, Text'lerin doğru temada (beyaz) görünmesini sağlar
    return Material(
      color: Colors.transparent, // Arka plan rengini Container belirlesin
      child: Container(
        // Cihazın altındaki çentik/boşluk (SafeArea) kadar da padding ver
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        color: Colors.red.shade700, // Koyu kırmızı
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'İnternet bağlantısı yok.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
