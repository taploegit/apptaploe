import 'package:url_launcher/url_launcher.dart';

Future<bool> redirectToDestination(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return true;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
