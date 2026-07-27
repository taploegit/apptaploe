import 'package:web/web.dart' as web;

Future<bool> redirectToDestination(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.trim().isEmpty) return false;
  web.window.location.replace(url);
  return true;
}
