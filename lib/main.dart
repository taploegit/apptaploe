import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config.dart';
import 'src/state.dart';
import 'src/utils.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Supabase.initialize(
        url: TaploeConfig.supabaseUrl,
        publishableKey: TaploeConfig.supabaseAnonKey,
      );

      usePathUrlStrategy();
      await taploeState.bootstrapLocaleFromUrl();

      taploeState.startAuthListener();
      runApp(const TaploeApp());

      unawaited(taploeState.bootstrap());
    },
    (error, _) {
      debugPrint('[Taploe] Se capturó un error asíncrono.');
      safePrintError(error);
    },
  );
}
