import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

class TaploeLogo extends StatelessWidget {
  final double size;
  final bool centered;
  final Color? color;
  static const String assetPath = 'assets/images/taploe-logo.png';
  static const double _aspectRatio = 1972 / 760;

  const TaploeLogo({
    super.key,
    this.size = 34,
    this.centered = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final image = kIsWeb
        ? Image.network(
            assetPath,
            height: size,
            width: size * _aspectRatio,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            color: color,
            colorBlendMode: color == null ? null : BlendMode.srcIn,
            errorBuilder: (_, _, _) => _fallbackLogo,
          )
        : Image.asset(
            assetPath,
            height: size,
            width: size * _aspectRatio,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            color: color,
            colorBlendMode: color == null ? null : BlendMode.srcIn,
            errorBuilder: (_, _, _) => _fallbackLogo,
          );
    final logo = Semantics(label: 'Taploe', image: true, child: image);

    return centered ? Center(child: logo) : logo;
  }

  Widget get _fallbackLogo => Text(
    'taploe',
    style: GoogleFonts.outfit(
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: color ?? TaploeColors.black,
    ),
  );
}

class TaploeAssetIcon extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;
  final double size;
  final Color? color;

  const TaploeAssetIcon({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      fallbackIcon,
      size: size,
      color: color ?? TaploeColors.blue,
    );
    return kIsWeb
        ? Image.network(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => fallback,
          );
  }
}

enum TaploeButtonKind { primary, secondary, ghost, danger }

class TaploeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;
  final FaIconData? faIcon;
  final Color? faIconColor;
  final String? assetPath;
  final bool loading;
  final TaploeButtonKind kind;
  final double? width;
  final bool expanded;

  const TaploeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconColor,
    this.faIcon,
    this.faIconColor,
    this.assetPath,
    this.loading = false,
    this.kind = TaploeButtonKind.primary,
    this.width,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = kind == TaploeButtonKind.primary;
    final danger = kind == TaploeButtonKind.danger;
    final ghost = kind == TaploeButtonKind.ghost;

    final bg = primary
        ? TaploeColors.blue
        : danger
        ? TaploeColors.error
        : ghost
        ? Colors.transparent
        : TaploeColors.white;

    final fg = primary || danger ? TaploeColors.white : TaploeColors.black;

    final button = SizedBox(
      width: expanded ? double.infinity : width,
      height: 54,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return primary ? TaploeColors.blueBorder : TaploeColors.subtle;
            }
            if (states.contains(WidgetState.pressed) && primary) {
              return TaploeColors.bluePressed;
            }
            if (states.contains(WidgetState.hovered) && primary) {
              return TaploeColors.blueHover;
            }
            return bg;
          }),
          foregroundColor: WidgetStatePropertyAll(fg),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: primary
                  ? TaploeColors.blue
                  : danger
                  ? TaploeColors.error
                  : ghost
                  ? Colors.transparent
                  : TaploeColors.borderStrong,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TaploeRadius.pill),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (assetPath != null || faIcon != null || icon != null) ...[
                    if (assetPath != null)
                      TaploeAssetIcon(
                        assetPath: assetPath!,
                        fallbackIcon: icon ?? Icons.link_rounded,
                        size: 18,
                      )
                    else if (faIcon != null)
                      FaIcon(faIcon, size: 18, color: faIconColor)
                    else
                      Icon(icon, size: 18, color: iconColor),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );

    return button;
  }
}

class TaploeTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController controller;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const TaploeTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.focusNode,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.text,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction:
              textInputAction ??
              (maxLines == 1 ? TextInputAction.done : TextInputAction.newline),
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            counterText: '',
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class TaploePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;

  const TaploePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = TaploeRadius.card,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? TaploeColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? TaploeColors.border),
      ),
      child: child,
    );
  }
}

class TaploeSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const TaploeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: TaploeColors.blue, size: 24),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: context.text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: GoogleFonts.dmSans(color: context.muted, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

class TaploeEmpty extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const TaploeEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: TaploeColors.blue),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: context.text,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.muted, height: 1.45),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class TaploeModalShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? footer;
  final double maxWidth;
  final bool centeredHeader;

  const TaploeModalShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.footer,
    this.maxWidth = 720,
    this.centeredHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = context.isMobile ? 20.0 : 30.0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.isMobile ? 14 : 32,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TaploeRadius.modal),
          child: Material(
            color: TaploeColors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      28,
                      horizontal,
                      footer == null ? 28 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: centeredHeader
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (leading != null) ...[
                              leading!,
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: centeredHeader
                                    ? CrossAxisAlignment.center
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    textAlign: centeredHeader
                                        ? TextAlign.center
                                        : TextAlign.start,
                                    style: GoogleFonts.outfit(
                                      fontSize: context.isMobile ? 28 : 34,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                      color: context.text,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      subtitle!,
                                      textAlign: centeredHeader
                                          ? TextAlign.center
                                          : TextAlign.start,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        color: context.muted,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
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
                        const SizedBox(height: 26),
                        child,
                      ],
                    ),
                  ),
                ),
                if (footer != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      16,
                      horizontal,
                      20,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: TaploeColors.border),
                      ),
                    ),
                    child: footer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaploeInfoNote extends StatelessWidget {
  final String text;
  final IconData icon;

  const TaploeInfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: TaploeColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                color: TaploeColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaploeToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  const TaploeToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 18,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: TaploeColors.blue, size: 21),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: context.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: context.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class TaploeStepData {
  final IconData icon;
  final String label;
  final bool active;
  final bool completed;

  const TaploeStepData({
    required this.icon,
    required this.label,
    this.active = false,
    this.completed = false,
  });
}

class TaploeStepIndicator extends StatelessWidget {
  final List<TaploeStepData> steps;

  const TaploeStepIndicator({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        if (compact) {
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: steps.map((step) => _StepPill(step: step)).toList(),
          );
        }

        return Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              Expanded(child: _StepPill(step: steps[i])),
              if (i != steps.length - 1)
                Container(
                  width: 40,
                  height: 1,
                  color: TaploeColors.borderStrong,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _StepPill extends StatelessWidget {
  final TaploeStepData step;

  const _StepPill({required this.step});

  @override
  Widget build(BuildContext context) {
    final highlighted = step.active || step.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(TaploeRadius.pill),
        border: Border.all(
          color: step.active ? TaploeColors.blue : TaploeColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            step.completed ? Icons.check_rounded : step.icon,
            size: 17,
            color: highlighted ? TaploeColors.blue : TaploeColors.muted,
          ),
          const SizedBox(width: 7),
          Text(
            step.label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlighted ? TaploeColors.text : TaploeColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

void taploeToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final media = MediaQuery.of(context);
  final topOffset = media.padding.top + 46;
  final bottomMargin = (media.size.height - topOffset - 86).clamp(
    22.0,
    10000.0,
  );
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      elevation: 0,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      content: _TaploeNotificationToast(message: message, error: error),
      margin: EdgeInsets.only(left: 12, right: 12, bottom: bottomMargin),
    ),
  );
}

class _TaploeNotificationToast extends StatelessWidget {
  final String message;
  final bool error;

  const _TaploeNotificationToast({required this.message, required this.error});

  @override
  Widget build(BuildContext context) {
    final color = error ? TaploeColors.error : TaploeColors.success;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 18, 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: BoxDecoration(
              color: TaploeColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TaploeColors.border),
              boxShadow: [
                BoxShadow(
                  color: TaploeColors.black.withValues(alpha: .12),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .38),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        textAlign: TextAlign.start,
                        style: GoogleFonts.dmSans(
                          color: TaploeColors.black,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    tooltip: 'Cerrar',
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onPressed: () =>
                        ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: TaploeColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  const PageShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = context.isMobile ? 18.0 : 32.0;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 30, horizontal, 16),
            child: context.isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PageTitle(title: title, subtitle: subtitle),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PageTitle(title: title, subtitle: subtitle),
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(width: 20),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    ],
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 36),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _PageTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: context.isMobile ? 32 : 42,
            height: .95,
            fontWeight: FontWeight.w600,
            color: context.text,
            letterSpacing: 0,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: context.muted,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}
