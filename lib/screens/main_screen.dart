import 'package:flutter/material.dart';
import 'package:bilgi_yarismasi/screens/home_screen.dart';
import 'package:bilgi_yarismasi/screens/leaderboard_screen.dart';
import 'package:bilgi_yarismasi/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Hangi sekmede olduğumuzu tutan state

  // Alt çubukta gösterilecek 3 ana ekranımız
  static final List<Widget> _widgetOptions = <Widget>[
    HomeScreen(), // Index 0: Kategoriler
    LeaderboardScreen(), // Index 1: Liderlik Tablosu
    const ProfileScreen(), // Index 2: Profil Sayfası
  ];

  // Bir sekmeye tıklandığında indeksi güncelleyen fonksiyon
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body (gövde) olarak, listeden seçili indeksteki ekranı göster
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),

      // Alt Gezinme Çubuğu
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home), // Seçiliyken bu ikonu göster
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined),
            activeIcon: Icon(Icons.leaderboard),
            label: 'Sıralama',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profilim',
          ),
        ],
        currentIndex: _selectedIndex, // Şu anki seçili sekme
        onTap: _onItemTapped, // Tıklandığında fonksiyonu çağır
      ),
    );
  }
}
