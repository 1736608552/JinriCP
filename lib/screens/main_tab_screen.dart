import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'live_screen.dart';
import 'plugin_screen.dart';
import 'settings_screen.dart';

class MainTabScreen extends StatefulWidget {
  final ApiService apiService;
  final StorageService storageService;

  const MainTabScreen({
    super.key,
    required this.apiService,
    required this.storageService,
  });

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      LiveScreen(
        apiService: widget.apiService,
      ),
      const PluginScreen(),
      SettingsScreen(
        apiService: widget.apiService,
        storageService: widget.storageService,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141724),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF141724),
          selectedItemColor: Colors.deepPurpleAccent,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.live_tv_rounded),
              activeIcon: Icon(Icons.live_tv_rounded, color: Colors.redAccent),
              label: '实时直播',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.extension_rounded),
              activeIcon: Icon(Icons.extension_rounded, color: Colors.deepPurpleAccent),
              label: '插件源',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded, color: Colors.deepPurpleAccent),
              label: '系统设置',
            ),
          ],
        ),
      ),
    );
  }
}
