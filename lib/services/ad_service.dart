import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

class AdService with ChangeNotifier {
  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;

  // Sadece NORMAL quizler için sayaç
  int _quizCompletionCounter = 0;
  // Normal quizlerde kaç testte bir reklam gösterilecek
  static const int _showAdFrequency = 2; // (Senin ayarın 2'de kalmış)

  // --- GERÇEK REKLAM ID'LERİN (Dokunmadım) ---
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6415661016738887/9722150806';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6415661016738887/4618724283';
    }
    return '';
  }

  // 1. Reklamı Yükle (Aynı)
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('Geçiş Reklamı yüklendi.');
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Geçiş Reklamı yüklenemedi: $error');
          _interstitialAd = null;
          _interstitialLoadAttempts++;
          if (_interstitialLoadAttempts <= 3) {
            Future.delayed(const Duration(seconds: 30), loadInterstitialAd);
          }
        },
      ),
    );
  }

  // 2. NORMAL Quiz Reklamı (Sayaçlı - Aynı)
  void showInterstitialAd({
    required bool isProUser,
    required Function onAdDismissed,
  }) {
    _quizCompletionCounter++;
    print("Normal Test Bitirme Sayacı: $_quizCompletionCounter");

    if (!isProUser &&
        _quizCompletionCounter >= _showAdFrequency &&
        _interstitialAd != null) {
      print("Reklam gösteriliyor (Normal Quiz)...");

      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          print('Reklam kapatıldı.');
          ad.dispose();
          loadInterstitialAd();
          onAdDismissed();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          print('Reklam gösterilemedi: $error');
          ad.dispose();
          loadInterstitialAd();
          onAdDismissed();
        },
      );

      _interstitialAd!.show();
      _quizCompletionCounter = 0;
      _interstitialAd = null;
    } else {
      if (_interstitialAd == null && !isProUser) {
        print("Reklam gösterilemedi (henüz yüklenmemişti). Yenisi yükleniyor.");
        loadInterstitialAd();
      }
      onAdDismissed();
    }
  }

  // --- 3. YENİ FONKSİYON: Deneme Sınavı Reklamı (Sayaçsız) ---
  void showTrialExamInterstitialAd({
    required bool isProUser,
    required Function onAdDismissed,
  }) {
    // Bu fonksiyon SAYAÇ KONTROLÜ YAPMAZ.
    // Sadece PRO değilse ve reklam yüklüyse gösterir.

    print("Deneme Sınavı Reklamı kontrol ediliyor...");

    if (!isProUser && _interstitialAd != null) {
      print("Reklam gösteriliyor (Deneme Sınavı)...");

      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          print('Reklam kapatıldı.');
          ad.dispose();
          loadInterstitialAd(); // Bir sonraki için yenisini yükle
          onAdDismissed();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          print('Reklam gösterilemedi: $error');
          ad.dispose();
          loadInterstitialAd();
          onAdDismissed();
        },
      );

      _interstitialAd!.show();
      _interstitialAd = null; // Reklamı temizle
    } else {
      // PRO ise veya reklam yüklenmediyse, direkt kapat
      if (_interstitialAd == null && !isProUser) {
        print("Reklam gösterilemedi (henüz yüklenmemişti). Yenisi yükleniyor.");
        loadInterstitialAd(); // Bir sonrakine hazırlık yap
      }
      onAdDismissed();
    }
  }
  // --- YENİ FONKSİYON BİTTİ ---

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }
}
