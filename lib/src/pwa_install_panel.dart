import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'pwa_install.dart';
import 'theme.dart';
import 'widgets.dart';

class PwaInstallPanel extends StatefulWidget {
  final DigitalProfileModel profile;
  final bool compact;
  final bool embedded;

  const PwaInstallPanel({
    super.key,
    required this.profile,
    this.compact = false,
    this.embedded = false,
  });

  @override
  State<PwaInstallPanel> createState() => _PwaInstallPanelState();
}

class _PwaInstallPanelState extends State<PwaInstallPanel> {
  bool installing = false;

  @override
  void initState() {
    super.initState();
    PwaInstallService.initialize();
    pwaInstallChanges.addListener(_handleInstallStateChanged);
  }

  @override
  void didUpdateWidget(covariant PwaInstallPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) _configureProfileManifest();
  }

  @override
  void dispose() {
    pwaInstallChanges.removeListener(_handleInstallStateChanged);
    super.dispose();
  }

  void _handleInstallStateChanged() {
    if (mounted) setState(() {});
  }

  void _configureProfileManifest() {
    PwaInstallService.configureProfile(
      name: widget.profile.displayName,
      shortName: widget.profile.displayName,
      startUrl: '/p/${widget.profile.publicSlug}',
      description: widget.profile.bio,
    );
  }

  Future<void> _install() async {
    setState(() => installing = true);
    try {
      final installed = await PwaInstallService.requestInstall();
      if (!installed && mounted) _openInstallGuide();
    } finally {
      if (mounted) setState(() => installing = false);
    }
  }

  void _openInstallGuide() {
    showDialog<void>(
      context: context,
      builder: (context) =>
          _PwaInstallGuideDialog(platform: PwaInstallService.platform),
    );
  }

  @override
  Widget build(BuildContext context) {
    _configureProfileManifest();
    final content = _content(context);
    if (widget.embedded) return content;
    return TaploePanel(
      radius: 22,
      padding: EdgeInsets.all(widget.compact ? 18 : 22),
      child: content,
    );
  }

  Widget _content(BuildContext context) {
    final platform = PwaInstallService.platform;
    final standalone = PwaInstallService.isStandalone;
    final canPrompt = PwaInstallService.canPromptInstall;
    final stacked = widget.compact || MediaQuery.sizeOf(context).width < 720;

    final intro = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          standalone
              ? Icons.check_circle_outline_rounded
              : Icons.phone_iphone_rounded,
          color: TaploeColors.blue,
          size: 30,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Instalar perfil',
                style: GoogleFonts.outfit(
                  color: context.text,
                  fontSize: widget.compact ? 19 : 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                standalone
                    ? 'Tu perfil ya se está ejecutando como aplicación.'
                    : 'Instala este perfil en tu teléfono para abrirlo rápido desde la pantalla de inicio.',
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final action = standalone
        ? const _PwaStatusPill(label: 'Instalado')
        : Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              TaploeButton(
                width: stacked ? double.infinity : 310,
                label: 'Instalar en mi teléfono',
                icon: Icons.download_rounded,
                loading: installing,
                onPressed: platform == PwaInstallPlatform.android && canPrompt
                    ? _install
                    : _openInstallGuide,
              ),
              const SizedBox(height: 8),
              Text(
                canPrompt
                    ? 'Instalación rápida disponible.'
                    : 'Te guiamos según tu navegador.',
                textAlign: stacked ? TextAlign.left : TextAlign.right,
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [intro, const SizedBox(height: 16), action],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: intro,
          ),
        ),
        const SizedBox(width: 32),
        Align(alignment: Alignment.topRight, child: action),
      ],
    );
  }
}

class _PwaInstallGuideDialog extends StatelessWidget {
  final PwaInstallPlatform platform;

  const _PwaInstallGuideDialog({required this.platform});

  @override
  Widget build(BuildContext context) {
    final ios = platform == PwaInstallPlatform.ios;
    final title = ios ? 'Instalar en iPhone' : 'Instalar en Android';
    final subtitle = ios
        ? 'Abre este perfil en Safari y sigue estos pasos.'
        : 'Abre este perfil en Chrome, Edge o Samsung Internet y sigue estos pasos.';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TaploePanel(
          radius: 28,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.install_mobile_rounded,
                    color: TaploeColors.blue,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            color: context.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: GoogleFonts.dmSans(
                            color: context.muted,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _PwaInstallInstructions(platform: platform, large: true),
              const SizedBox(height: 22),
              TaploeButton(
                label: 'Entendido',
                icon: Icons.check_rounded,
                expanded: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PwaStatusPill extends StatelessWidget {
  final String label;

  const _PwaStatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TaploeColors.blue.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: TaploeColors.blue,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: TaploeColors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PwaInstallInstructions extends StatelessWidget {
  final PwaInstallPlatform platform;
  final bool large;

  const _PwaInstallInstructions({required this.platform, this.large = false});

  @override
  Widget build(BuildContext context) {
    final ios = platform == PwaInstallPlatform.ios;
    final steps = ios
        ? const [
            (Icons.ios_share_rounded, 'Toca Compartir'),
            (Icons.add_box_outlined, 'Selecciona Agregar a pantalla de inicio'),
            (Icons.check_rounded, 'Confirma con Agregar'),
          ]
        : const [
            (Icons.more_vert_rounded, 'Toca el menú ⋮ del navegador'),
            (
              Icons.add_to_home_screen_rounded,
              'Elige Agregar a pantalla principal',
            ),
            (Icons.check_rounded, 'Instalar'),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: large ? 42 : 18,
                height: large ? 42 : 18,
                alignment: Alignment.center,
                decoration: large
                    ? BoxDecoration(
                        color: TaploeColors.blue.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(14),
                      )
                    : null,
                child: Icon(
                  step.$1,
                  color: TaploeColors.blue,
                  size: large ? 22 : 18,
                ),
              ),
              SizedBox(width: large ? 12 : 8),
              Flexible(
                child: Text(
                  step.$2,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontSize: large ? 16 : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (step != steps.last) SizedBox(height: large ? 14 : 8),
        ],
      ],
    );
  }
}
