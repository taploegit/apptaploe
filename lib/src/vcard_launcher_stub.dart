import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

Future<bool> openVcardFile({
  required String contents,
  required String displayName,
}) async {
  final uri = Uri.dataFromString(
    _normalizeVcf(contents),
    mimeType: 'text/vcard',
    encoding: utf8,
  );
  try {
    if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return true;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

String _normalizeVcf(String value) {
  final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return normalized.split('\n').join('\r\n');
}
