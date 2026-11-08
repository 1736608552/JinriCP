import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_navigation_screen.dart';
import 'services/proxy_route_service.dart';
import 'services/settings_service.dart';
import 'services/theme_service.dart';

class CustomHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = CustomHttpOverrides();
  await SettingsService.initSettings();
  await ProxyRouteService.init();
  
  // 优化状态栏沉浸式浸入
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'PandaLive 极光影音',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,

          // ☀️ 现代轻奢陶瓷雅白模式
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F7FB),
            primaryColor: AppTheme.primaryPink,
            cardColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryPink,
              secondary: AppTheme.accentPink,
              surface: Colors.white,
              surfaceContainerLowest: Color(0xFFF5F7FB),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF111420)),
              titleTextStyle: TextStyle(
                color: Color(0xFF111420),
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              centerTitle: false,
            ),
            dividerColor: const Color(0xFFE5E9F2),
            splashFactory: InkSparkle.splashFactory,
            useMaterial3: true,
          ),

          // 🌙 电影级沉浸黑曜石模式 (Midnight Cinematic)
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF090A10),
            primaryColor: AppTheme.primaryPink,
            cardColor: const Color(0xFF121522),
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPink,
              secondary: AppTheme.accentPink,
              surface: Color(0xFF121522),
              surfaceContainerLowest: Color(0xFF090A10),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0E101A),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              centerTitle: false,
            ),
            dividerColor: Colors.white.withOpacity(0.08),
            splashFactory: InkSparkle.splashFactory,
            useMaterial3: true,
          ),

          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
