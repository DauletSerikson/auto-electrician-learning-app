import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AutoElectricianApp());
}

class AutoElectricianApp extends StatelessWidget {
  const AutoElectricianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Автоэлектрика с нуля',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      home: const HomeScreen(),
    );
  }
}
