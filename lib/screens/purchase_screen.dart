import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// --- DÜZELTME: Artık 'proProductId'yi de import ediyoruz ---
import 'package:bilgi_yarismasi/services/purchase_service.dart';
// --- DÜZELTME BİTTİ ---
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final purchaseService = context.watch<PurchaseService>();
    final bool isStoreAvailable = purchaseService.isStoreAvailable;
    final bool isPending = purchaseService.isPurchasePending;

    ProductDetails? proProduct;
    try {
      // --- DÜZELTME: Alt çizgi kaldırıldı ---
      proProduct = purchaseService.products.firstWhere(
        (p) => p.id == proProductId, // '_proProductId' -> 'proProductId'
      );
      // --- DÜZELTME BİTTİ ---
    } catch (e) {
      proProduct = null;
      print("firstWhere hatası (PurchaseScreen): $e");
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('PRO\'ya Geçiş Yap'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.1),
                    colorScheme.secondary.withOpacity(0.1)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                FontAwesomeIcons.rocket,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tüm Özellikleri Aç!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Tek seferlik ödeme ile ömür boyu PRO olun ve uygulamanın tadını sınırsızca çıkarın.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            _buildFeatureRow(context, FontAwesomeIcons.rectangleAd, 'Reklamları Kaldır', 'Tüm banner ve geçiş reklamlarından kurtulun.'),
            _buildFeatureRow(context, FontAwesomeIcons.chartPie, 'Detaylı İstatistikler', 'Tüm kategorilerdeki performansınızı analiz edin.'),
            _buildFeatureRow(context, FontAwesomeIcons.magnifyingGlassChart, 'Cevapları İncele', 'Deneme sınavlarındaki doğru ve yanlışlarınızı görün.'),
            _buildFeatureRow(context, Icons.lock_open_rounded, 'Özel Sınavlar', 'Sadece PRO üyelere özel hazırlanan denemelere erişin.'),
            
            const SizedBox(height: 40),

            if (isPending)
              const Center(child: CircularProgressIndicator())
            else if (!isStoreAvailable)
              const Center(child: Text('Market bulunamadı.'))
            else if (proProduct == null)
              Center(
                child: Text(
                  'Ürün bilgisi yüklenemedi. İnternetinizi kontrol edin.', 
                  style: TextStyle(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  purchaseService.buyProMembership();
                },
                child: Column(
                  children: [
                    Text(
                      'Ömür Boyu PRO Satın Al', 
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onPrimary)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proProduct.price,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onPrimary, fontSize: 28),
                    ),
                  ],
                ),
              ),
              
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // TODO: Satın alımları geri yükleme
                // purchaseService.restorePurchases();
              },
              child: const Text('Satın Alımları Geri Yükle'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle, 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}