import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'localization.dart';
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
  final Widget? installPanel;
  final bool framed;
  final bool allowVerifiedBadge;
  final bool allowCustomDesign;
  final bool allowForms;
  final bool allowIntegrations;
  final bool showTaploeWatermark;

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
    this.installPanel,
    this.framed = false,
    this.allowVerifiedBadge = true,
    this.allowCustomDesign = true,
    this.allowForms = true,
    this.allowIntegrations = true,
    this.showTaploeWatermark = false,
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
    final t = TaploeTextCatalog(
      TaploeLocaleConfig.fromLocaleParam(profile.publicLocale),
    );
    final links = widget.links;
    final forms = widget.forms;
    final integrations = widget.integrations;
    final framed = widget.framed;
    final phoneWidth = framed ? 390.0 : 430.0;
    final phoneHeight = framed ? 844.0 : 932.0;
    final avatarRadius = framed ? 46.0 : 60.0;
    final headerHeight = framed ? 214.0 : 270.0;
    final coverHeight = headerHeight - avatarRadius;
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
    final directLinks = sortedLinks
        .where(
          (link) =>
              link.linkType != 'email' &&
              link.linkType != 'calendar' &&
              !_isSocialOrWebsiteLink(link),
        )
        .toList();
    final visibleForms = widget.allowForms
        ? forms.where((form) => form.isActive).toList()
        : <SmartFormModel>[];
    final visibleIntegrations = widget.allowIntegrations
        ? integrations.where((integration) => integration.isEnabled).toList()
        : <ProfileIntegrationModel>[];
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
    final coverUrl = widget.allowCustomDesign ? profile.coverPhotoUrl : null;
    final logoUrl = widget.allowCustomDesign ? profile.logoUrl : null;
    final theme = widget.allowCustomDesign
        ? profile.theme ?? ProfileThemeModel(profileId: profile.id)
        : ProfileThemeModel(profileId: profile.id);
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
      fontSize: framed ? 28 : 36,
      fontWeight: FontWeight.w600,
      color: contentColor,
      height: 1.05,
    );
    final companyStyle = _profileFont(
      theme.fontFamily,
      fontSize: framed ? 16 : 19,
      fontWeight: FontWeight.w600,
      color: contentColor,
      height: 1.1,
    );
    final roleStyle = _profileFont(
      theme.fontFamily,
      fontSize: framed ? 15 : 18,
      fontWeight: FontWeight.w600,
      color: mutedColor,
      height: 1.16,
    );
    final bioStyle = _profileFont(
      theme.fontFamily,
      fontSize: framed ? 12 : 15,
      fontWeight: FontWeight.w500,
      color: mutedColor,
      height: 1.32,
    );
    final sectionStyle = _profileFont(
      theme.fontFamily,
      fontSize: framed ? 16 : 22,
      fontWeight: FontWeight.w600,
      color: contentColor,
    );
    final companyName = profile.companyName?.trim() ?? '';
    final jobTitle = profile.jobTitle?.trim() ?? '';
    final bio = profile.bio?.trim() ?? '';

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
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [backgroundStart, backgroundEnd],
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
          Positioned(
            top: framed ? 52 : 56,
            child: logoUrl == null || logoUrl.isEmpty
                ? widget.showTaploeWatermark
                      ? TaploeLogo(
                          size: framed ? 40 : 48,
                          centered: true,
                          color: TaploeColors.black,
                        )
                      : SizedBox(height: framed ? 44 : 52)
                : Image.network(
                    logoUrl,
                    height: framed ? 44 : 52,
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
                        fontWeight: FontWeight.w600,
                        fontSize: framed ? 30 : 38,
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
            if (widget.allowVerifiedBadge && profile.showVerifiedBadge) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.verified_rounded,
                color: const Color(0xFF1DA1F2),
                size: framed ? 20 : 25,
              ),
            ],
          ],
        ),
        if (companyName.isNotEmpty) ...[
          SizedBox(height: framed ? 7 : 7),
          Text(companyName, textAlign: TextAlign.center, style: companyStyle),
        ],
        if (jobTitle.isNotEmpty) ...[
          SizedBox(height: framed ? 5 : 5),
          Text(jobTitle, textAlign: TextAlign.center, style: roleStyle),
        ],
        if (bio.isNotEmpty) ...[
          SizedBox(height: framed ? 9 : 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: framed ? 10 : 18),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: bioStyle,
            ),
          ),
        ],
        SizedBox(height: framed ? 16 : 22),
        _PublicActionButton(
          label: t.saveContact,
          icon: Icons.person_add_alt_1_rounded,
          primary: true,
          primaryColor: actionColor,
          primaryForeground: actionForeground,
          accentColor: accentColor,
          surfaceColor: surfaceColor,
          outlineColor: outlineColor,
          radius: buttonRadius,
          fontFamily: theme.fontFamily,
          compact: framed,
          onTap: widget.onSaveContact,
        ),
        SizedBox(height: framed ? 10 : 14),
        if (emailLink == null)
          _PublicActionButton(
            label: t.share,
            icon: Icons.share_rounded,
            primaryColor: primaryColor,
            accentColor: accentColor,
            textColor: contentColor,
            surfaceColor: surfaceColor,
            outlineColor: outlineColor,
            radius: buttonRadius,
            fontFamily: theme.fontFamily,
            compact: framed,
            onTap: widget.onShare,
          )
        else
          Row(
            children: [
              Expanded(
                child: _PublicActionButton(
                  label: t.sendMail,
                  icon: Icons.email_rounded,
                  primaryColor: primaryColor,
                  accentColor: accentColor,
                  textColor: contentColor,
                  surfaceColor: surfaceColor,
                  outlineColor: outlineColor,
                  radius: buttonRadius,
                  fontFamily: theme.fontFamily,
                  compact: framed,
                  onTap: () => widget.onOpenLink?.call(emailLink),
                ),
              ),
              SizedBox(width: framed ? 8 : 12),
              Expanded(
                child: _PublicActionButton(
                  label: t.share,
                  icon: Icons.share_rounded,
                  primaryColor: primaryColor,
                  accentColor: accentColor,
                  textColor: contentColor,
                  surfaceColor: surfaceColor,
                  outlineColor: outlineColor,
                  radius: buttonRadius,
                  fontFamily: theme.fontFamily,
                  compact: framed,
                  onTap: widget.onShare,
                ),
              ),
            ],
          ),
        if (widget.installPanel != null) ...[
          const SizedBox(height: 16),
          widget.installPanel!,
        ],
        if (socialLinks.isNotEmpty) ...[
          SizedBox(height: framed ? 18 : 24),
          _SectionTitle(t.connectWithMe, style: sectionStyle),
          SizedBox(height: framed ? 10 : 14),
          Wrap(
            spacing: framed ? 10 : 14,
            runSpacing: framed ? 10 : 12,
            children: [
              for (final link in socialLinks)
                _SocialCircle(
                  link: link,
                  surfaceColor: surfaceColor,
                  outlineColor: outlineColor,
                  compact: framed,
                  onTap: () => widget.onOpenLink?.call(link),
                ),
            ],
          ),
        ],
        if (directLinks.isNotEmpty) ...[
          SizedBox(height: framed ? 18 : 24),
          _SectionTitle(t.contact, style: sectionStyle),
          SizedBox(height: framed ? 10 : 14),
          for (final link in directLinks) ...[
            _PublicActionButton(
              label: link.label.isEmpty
                  ? _defaultLinkLabel(link.linkType)
                  : link.label,
              icon: _publicLinkIcon(link.linkType),
              trailing: Icons.arrow_forward_rounded,
              primaryColor: primaryColor,
              accentColor: accentColor,
              textColor: contentColor,
              surfaceColor: surfaceColor,
              outlineColor: outlineColor,
              radius: buttonRadius,
              fontFamily: theme.fontFamily,
              compact: framed,
              onTap: () => widget.onOpenLink?.call(link),
            ),
            SizedBox(height: framed ? 8 : 10),
          ],
        ],
        if (calendarLink != null || calendarIntegration != null) ...[
          SizedBox(height: framed ? 18 : 24),
          _SectionTitle(t.scheduleMeeting, style: sectionStyle),
          SizedBox(height: framed ? 10 : 14),
          _PublicActionButton(
            label: calendarLink != null
                ? (calendarLink.label.isEmpty
                      ? t.scheduleMeeting
                      : calendarLink.label)
                : (calendarIntegration?.displayLabel?.isNotEmpty == true
                      ? calendarIntegration!.displayLabel!
                      : t.scheduleMeeting),
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
            compact: framed,
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
          SizedBox(height: framed ? 18 : 26),
          _SectionTitle(t.tools, style: sectionStyle),
          SizedBox(height: framed ? 10 : 12),
          Wrap(
            spacing: framed ? 8 : 10,
            runSpacing: framed ? 8 : 10,
            children: [
              for (final integration in visibleIntegrations.where(
                (item) => item.integration?.integrationType != 'calendar',
              ))
                _PublicMiniPill(
                  label:
                      integration.displayLabel ??
                      integration.integration?.provider ??
                      t.text('Integración', 'Integration'),
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
          SizedBox(height: framed ? 18 : 26),
          _SectionTitle(t.contactForm, style: sectionStyle),
          SizedBox(height: framed ? 10 : 12),
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
              compact: framed,
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
      child: framed
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                    child: content,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: content,
                ),
              ],
            ),
    );

    if (!framed) {
      return surface;
    }

    return SizedBox(
      width: phoneWidth,
      height: phoneHeight,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: TaploeColors.black.withValues(alpha: .18),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(11, 15, 11, 11),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.topCenter,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(39), child: surface),
            Positioned(
              top: 6,
              child: Container(
                width: 112,
                height: 27,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
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
  final bool compact;
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
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = primary ? primaryColor : surfaceColor;
    final foreground = primary ? primaryForeground : textColor;
    final iconSize = compact ? 21.0 : 26.0;
    final labelSize = compact ? 16.5 : 18.0;
    final trailingSize = compact ? 24.0 : 30.0;
    final gap = compact ? 8.0 : 12.0;
    final text = Text(
      label,
      maxLines: 1,
      style: _profileFont(
        fontFamily,
        color: foreground,
        fontSize: labelSize,
        fontWeight: FontWeight.w600,
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 50 : 62),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? (primary ? 16 : 12) : (primary ? 20 : 16),
        ),
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
            Icon(
              icon,
              color: primary ? foreground : accentColor,
              size: iconSize,
            ),
            SizedBox(width: gap),
            if (trailing == null)
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: text),
              )
            else
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: text,
                  ),
                ),
              ),
            if (trailing != null) ...[
              SizedBox(width: gap),
              Icon(trailing, color: foreground, size: trailingSize),
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
  final bool compact;
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
    this.compact = false,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownRadius = radius > 28 ? 28.0 : radius;
    final iconSize = compact ? 21.0 : 26.0;
    final labelSize = compact ? 16.5 : 18.0;
    final trailingSize = compact ? 24.0 : 30.0;
    final gap = compact ? 8.0 : 12.0;
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
              height: compact ? 50 : 62,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.dynamic_form_outlined,
                      color: accentColor,
                      size: iconSize,
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _profileFont(
                          fontFamily,
                          color: textColor,
                          fontSize: labelSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: textColor,
                      size: trailingSize,
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
                  fontWeight: FontWeight.w600,
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
  final bool compact;
  final VoidCallback? onTap;

  const _SocialCircle({
    required this.link,
    required this.surfaceColor,
    required this.outlineColor,
    this.compact = false,
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
        width: compact ? 52 : 66,
        height: compact ? 52 : 66,
        decoration: BoxDecoration(
          color: surfaceColor,
          shape: BoxShape.circle,
          border: Border.all(color: outlineColor),
        ),
        child: Center(
          child: faIcon == null
              ? Icon(
                  Icons.language_rounded,
                  color: color,
                  size: compact ? 30 : 38,
                )
              : FaIcon(faIcon, color: color, size: compact ? 29 : 36),
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

bool _isSocialOrWebsiteLink(ProfileLinkModel link) {
  return _socialIconFor(link.linkType) != null || link.linkType == 'website';
}

IconData _publicLinkIcon(String type) {
  switch (type) {
    case 'phone':
      return Icons.phone_outlined;
    case 'maps':
      return Icons.location_on_outlined;
    case 'catalog':
    case 'file':
      return Icons.description_outlined;
    case 'payment':
      return Icons.payments_outlined;
    default:
      return Icons.link_rounded;
  }
}

String _defaultLinkLabel(String type) {
  switch (type) {
    case 'phone':
      return 'Call';
    case 'maps':
      return 'Location';
    case 'catalog':
      return 'Catalog';
    case 'file':
      return 'File';
    case 'payment':
      return 'Payment';
    default:
      return 'Open link';
  }
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
      return fontWeight.value >= FontWeight.w600.value
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
