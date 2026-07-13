import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets.dart';

class TaploePublicProfileCard extends StatefulWidget {
  final DigitalProfileModel profile;
  final List<ProfileLinkModel> links;
  final List<SmartFormModel> forms;
  final List<ProfileIntegrationModel> integrations;
  final VoidCallback? onSaveContact;
  final VoidCallback? onShare;
  final ValueChanged<ProfileLinkModel>? onOpenLink;
  final ValueChanged<SmartFormModel>? onOpenForm;
  final ValueChanged<ProfileIntegrationModel>? onOpenIntegration;
  final Widget Function(SmartFormModel form)? formBuilder;
  final bool framed;

  const TaploePublicProfileCard({
    super.key,
    required this.profile,
    required this.links,
    this.forms = const [],
    this.integrations = const [],
    this.onSaveContact,
    this.onShare,
    this.onOpenLink,
    this.onOpenForm,
    this.onOpenIntegration,
    this.formBuilder,
    this.framed = false,
  });

  @override
  State<TaploePublicProfileCard> createState() =>
      _TaploePublicProfileCardState();
}

class _TaploePublicProfileCardState extends State<TaploePublicProfileCard> {
  final Set<String> expandedFormIds = {};

  void _toggleForm(SmartFormModel form) {
    setState(() {
      if (!expandedFormIds.add(form.id)) {
        expandedFormIds.remove(form.id);
      }
    });
    widget.onOpenForm?.call(form);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final links = widget.links;
    final forms = widget.forms;
    final integrations = widget.integrations;
    final framed = widget.framed;
    const phoneWidth = 430.0;
    const phoneHeight = 932.0;
    const avatarRadius = 62.0;
    const headerHeight = 326.0;
    const coverHeight = headerHeight - avatarRadius;
    final sortedLinks = links.where((link) => link.isVisible).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final socialLinks = sortedLinks
        .where(
          (link) =>
              _socialIconFor(link.linkType) != null ||
              link.linkType == 'website',
        )
        .toList();
    final emailLink = _firstLink(sortedLinks, 'email');
    final calendarLink = _firstLink(sortedLinks, 'calendar');
    final visibleForms = forms.where((form) => form.isActive).toList();
    final visibleIntegrations = integrations
        .where((integration) => integration.isEnabled)
        .toList();
    final calendarIntegrations = visibleIntegrations
        .where(
          (integration) =>
              integration.integration?.integrationType == 'calendar' &&
              integration.integration?.publicUrl?.trim().isNotEmpty == true,
        )
        .toList();
    final calendarIntegration = calendarIntegrations.isEmpty
        ? null
        : calendarIntegrations.first;
    final coverUrl = profile.coverPhotoUrl;
    final logoUrl = profile.logoUrl;
    final theme = profile.theme ?? ProfileThemeModel(profileId: profile.id);
    final primaryColor = _colorFromHex(
      theme.primaryColor,
      fallback: TaploeColors.blue,
    );
    final accentColor = _colorFromHex(
      theme.accentColor,
      fallback: primaryColor,
    );
    final backgroundStart = _colorFromHex(
      theme.backgroundColorStart,
      fallback: TaploeColors.white,
    );
    final backgroundEnd = _colorFromHex(
      theme.backgroundColorEnd ?? theme.backgroundColorStart,
      fallback: backgroundStart,
    );
    final isDark = backgroundStart.computeLuminance() < .45;
    final contentColor = isDark ? TaploeColors.white : TaploeColors.black;
    final mutedColor = isDark
        ? TaploeColors.white.withValues(alpha: .78)
        : TaploeColors.black;
    final surfaceColor = isDark
        ? TaploeColors.white.withValues(alpha: .10)
        : TaploeColors.white;
    final outlineColor = isDark
        ? TaploeColors.white.withValues(alpha: .20)
        : TaploeColors.border;
    final actionColor = _bestActionColor(
      primaryColor: primaryColor,
      accentColor: accentColor,
      backgroundColor: backgroundStart,
    );
    final actionForeground = actionColor.computeLuminance() > .62
        ? TaploeColors.black
        : TaploeColors.white;
    final buttonRadius = switch (theme.buttonStyle) {
      'square' => 10.0,
      'rounded' => 18.0,
      _ => 999.0,
    };
    final headingStyle = _profileFont(
      theme.fontFamily,
      fontSize: 34,
      fontWeight: FontWeight.w900,
      color: contentColor,
      height: 1.05,
    );
    final bodyStyle = _profileFont(
      theme.fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: mutedColor,
      height: 1.12,
    );
    final sectionStyle = _profileFont(
      theme.fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w900,
      color: contentColor,
    );
    final jobLine = [
      profile.jobTitle,
      profile.companyName,
    ].where((value) => value?.trim().isNotEmpty == true).join(' and ');

    final header = SizedBox(
      height: headerHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: coverHeight,
            child: coverUrl == null || coverUrl.isEmpty
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF9FAFB), Color(0xFFEFF2F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  )
                : Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
          ),
          if (framed)
            Positioned(
              top: 16,
              child: Container(
                width: 126,
                height: 32,
                decoration: BoxDecoration(
                  color: TaploeColors.black,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          Positioned(
            top: framed ? 96 : 72,
            child: logoUrl == null || logoUrl.isEmpty
                ? TaploeLogo(
                    size: 48,
                    centered: true,
                    color: TaploeColors.black,
                  )
                : Image.network(
                    logoUrl,
                    height: 54,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
          ),
          Positioned(
            bottom: 0,
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: const Color(0xFFE5E7EB),
              backgroundImage:
                  profile.profilePhotoUrl == null ||
                      profile.profilePhotoUrl!.isEmpty
                  ? null
                  : NetworkImage(profile.profilePhotoUrl!),
              child:
                  profile.profilePhotoUrl == null ||
                      profile.profilePhotoUrl!.isEmpty
                  ? Text(
                      initials(profile.displayName),
                      style: _profileFont(
                        theme.fontFamily,
                        color: TaploeColors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                profile.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: headingStyle,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFF1DA1F2),
              size: 24,
            ),
          ],
        ),
        if (jobLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(jobLine, textAlign: TextAlign.center, style: bodyStyle),
        ],
        const SizedBox(height: 30),
        _PublicActionButton(
          label: 'Save contact',
          icon: Icons.person_add_alt_1_rounded,
          primary: true,
          primaryColor: actionColor,
          primaryForeground: actionForeground,
          accentColor: accentColor,
          surfaceColor: surfaceColor,
          outlineColor: outlineColor,
          radius: buttonRadius,
          fontFamily: theme.fontFamily,
          onTap: widget.onSaveContact,
        ),
        const SizedBox(height: 14),
        if (emailLink == null)
          _PublicActionButton(
            label: 'Share',
            icon: Icons.share_rounded,
            primaryColor: primaryColor,
            accentColor: accentColor,
            textColor: contentColor,
            surfaceColor: surfaceColor,
            outlineColor: outlineColor,
            radius: buttonRadius,
            fontFamily: theme.fontFamily,
            onTap: widget.onShare,
          )
        else
          Row(
            children: [
              Expanded(
                child: _PublicActionButton(
                  label: 'Send mail',
                  icon: Icons.email_rounded,
                  primaryColor: primaryColor,
                  accentColor: accentColor,
                  textColor: contentColor,
                  surfaceColor: surfaceColor,
                  outlineColor: outlineColor,
                  radius: buttonRadius,
                  fontFamily: theme.fontFamily,
                  onTap: () => widget.onOpenLink?.call(emailLink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PublicActionButton(
                  label: 'Share',
                  icon: Icons.share_rounded,
                  primaryColor: primaryColor,
                  accentColor: accentColor,
                  textColor: contentColor,
                  surfaceColor: surfaceColor,
                  outlineColor: outlineColor,
                  radius: buttonRadius,
                  fontFamily: theme.fontFamily,
                  onTap: widget.onShare,
                ),
              ),
            ],
          ),
        if (socialLinks.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionTitle('Connect with me', style: sectionStyle),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              for (final link in socialLinks)
                _SocialCircle(
                  link: link,
                  surfaceColor: surfaceColor,
                  outlineColor: outlineColor,
                  onTap: () => widget.onOpenLink?.call(link),
                ),
            ],
          ),
        ],
        if (calendarLink != null || calendarIntegration != null) ...[
          const SizedBox(height: 30),
          _SectionTitle('Schedule a meeting', style: sectionStyle),
          const SizedBox(height: 14),
          _PublicActionButton(
            label: calendarLink != null
                ? (calendarLink.label.isEmpty
                      ? 'Schedule meeting'
                      : calendarLink.label)
                : (calendarIntegration?.displayLabel?.isNotEmpty == true
                      ? calendarIntegration!.displayLabel!
                      : 'Schedule meeting'),
            icon: Icons.calendar_month_rounded,
            trailing: Icons.arrow_forward_rounded,
            primary: true,
            primaryColor: actionColor,
            primaryForeground: actionForeground,
            accentColor: accentColor,
            surfaceColor: surfaceColor,
            outlineColor: outlineColor,
            radius: buttonRadius,
            fontFamily: theme.fontFamily,
            onTap: () {
              if (calendarLink != null) {
                widget.onOpenLink?.call(calendarLink);
              } else if (calendarIntegration != null) {
                widget.onOpenIntegration?.call(calendarIntegration);
              }
            },
          ),
        ],
        if (visibleIntegrations
            .where(
              (integration) =>
                  integration.integration?.integrationType != 'calendar',
            )
            .isNotEmpty) ...[
          const SizedBox(height: 26),
          _SectionTitle('Tools', style: sectionStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final integration in visibleIntegrations.where(
                (item) => item.integration?.integrationType != 'calendar',
              ))
                _PublicMiniPill(
                  label:
                      integration.displayLabel ??
                      integration.integration?.provider ??
                      'Integración',
                  icon: _integrationIcon(
                    integration.integration?.integrationType,
                  ),
                  accentColor: accentColor,
                  surfaceColor: surfaceColor,
                  outlineColor: outlineColor,
                  textColor: contentColor,
                  fontFamily: theme.fontFamily,
                  onTap: () => widget.onOpenIntegration?.call(integration),
                ),
            ],
          ),
        ],
        if (visibleForms.isNotEmpty) ...[
          const SizedBox(height: 26),
          _SectionTitle('Contact form', style: sectionStyle),
          const SizedBox(height: 12),
          for (final form in visibleForms.take(2)) ...[
            _PublicFormDropdown(
              label: form.name,
              expanded: expandedFormIds.contains(form.id),
              primaryColor: primaryColor,
              accentColor: accentColor,
              textColor: contentColor,
              surfaceColor: surfaceColor,
              outlineColor: outlineColor,
              radius: buttonRadius,
              fontFamily: theme.fontFamily,
              onTap: () => _toggleForm(form),
              child: widget.formBuilder?.call(form),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );

    final surface = Container(
      decoration: BoxDecoration(
        color: theme.backgroundType == 'gradient' ? null : backgroundStart,
        gradient: theme.backgroundType == 'gradient'
            ? LinearGradient(
                colors: [backgroundStart, backgroundEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(framed ? 32 : 28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: framed ? MainAxisSize.max : MainAxisSize.min,
        children: [
          header,
          if (framed)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: content,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: content,
            ),
        ],
      ),
    );

    final card = framed
        ? SizedBox(width: phoneWidth, height: phoneHeight, child: surface)
        : surface;

    if (!framed) {
      return card;
    }

    final scaledCard = FittedBox(fit: BoxFit.contain, child: card);

    return AspectRatio(
      aspectRatio: phoneWidth / phoneHeight,
      child: Container(
        decoration: BoxDecoration(
          color: TaploeColors.black,
          borderRadius: BorderRadius.circular(38),
          border: Border.all(color: TaploeColors.black, width: 6),
        ),
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: scaledCard,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _SectionTitle(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }
}

class _PublicActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData? trailing;
  final bool primary;
  final Color primaryColor;
  final Color primaryForeground;
  final Color accentColor;
  final Color textColor;
  final Color surfaceColor;
  final Color outlineColor;
  final double radius;
  final String fontFamily;
  final VoidCallback? onTap;

  const _PublicActionButton({
    required this.label,
    required this.icon,
    this.trailing,
    this.primary = false,
    this.primaryColor = TaploeColors.blue,
    this.primaryForeground = TaploeColors.white,
    this.accentColor = TaploeColors.blue,
    this.textColor = TaploeColors.black,
    this.surfaceColor = TaploeColors.white,
    this.outlineColor = TaploeColors.border,
    this.radius = 18,
    this.fontFamily = 'system',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = primary ? primaryColor : surfaceColor;
    final foreground = primary ? primaryForeground : textColor;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: primary ? primaryColor : outlineColor,
            width: primary ? 0 : 1.3,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? foreground : accentColor, size: 26),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _profileFont(
                  fontFamily,
                  color: foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Icon(trailing, color: foreground, size: 30),
            ],
          ],
        ),
      ),
    );
  }
}

class _PublicFormDropdown extends StatelessWidget {
  final String label;
  final bool expanded;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;
  final Color surfaceColor;
  final Color outlineColor;
  final double radius;
  final String fontFamily;
  final VoidCallback? onTap;
  final Widget? child;

  const _PublicFormDropdown({
    required this.label,
    required this.expanded,
    required this.primaryColor,
    required this.accentColor,
    required this.textColor,
    required this.surfaceColor,
    required this.outlineColor,
    required this.radius,
    required this.fontFamily,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownRadius = radius > 28 ? 28.0 : radius;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(dropdownRadius),
        border: Border.all(color: outlineColor, width: 1.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 62,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.dynamic_form_outlined,
                      color: accentColor,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _profileFont(
                          fontFamily,
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: textColor,
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded && child != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: child!,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PublicMiniPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final Color surfaceColor;
  final Color outlineColor;
  final Color textColor;
  final String fontFamily;
  final VoidCallback? onTap;

  const _PublicMiniPill({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.surfaceColor,
    required this.outlineColor,
    required this.textColor,
    required this.fontFamily,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 48,
        constraints: const BoxConstraints(maxWidth: 188),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: outlineColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _profileFont(
                  fontFamily,
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialCircle extends StatelessWidget {
  final ProfileLinkModel link;
  final Color surfaceColor;
  final Color outlineColor;
  final VoidCallback? onTap;

  const _SocialCircle({
    required this.link,
    required this.surfaceColor,
    required this.outlineColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final faIcon = _socialIconFor(link.linkType);
    final color = _brandColorFor(link.linkType);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: surfaceColor,
          shape: BoxShape.circle,
          border: Border.all(color: outlineColor),
        ),
        child: Center(
          child: faIcon == null
              ? Icon(Icons.language_rounded, color: color, size: 38)
              : FaIcon(faIcon, color: color, size: 36),
        ),
      ),
    );
  }
}

ProfileLinkModel? _firstLink(List<ProfileLinkModel> links, String type) {
  for (final link in links) {
    if (link.linkType == type) return link;
  }
  return null;
}

IconData _integrationIcon(String? type) {
  switch (type) {
    case 'calendar':
      return Icons.calendar_month_rounded;
    case 'crm':
      return Icons.groups_outlined;
    case 'automation':
      return Icons.bolt_rounded;
    case 'payments':
      return Icons.payments_outlined;
    default:
      return Icons.extension_outlined;
  }
}

FaIconData? _socialIconFor(String type) {
  switch (type) {
    case 'linkedin':
      return FontAwesomeIcons.linkedin;
    case 'instagram':
      return FontAwesomeIcons.instagram;
    case 'whatsapp':
      return FontAwesomeIcons.whatsapp;
    case 'tiktok':
      return FontAwesomeIcons.tiktok;
    case 'facebook':
      return FontAwesomeIcons.facebook;
    case 'x':
      return FontAwesomeIcons.xTwitter;
    case 'youtube':
      return FontAwesomeIcons.youtube;
    case 'website':
      return null;
    default:
      return null;
  }
}

Color _brandColorFor(String type) {
  switch (type) {
    case 'linkedin':
      return const Color(0xFF0A66C2);
    case 'instagram':
      return const Color(0xFFE1306C);
    case 'whatsapp':
      return const Color(0xFF25D366);
    case 'facebook':
      return const Color(0xFF1877F2);
    case 'youtube':
      return const Color(0xFFFF0000);
    case 'tiktok':
    case 'x':
      return TaploeColors.black;
    case 'website':
      return TaploeColors.black;
    default:
      return TaploeColors.blue;
  }
}

Color _colorFromHex(String value, {required Color fallback}) {
  final clean = value.replaceAll('#', '').trim();
  if (clean.length != 6) return fallback;
  final parsed = int.tryParse('FF$clean', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

Color _bestActionColor({
  required Color primaryColor,
  required Color accentColor,
  required Color backgroundColor,
}) {
  if (_contrastRatio(primaryColor, backgroundColor) >= 3) {
    return primaryColor;
  }
  if (_contrastRatio(accentColor, backgroundColor) >= 3) {
    return accentColor;
  }
  return backgroundColor.computeLuminance() > .5
      ? TaploeColors.black
      : TaploeColors.white;
}

double _contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + .05) / (darker + .05);
}

TextStyle _profileFont(
  String family, {
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  double? height,
}) {
  switch (family) {
    case 'poppins':
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    case 'montserrat':
      return GoogleFonts.montserrat(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    default:
      return fontWeight.value >= FontWeight.w800.value
          ? GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            )
          : GoogleFonts.dmSans(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
  }
}
