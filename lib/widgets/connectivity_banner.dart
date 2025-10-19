import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child; // Banner'ın altında gösterilecek asıl içerik

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false; // Bağlantı durumu

  @override
  void initState() {
    super.initState();
    // İlk durumu kontrol et
    _checkInitialConnectivity();
    // Bağlantı değişikliklerini dinlemeye başla
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel(); // Dinleyiciyi iptal et
    super.dispose();
  }

  // Başlangıçtaki bağlantı durumunu kontrol eder
  Future<void> _checkInitialConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
  }

  // Bağlantı durumu değiştiğinde çağrılır
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Eğer sonuç listesi boşsa veya 'none' içeriyorsa offline kabul et
    bool offline = results.isEmpty || results.contains(ConnectivityResult.none);
    // Sadece durum değiştiyse setState çağır
    if (offline != _isOffline && mounted) {
      setState(() {
        _isOffline = offline;
        // Bağlantı geri geldiğinde veya ilk açılışta bilgi mesajı (opsiyonel)
        /*
         if(!offline){
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('İnternet bağlantısı sağlandı.'), backgroundColor: Colors.green)
            );
         }
         */
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Eğer offline ise banner'ı göster
        if (_isOffline)
          Material(
            // Banner'a Material görünümü verelim
            color: Colors.red.shade700,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ), // Padding ayarlandı
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'İnternet bağlantısı yok',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        // Banner'ın altında asıl uygulama içeriğini göster
        Expanded(child: widget.child),
      ],
    );
  }
}
