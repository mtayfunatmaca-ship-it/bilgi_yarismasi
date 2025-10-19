import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  // Yeni çözülen testten gelen veriler
  final String? quizId;
  final int? puan;
  final int? dogruSayisi;
  final int? soruSayisi;

  // Geçmişten gelen test verisi
  final Map<String, dynamic>? solvedData;
  final bool fromHistory; // Geçmişten mi çağrıldı?

  const ResultScreen({
    super.key,
    this.quizId,
    this.puan,
    this.dogruSayisi,
    this.soruSayisi,
    this.solvedData,
    this.fromHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    // Verileri nereden okuyacağımızı belirliyoruz
    int finalPuan, finalDogruSayisi, finalSoruSayisi;
    String appBarTitle;

    if (fromHistory && solvedData != null) {
      // Geçmişten geliyorsa: 'solvedData' haritasından oku
      appBarTitle = 'Geçmiş Sonuç';

      // Firestore'dan gelen 'num' tipini '.toInt()' ile 'int' tipine çeviriyoruz
      finalPuan = (solvedData!['puan'] as num? ?? 0).toInt();
      finalDogruSayisi = (solvedData!['dogruSayisi'] as num? ?? 0).toInt();
      finalSoruSayisi =
          finalDogruSayisi + (solvedData!['yanlisSayisi'] as num? ?? 0).toInt();
    } else {
      // Yeni çözüldüyse: doğrudan parametrelerden oku
      appBarTitle = 'Test Sonucu';
      finalPuan = puan ?? 0;
      finalDogruSayisi = dogruSayisi ?? 0;
      finalSoruSayisi = soruSayisi ?? 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        automaticallyImplyLeading: false, // Geri tuşunu gizle
      ),
      body: Center(
        child: Column(
          // 'MainAxisAlignment' typo hatası düzeltildi
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              // Mesajı duruma göre değiştir
              fromHistory ? 'BU TESTİ DAHA ÖNCE ÇÖZDÜNÜZ' : 'TEBRİKLER!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              'Puanınız: $finalPuan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              '$finalSoruSayisi soruda $finalDogruSayisi doğru yaptınız.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (fromHistory) // Sadece geçmişe bakıyorsa not göster
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '(Bu testten tekrar puan kazanamazsınız)',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // 'QuizListScreen' sadece yeni çözüldüyse yenilenir
                Navigator.of(context).pop(fromHistory ? false : true);
              },
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }
}
