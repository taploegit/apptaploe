import 'package:apptaploe/src/app.dart';
import 'package:apptaploe/src/config.dart';
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
}
