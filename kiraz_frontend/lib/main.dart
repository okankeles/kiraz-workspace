import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.instance.onSessionExpired = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };
  runApp(const KirazApp());
}

class KirazApp extends StatelessWidget {
  const KirazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'KiraZ',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E50CE),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E50CE),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF161F33),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
