import 'package:apptaploe/src/app.dart';
import 'package:apptaploe/src/config.dart';
import 'package:apptaploe/src/localization.dart';
import 'package:apptaploe/src/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
  } catch (_) {
    await Supabase.initialize(
      url: TaploeConfig.supabaseUrl,
      publishableKey: TaploeConfig.supabaseAnonKey,
      debug: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await _ensureSupabaseInitialized();
  });

  testWidgets('Taploe muestra login cuando no hay sesión', (
    WidgetTester tester,
  ) async {
    taploeState.localeConfig = TaploeLocaleConfig.esMx;
    taploeState.bootstrapping = false;
    taploeState.currentUser = null;
    taploeState.organization = null;
    taploeState.profiles = [];
    taploeState.cards = [];
    taploeState.activeProfile = null;

    await tester.pumpWidget(const TaploeApp());
    await tester.pumpAndSettle();

    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('Taploe traduce el login completo cuando el idioma es inglés', (
    WidgetTester tester,
  ) async {
    taploeState.localeConfig = TaploeLocaleConfig.enUs;
    taploeState.bootstrapping = false;
    taploeState.currentUser = null;
    taploeState.organization = null;
    taploeState.profiles = [];
    taploeState.cards = [];
    taploeState.activeProfile = null;

    await tester.pumpWidget(const TaploeApp());
    await tester.pumpAndSettle();

    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsNothing);
  });

  test('Taploe traduce textos visibles dinámicos de la plataforma', () {
    expect(
      taploeTranslateToEnglish(
        'Hola, Daniel. Elige la ruta pública de tu perfil digital.',
      ),
      'Hi, Daniel. Choose your digital profile public URL.',
    );
    expect(taploeTranslateToEnglish('87 envíos'), '87 submissions');
    expect(
      taploeTranslateToEnglish('María Comercial\nMiembro'),
      'María Comercial\nMember',
    );
    expect(
      taploeTranslateToEnglish(
        'app.taploe.com/daniel ya está en uso. Elige otra ruta.',
      ),
      'app.taploe.com/daniel is already in use. Choose another URL.',
    );
  });
}
