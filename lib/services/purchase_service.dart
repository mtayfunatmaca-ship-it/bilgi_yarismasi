import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- DÜZELTME: Değişken adı 'public' yapıldı (alt çizgi kaldırıldı) ---
const String proProductId = 'pro_lifetime';
// --- DÜZELTME BİTTİ ---

class PurchaseService with ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isStoreAvailable = false;
  bool _isPurchasePending = false;

  bool get isStoreAvailable => _isStoreAvailable;
  bool get isPurchasePending => _isPurchasePending;
  List<ProductDetails> get products => _products;

  PurchaseService() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => print("Satın alma dinleyicisinde hata: $error"),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    _isStoreAvailable = await _iap.isAvailable();
    if (!_isStoreAvailable) {
      print("Hata: Satın alma marketi (App Store/Play Store) bulunamadı.");
      notifyListeners();
      return;
    }
    await _loadProducts();
    await _iap.restorePurchases();
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    // --- DÜZELTME: Alt çizgi kaldırıldı ---
    Set<String> kIds = {proProductId};
    // --- DÜZELTME BİTTİ ---
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        kIds,
      );
      if (response.notFoundIDs.isNotEmpty) {
        print("Hata: Ürün ID'leri bulunamadı: ${response.notFoundIDs}");
      }
      _products = response.productDetails;
      print("Ürünler yüklendi: ${_products.map((p) => p.title).join(', ')}");
    } catch (e) {
      print("Ürünler yüklenirken hata: $e");
    }
  }

  Future<void> buyProMembership() async {
    if (!_isStoreAvailable || _isPurchasePending) return;

    ProductDetails? product;
    try {
      // --- DÜZELTME: Alt çizgi kaldırıldı ---
      product = _products.firstWhere((p) => p.id == proProductId);
      // --- DÜZELTME BİTTİ ---
    } catch (e) {
      product = null;
      print("firstWhere hatası (buyProMembership): $e");
    }

    if (product == null) {
      print(
        "Hata: 'pro_lifetime' ürünü marketten çekilemedi. Konsol ayarlarını kontrol et.",
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      _isPurchasePending = true;
      notifyListeners();
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print("Satın alma başlatılırken hata: $e");
      _isPurchasePending = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased) {
        print("Satın alım başarılı: ${purchase.productID}");
        await _iap.completePurchase(purchase);
        await _grantProAccess();
      } else if (purchase.status == PurchaseStatus.pending) {
        print("Satın alım beklemede...");
      } else if (purchase.status == PurchaseStatus.error) {
        print("Satın alım hatası: ${purchase.error?.message}");
        _iap.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.canceled) {
        print("Satın alım iptal edildi.");
        _iap.completePurchase(purchase);
      }
    }
    _isPurchasePending = false;
    notifyListeners();
  }

  Future<void> _grantProAccess() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("Hata: Kullanıcı giriş yapmamış, PRO yetkisi verilemedi.");
      return;
    }
    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      await userDocRef.update({'isPro': true});
      print("Firestore güncellendi: Kullanıcı artık PRO.");
    } catch (e) {
      print("Firestore 'isPro' güncelleme hatası: $e");
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
