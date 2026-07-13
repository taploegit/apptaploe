import 'package:flutter/foundation.dart';

String nowIso() => DateTime.now().toUtc().toIso8601String();

String slugify(String value) {
  final lower = value.trim().toLowerCase();
  final replaced = lower
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (replaced.length >= 3) return replaced;
  return 'taploe-${DateTime.now().millisecondsSinceEpoch}';
}

String initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  if (parts.isEmpty) return 'T';
  return parts.take(2).map((e) => e[0].toUpperCase()).join();
}

String dateShort(DateTime? date) {
  if (date == null) return '-';
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

void safePrintError(Object error) {
  if (kDebugMode) debugPrint(error.toString());
}

String safeAuthErrorMessage(
  Object? error, {
  String fallback = 'No se pudo completar el acceso. Intenta de nuevo.',
}) {
  final raw = error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('AuthException: ', '')
      .replaceFirst('ClientException: ', '')
      .trim();
  final normalized = raw.toLowerCase();

  if (normalized.isEmpty || normalized == 'null') return fallback;

  if (normalized.contains('invalid') ||
      normalized.contains('expired') ||
      normalized.contains('otp') ||
      normalized.contains('token has expired') ||
      normalized.contains('incorrect')) {
    return 'El código es incorrecto o ya expiró.';
  }

  if (normalized.contains('auth_user_id_fkey') ||
      normalized.contains('key is not present in table "users"') ||
      normalized.contains('no hay sesión') ||
      normalized.contains('session') ||
      normalized.contains('jwt') ||
      normalized.contains('unauthorized') ||
      normalized.contains('401')) {
    return 'No pudimos validar tu sesión. Vuelve a iniciar sesión e intenta de nuevo.';
  }

  if (normalized.contains('failed to fetch') ||
      normalized.contains('browser_client') ||
      normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('cors') ||
      normalized.contains('xmlhttprequest') ||
      normalized.contains('supabase.co') ||
      normalized.contains('http://') ||
      normalized.contains('https://')) {
    return 'No pudimos conectar con Taploe. Revisa tu conexión e intenta de nuevo.';
  }

  if (normalized.contains('permission') ||
      normalized.contains('row-level security') ||
      normalized.contains('rls') ||
      normalized.contains('403')) {
    return 'El código fue aceptado, pero no se pudo cargar tu cuenta.';
  }

  if (raw.length > 140 || normalized.contains('/.pub-cache/')) {
    return fallback;
  }

  return raw;
}

String safeActivationErrorMessage(
  Object? error, {
  String fallback = 'No pudimos vincular esta tarjeta. Intenta de nuevo.',
}) {
  final raw = error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('ClientException: ', '')
      .replaceFirst('FunctionsException: ', '')
      .trim();
  final normalized = raw.toLowerCase();

  if (normalized.isEmpty || normalized == 'null') return fallback;

  if (normalized.contains('no pudimos reconocer') ||
      normalized.contains('qr') && normalized.contains('taploe')) {
    return 'No pudimos reconocer este QR como una tarjeta Taploe.';
  }

  if (normalized.contains('ya está vinculada a tu cuenta') ||
      normalized.contains('already linked to your account') ||
      normalized.contains('already linked to this account') ||
      normalized.contains('same user')) {
    return 'Esta tarjeta ya está vinculada a tu cuenta.';
  }

  if (normalized.contains('otra cuenta') ||
      normalized.contains('another account') ||
      normalized.contains('already claimed') ||
      normalized.contains('owner_user_id') ||
      normalized.contains('active_profile_id')) {
    return 'Esta tarjeta ya fue vinculada a otra cuenta.';
  }

  if (normalized.contains('not found') ||
      normalized.contains('no rows') ||
      normalized.contains('inexistente') ||
      normalized.contains('no existe') ||
      normalized.contains('not available') ||
      normalized.contains('inactive') ||
      normalized.contains('inactivo') ||
      normalized.contains('disabled') ||
      normalized.contains('lost') ||
      normalized.contains('replaced') ||
      normalized.contains('deshabilitada') ||
      normalized.contains('perdida') ||
      normalized.contains('reemplazada')) {
    return 'Esta tarjeta no está disponible para vincular.';
  }

  if (normalized.contains('jwt') ||
      normalized.contains('session') ||
      normalized.contains('auth') ||
      normalized.contains('unauthorized') ||
      normalized.contains('401') ||
      normalized.contains('403') ||
      normalized.contains('permission') ||
      normalized.contains('row-level security') ||
      normalized.contains('rls')) {
    return 'No pudimos validar tu sesión. Vuelve a iniciar sesión e intenta de nuevo.';
  }

  if (normalized.contains('failed to fetch') ||
      normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('cors') ||
      normalized.contains('xmlhttprequest') ||
      normalized.contains('supabase.co') ||
      normalized.contains('functions/v1') ||
      normalized.contains('uri=') ||
      normalized.contains('http://') ||
      normalized.contains('https://')) {
    return 'No pudimos conectar con Taploe. Revisa tu conexión e intenta de nuevo.';
  }

  if (normalized.contains('edge function') ||
      normalized.contains('function') ||
      normalized.contains('response') ||
      normalized.contains('payload') ||
      normalized.contains('token') ||
      raw.length > 140) {
    return fallback;
  }

  return raw;
}
