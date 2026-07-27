import 'package:flutter/material.dart' hide Text;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localized_text.dart';
import '../repositories.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

class RedirectResolverView extends StatefulWidget {
  final String slug;

  const RedirectResolverView({super.key, required this.slug});

  @override
  State<RedirectResolverView> createState() => _RedirectResolverViewState();
}

class _RedirectResolverViewState extends State<RedirectResolverView> {
  bool loading = true;
  bool failed = false;
  String? destinationUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final redirect = await CardRedirectRepository.resolve(widget.slug);
      if (redirect == null || redirect.destinationUrl.trim().isEmpty) {
        if (mounted) {
          setState(() {
            loading = false;
            failed = true;
          });
        }
        return;
      }

      destinationUrl = redirect.destinationUrl;
      await CardRedirectRepository.trackClick(redirectId: redirect.id);

      final uri = Uri.tryParse(redirect.destinationUrl);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          setState(() {
            loading = false;
            failed = true;
          });
        }
      }
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = failed ? 'This redirect is unavailable.' : 'Redirecting...';
    return Scaffold(
      backgroundColor: TaploeColors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TaploeLogo(size: 48, centered: true),
                const SizedBox(height: 34),
                if (loading && !failed) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                ] else
                  const Icon(
                    Icons.link_off_rounded,
                    color: TaploeColors.error,
                    size: 42,
                  ),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: TaploeColors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (failed && destinationUrl != null) ...[
                  const SizedBox(height: 18),
                  TaploeButton(
                    label: 'Open destination',
                    icon: Icons.open_in_new_rounded,
                    onPressed: () {
                      final uri = Uri.tryParse(destinationUrl!);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
