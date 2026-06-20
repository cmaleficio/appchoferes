import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'screens/expense_form_screen.dart';

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
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AppChoferes')),
      body: const Center(
        child: Text('Bienvenido — usa el + para registrar un gasto'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Registrar Gasto'),
      ),
    );
  }
}
