import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class TaploeApp extends StatelessWidget {
  const TaploeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Taploe',
      debugShowCheckedModeBanner: false,
      theme: taploeTheme(),
      routerConfig: taploeRouter,
    );
  }
}
