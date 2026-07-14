import 'package:flutter/foundation.dart';

enum PwaInstallPlatform { ios, android, desktop, unknown }

final ValueNotifier<int> pwaInstallChanges = ValueNotifier<int>(0);

class PwaInstallService {
  static void initialize() {}

  static PwaInstallPlatform get platform => PwaInstallPlatform.unknown;

  static bool get isStandalone => false;

  static bool get canPromptInstall => false;

  static Future<bool> requestInstall() async => false;

  static void configureProfile({
    required String name,
    required String shortName,
    required String startUrl,
    String? description,
  }) {}
}
