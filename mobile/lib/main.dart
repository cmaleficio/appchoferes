import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';
import 'services/telemetry_service.dart';
import 'services/background_tracking_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart' as dash;
import 'screens/expense_form_screen.dart';
import 'screens/expense_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  // Start foreground telemetry (every 5 min)
  TelemetryService.instance.start();
  // Start persistent background tracking (every 3 min, survives app close)
  await BackgroundTrackingService.instance.initialize();
  runApp(const AppChoferesApp());
}

class AppChoferesApp extends StatelessWidget {
  const AppChoferesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppChoferes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const dash.HomeScreen());
          case '/expense/new':
            return MaterialPageRoute(builder: (_) => const ExpenseFormScreen());
          case '/expenses':
            return MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen());
          default:
            return MaterialPageRoute(builder: (_) => const dash.HomeScreen());


        }
      },
    );
  }
}

/// Splash screen: checks if a saved JWT token exists → auto-login or redirect to login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 500)); // brief splash
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}


