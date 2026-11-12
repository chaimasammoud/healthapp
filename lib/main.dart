import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/meal_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthApp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const MealScreen(),
    );
  }
}
