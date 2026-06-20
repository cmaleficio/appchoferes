import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/expense_form_screen.dart';
import 'screens/expense_history_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
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
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/expense/new':
            return MaterialPageRoute(builder: (_) => const ExpenseFormScreen());
          case '/expenses':
            return MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen());
          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
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

/// Home screen: driver dashboard with quick actions.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppChoferes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar',
            onPressed: () async {
              final sync = SyncService.instance;
              final token = await sync.getToken();
              if (token == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronizando...')),
              );
              await sync.fullSync(token);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Sincronización completada'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await SyncService.instance.clearToken();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Sesión iniciada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Usa el botón + para registrar un gasto'),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'history',
            onPressed: () => Navigator.pushNamed(context, '/expenses'),
            tooltip: 'Historial de gastos',
            child: const Icon(Icons.list_alt),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new_expense',
            onPressed: () =>
                Navigator.pushNamed(context, '/expense/new'),
            icon: const Icon(Icons.add),
            label: const Text('Registrar Gasto'),
          ),
        ],
      ),
    );
  }
}
