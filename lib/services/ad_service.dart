// lib/services/ad_service.dart
import 'package:flutter/material.dart'; // <<< ChangeNotifier için GEREKLİ
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

class AdService with ChangeNotifier { // <<< 'with ChangeNotifier' EKLELİ OLMALI
  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;
  
  int _quizCompletionCounter = 0;
  static const int _showAdFrequency = 3;

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

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

  void showInterstitialAd({required bool isProUser, required Function onAdDismissed}) {
    _quizCompletionCounter++;
    print("Test bitirme sayacı: $_quizCompletionCounter");

    if (!isProUser && _quizCompletionCounter >= _showAdFrequency && _interstitialAd != null) {
      print("Reklam gösteriliyor...");
      
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

  // Düzeltilmiş dispose metodu
  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose(); // <<< super.dispose() çağrılmalı
  }
}