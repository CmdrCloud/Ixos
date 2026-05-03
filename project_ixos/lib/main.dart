import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/mood_provider.dart';
import 'providers/player_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dj_provider.dart';
import 'services/auth_service.dart';
import 'services/download_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const String baseUrl = 'https://musicapi.sisganadero.online'; // Updated URL
  final authService = AuthService(baseUrl: baseUrl);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MoodProvider()),
        ChangeNotifierProvider(create: (_) => DownloadService()),
        ChangeNotifierProxyProvider<DownloadService, PlayerProvider>(
          create: (_) => PlayerProvider(),
          update: (_, ds, player) => player!..updateDownloadService(ds),
        ),
        ChangeNotifierProvider(create: (_) => DjProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = AuthProvider(authService);
            provider.checkAuth();
            return provider;
          },
        ),
      ],
      child: const IxosApp(),
    ),
  );
}

class IxosApp extends StatelessWidget {
  const IxosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ixos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF09090B),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
