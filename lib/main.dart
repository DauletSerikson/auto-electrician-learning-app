import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AutoElectricianApp());
}

class AutoElectricianApp extends StatelessWidget {
  const AutoElectricianApp({super.key});

  static const _locale = Locale('ru');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Автоэлектрика с нуля',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // The SDK's application-level Localizations currently leaves the
      // semantics language unset. Mark all routes as Russian for screen readers.
      builder: (context, child) =>
          Semantics(container: true, localeForSubtree: _locale, child: child),

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      home: const HomeScreen(),
    );
  }
}
