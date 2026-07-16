import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'router.dart';
import 'state.dart';
import 'theme.dart';

class TaploeApp extends StatelessWidget {
  const TaploeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: taploeState,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Taploe',
          debugShowCheckedModeBanner: false,
          theme: taploeTheme(),
          locale: taploeState.localeConfig.flutterLocale,
          supportedLocales: const [Locale('es', 'MX'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          routerConfig: taploeRouter,
        );
      },
    );
  }
}
