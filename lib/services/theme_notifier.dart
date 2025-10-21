import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  // Varsayılan tema renginiz (sizin kodunuzdan alındı)
  final Color _defaultColor = const Color.fromARGB(255, 243, 100, 33);
  late Color _seedColor;

  // Uygulamanın diğer kısımlarının mevcut rengi okuması için
  Color get seedColor => _seedColor;

  // Kayıt anahtarı
  static const String _themeColorKey = 'theme_color';

  ThemeNotifier() {
    _seedColor = _defaultColor; // Başlangıçta varsayılana ayarla
    _loadFromPrefs(); // Hafızadan kayıtlı rengi yüklemeyi dene
  }

  // Rengi değiştiren ana fonksiyon
  Future<void> setThemeColor(Color newColor) async {
    _seedColor = newColor;
    notifyListeners(); // Uygulamaya "renk değişti, yeniden çizil" sinyali gönder

    // Seçimi hafızaya kaydet
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeColorKey, newColor.value);
    } catch (e) {
      print("Tema rengi kaydedilirken hata: $e");
    }
  }

  // Uygulama açılırken hafızadan rengi yükler
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? colorValue = prefs.getInt(_themeColorKey);

      if (colorValue != null) {
        _seedColor = Color(colorValue);
        notifyListeners(); // Hafızadan yüklenen rengi uygulamaya bildir
      }
    } catch (e) {
      print("Tema rengi yüklenirken hata: $e");
    }
  }
}
