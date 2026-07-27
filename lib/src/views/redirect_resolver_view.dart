import 'package:flutter/material.dart' hide Text;
import 'package:google_fonts/google_fonts.dart';

import '../localized_text.dart';
import '../redirect_navigation.dart';
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
      final destination = redirect?.destinationUrl?.trim();
      if (redirect == null || destination == null || destination.isEmpty) {
        if (mounted) {
          setState(() {
            loading = false;
            failed = true;
          });
        }
        return;
      }

      destinationUrl = destination;
      await CardRedirectRepository.trackClick(redirectId: redirect.id);

      if (!await redirectToDestination(destination)) {
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
    final t = TaploeTextScope.of(context);
    final message = failed
        ? t.text(
            'Esta redirección no está disponible.',
            'This redirect is unavailable.',
          )
        : t.text('Redirigiendo...', 'Redirecting...');
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
                Image.asset(
                  'assets/images/google.png',
                  width: 82,
                  height: 82,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.public_rounded,
                    color: TaploeColors.blue,
                    size: 62,
                  ),
                ),
                const SizedBox(height: 28),
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
                      redirectToDestination(destinationUrl!);
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
