import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
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

class _RedirectResolverViewState extends State<RedirectResolverView>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  bool failed = false;
  String? destinationUrl;
  late final AnimationController _spinnerController;

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _resolve();
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
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
    final failedRedirectUrl = TaploeConfig.redirectUrl(widget.slug);
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
                  width: 178,
                  height: 74,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.public_rounded,
                    color: TaploeColors.blue,
                    size: 74,
                  ),
                ),
                const SizedBox(height: 28),
                if (loading && !failed) ...[
                  _GoogleProgressIndicator(animation: _spinnerController),
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
                if (failed) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    t.text(
                      'Ruta: $failedRedirectUrl',
                      'Route: $failedRedirectUrl',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: TaploeColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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

class _GoogleProgressIndicator extends StatelessWidget {
  final Animation<double> animation;

  const _GoogleProgressIndicator({required this.animation});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 46,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: animation.value * math.pi * 2,
            child: const CustomPaint(painter: _GoogleProgressPainter()),
          );
        },
      ),
    );
  }
}

class _GoogleProgressPainter extends CustomPainter {
  const _GoogleProgressPainter();

  static const _colors = [
    Color(0xFF4285F4),
    Color(0xFFEA4335),
    Color(0xFFFBBC05),
    Color(0xFF34A853),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.1;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const gap = math.pi / 22;
    final sweep = (math.pi * 2 - gap * _colors.length) / _colors.length;
    var startAngle = -math.pi / 2;

    for (final color in _colors) {
      paint.color = color;
      canvas.drawArc(arcRect, startAngle, sweep, false, paint);
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GoogleProgressPainter oldDelegate) => false;
}
