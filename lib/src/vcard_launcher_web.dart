// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<bool> openVcardFile({
  required String contents,
  required String displayName,
}) async {
  try {
    final blob = html.Blob([
      _normalizeVcf(contents),
    ], 'text/vcard;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = '${_fileSafeName(displayName)}.vcf'
      ..target = '_blank'
      ..rel = 'noopener';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}

String _normalizeVcf(String value) {
  final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return normalized.split('\n').join('\r\n');
}

String _fileSafeName(String value) {
  final cleaned = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? 'taploe-contact' : cleaned;
}
