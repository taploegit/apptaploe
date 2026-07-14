// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/foundation.dart';

enum PwaInstallPlatform { ios, android, desktop, unknown }

final ValueNotifier<int> pwaInstallChanges = ValueNotifier<int>(0);

class PwaInstallService {
  static js.JsObject? _deferredPrompt;
  static bool _initialized = false;
  static String? _manifestObjectUrl;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    final existingPrompt = _getDeferredPromptFromWindow();
    if (existingPrompt != null) {
      _deferredPrompt = existingPrompt;
    }

    html.window.addEventListener('beforeinstallprompt', (event) {
      event.preventDefault();
      final prompt = _getDeferredPromptFromWindow();
      if (prompt != null) {
        _deferredPrompt = prompt;
        pwaInstallChanges.value++;
      }
    });

    html.window.addEventListener('taploe-pwa-prompt-ready', (_) {
      final prompt = _getDeferredPromptFromWindow();
      if (prompt != null) {
        _deferredPrompt = prompt;
        pwaInstallChanges.value++;
      }
    });

    html.window.addEventListener('appinstalled', (_) {
      _deferredPrompt = null;
      js.context['taploeDeferredInstallPrompt'] = null;
      pwaInstallChanges.value++;
    });
  }

  static js.JsObject? _getDeferredPromptFromWindow() {
    final prompt = js.context['taploeDeferredInstallPrompt'];
    return prompt is js.JsObject ? prompt : null;
  }

  static PwaInstallPlatform get platform {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final maxTouchPoints = html.window.navigator.maxTouchPoints ?? 0;
    final isiPadOs = ua.contains('macintosh') && maxTouchPoints > 1;
    if (ua.contains('iphone') || ua.contains('ipad') || isiPadOs) {
      return PwaInstallPlatform.ios;
    }
    if (ua.contains('android')) return PwaInstallPlatform.android;
    if (ua.contains('edg') ||
        ua.contains('chrome') ||
        ua.contains('samsungbrowser')) {
      return PwaInstallPlatform.desktop;
    }
    return PwaInstallPlatform.unknown;
  }

  static bool get isStandalone {
    final standaloneMedia = html.window.matchMedia(
      '(display-mode: standalone)',
    );
    final navigator = js.context['navigator'];
    final navigatorStandalone =
        navigator is js.JsObject && navigator['standalone'] == true;
    return standaloneMedia.matches || navigatorStandalone;
  }

  static bool get canPromptInstall => _deferredPrompt != null;

  static Future<bool> requestInstall() async {
    final prompt = _deferredPrompt;
    if (prompt == null) return false;

    try {
      prompt.callMethod('prompt');
      _deferredPrompt = null;
      js.context['taploeDeferredInstallPrompt'] = null;
      pwaInstallChanges.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  static void configureProfile({
    required String name,
    required String shortName,
    required String startUrl,
    String? description,
  }) {
    final safeName = name.trim().isEmpty ? 'Taploe' : name.trim();
    final safeShortName = shortName.trim().isEmpty
        ? 'Taploe'
        : shortName.trim();
    html.document.title = safeName;
    _setMeta('apple-mobile-web-app-title', safeShortName);
    _setMeta('application-name', safeShortName);
    _setManifest(
      name: safeName,
      shortName: safeShortName,
      startUrl: startUrl,
      description: description,
    );
  }

  static void _setMeta(String name, String content) {
    final selector = 'meta[name="$name"]';
    final current = html.document.querySelector(selector) as html.MetaElement?;
    if (current != null) {
      current.content = content;
      return;
    }
    final meta = html.MetaElement()
      ..name = name
      ..content = content;
    html.document.head?.append(meta);
  }

  static void _setManifest({
    required String name,
    required String shortName,
    required String startUrl,
    String? description,
  }) {
    final manifest = <String, dynamic>{
      'name': name,
      'short_name': shortName,
      'description': description ?? 'Perfil digital Taploe.',
      'start_url': startUrl,
      'scope': '/',
      'display': 'standalone',
      'display_override': ['standalone', 'minimal-ui', 'browser'],
      'orientation': 'portrait-primary',
      'theme_color': '#2D5BFF',
      'background_color': '#FFFFFF',
      'prefer_related_applications': false,
      'icons': [
        {
          'src': '/icons/Icon-192.png',
          'sizes': '192x192',
          'type': 'image/png',
          'purpose': 'any',
        },
        {
          'src': '/icons/Icon-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'any',
        },
        {
          'src': '/icons/Icon-maskable-192.png',
          'sizes': '192x192',
          'type': 'image/png',
          'purpose': 'maskable',
        },
        {
          'src': '/icons/Icon-maskable-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'maskable',
        },
      ],
    };

    if (_manifestObjectUrl != null) {
      html.Url.revokeObjectUrl(_manifestObjectUrl!);
    }
    final blob = html.Blob([jsonEncode(manifest)], 'application/manifest+json');
    _manifestObjectUrl = html.Url.createObjectUrlFromBlob(blob);

    final oldLinks = html.document.querySelectorAll('link[rel="manifest"]');
    for (final link in oldLinks) {
      link.remove();
    }
    final manifestLink = html.LinkElement()
      ..rel = 'manifest'
      ..href = _manifestObjectUrl!;
    html.document.head?.append(manifestLink);
  }
}
