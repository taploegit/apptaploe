import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide IconButton, Text;
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../company_logo_drop.dart';
import '../localization.dart';
import '../localized_text.dart';
import '../models.dart';
import '../plan_capabilities.dart';
import '../pricing.dart';
import '../profile_public_card.dart';
import '../pwa_install_panel.dart';
import '../qr_scanner.dart';
import '../redirect_navigation.dart';
import '../realtime.dart';
import '../repositories.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

class DashboardView extends StatefulWidget {
  final DashboardSection initialSection;
  final int initialProfileStep;

  const DashboardView({
    super.key,
    this.initialSection = DashboardSection.home,
    this.initialProfileStep = 0,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

enum DashboardSection {
  home,
  profile,
  cards,
  redirects,
  share,
  analytics,
  leads,
  team,
  admin,
  settings,
}

bool _canEditProfile(DigitalProfileModel? profile) {
  if (profile == null) return false;
  return taploeState.profiles.any((item) => item.id == profile.id);
}

bool _hasActivePaidPlan() => taploeState.capabilities.hasPremiumFeatures;

BillingSubscriptionModel? _effectiveBillingSubscription() =>
    taploeState.organizationSubscription ?? taploeState.userSubscription;

bool _canViewDashboardSection(DashboardSection section) {
  final capabilities = taploeState.capabilities;
  switch (section) {
    case DashboardSection.analytics:
      return capabilities.canViewAnalytics;
    case DashboardSection.leads:
      return capabilities.canViewLeads;
    case DashboardSection.team:
      return capabilities.canViewTeam;
    case DashboardSection.admin:
      return capabilities.canViewAdmin;
    case DashboardSection.home:
    case DashboardSection.profile:
    case DashboardSection.cards:
    case DashboardSection.redirects:
    case DashboardSection.share:
    case DashboardSection.settings:
      return true;
  }
}

DashboardSection _allowedDashboardSection(DashboardSection section) => section;

void _selectDashboardSection(
  BuildContext context,
  ValueChanged<DashboardSection> select,
  DashboardSection section,
) {
  select(section);
}

class _DashboardViewState extends State<DashboardView> {
  late DashboardSection section;
  bool _entryDialogShown = false;
  bool _showInitialCardLinkPrompt = false;

  @override
  void initState() {
    super.initState();
    section = _allowedDashboardSection(widget.initialSection);
    taploeState.addListener(_handleTaploeStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowEntryDialog();
    });
  }

  @override
  void dispose() {
    taploeState.removeListener(_handleTaploeStateChanged);
    super.dispose();
  }

  void _handleTaploeStateChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowEntryDialog();
    });
  }

  void _maybeShowEntryDialog() {
    if (!mounted || _entryDialogShown) return;
    if (taploeState.bootstrapping || !taploeState.canAccessDashboard) return;
    if (_hasActivePaidPlan()) return;
    if (_showInitialCardLinkPrompt && !taploeState.hasLinkedCard) return;
    _entryDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _DashboardEntryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (taploeState.bootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!taploeState.canAccessDashboard) {
      return _ProfileRequiredView(
        onProfileCreated: (profile) {
          if (!context.mounted) return;
          setState(() {
            section = DashboardSection.profile;
            _showInitialCardLinkPrompt = !taploeState.hasLinkedCard;
          });
        },
      );
    }

    if (_showInitialCardLinkPrompt && !taploeState.hasLinkedCard) {
      return _InitialCardLinkView(
        onLinkCard: () => _showCardLinkingDialog(context),
        onSkip: () {
          setState(() => _showInitialCardLinkPrompt = false);
          context.go('/profile');
        },
      );
    }

    final mobileSections = [
      DashboardSection.home,
      DashboardSection.profile,
      DashboardSection.redirects,
      DashboardSection.share,
      DashboardSection.analytics,
      DashboardSection.leads,
    ];
    final mobileSelectedIndex = mobileSections.indexOf(section);
    final t = TaploeTextScope.of(context);

    return Scaffold(
      backgroundColor: TaploeColors.page,
      appBar: context.isMobile
          ? AppBar(title: const TaploeLogo(size: 30))
          : null,
      body: Row(
        children: [
          if (!context.isMobile)
            _Sidebar(
              selected: section,
              onSelected: (s) => _selectDashboardSection(
                context,
                (next) => setState(() => section = next),
                s,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                if (!context.isMobile)
                  _TopHeader(
                    selected: section,
                    onSelected: (s) => _selectDashboardSection(
                      context,
                      (next) => setState(() => section = next),
                      s,
                    ),
                  ),
                Expanded(child: _content()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: context.isMobile
          ? NavigationBar(
              selectedIndex: mobileSelectedIndex < 0 ? 0 : mobileSelectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => section = mobileSections[i]),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.space_dashboard_outlined),
                  label: t.home,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  label: t.text('Perfil', 'Profile'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.alt_route_rounded),
                  label: t.text('Redirección', 'Redirects'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.ios_share_rounded),
                  label: t.share,
                ),
                NavigationDestination(
                  icon: _PlanLockedNavIcon(
                    icon: Icons.insights_rounded,
                    locked: !taploeState.capabilities.canViewAnalytics,
                  ),
                  label: t.text('Métricas', 'Metrics'),
                ),
                NavigationDestination(
                  icon: _PlanLockedNavIcon(
                    icon: Icons.handshake_outlined,
                    locked: !taploeState.capabilities.canViewLeads,
                  ),
                  label: 'Leads',
                ),
              ],
            )
          : null,
    );
  }

  Widget _content() {
    if (!_canViewDashboardSection(section)) {
      return _PlanLockedSectionView(section: section);
    }
    switch (section) {
      case DashboardSection.home:
        return HomeOverviewView(
          onSelected: (s) => _selectDashboardSection(
            context,
            (next) => setState(() => section = next),
            s,
          ),
        );
      case DashboardSection.profile:
        return ProfileEditorView(
          initialStep: widget.initialProfileStep,
          onManageCompanyLogo: () =>
              setState(() => section = DashboardSection.admin),
        );
      case DashboardSection.cards:
        return const CardManagerView();
      case DashboardSection.redirects:
        return const RedirectManagerView();
      case DashboardSection.share:
        return const ShareCenterView();
      case DashboardSection.analytics:
        return const AnalyticsDashboardView();
      case DashboardSection.leads:
        return const LeadsView();
      case DashboardSection.team:
        return const TeamView();
      case DashboardSection.admin:
        return AdminView(
          onEditProfile: (profile) {
            taploeState.setActiveProfile(profile);
            setState(() => section = DashboardSection.profile);
          },
          onManageTeam: () => setState(() => section = DashboardSection.team),
        );
      case DashboardSection.settings:
        return const SettingsView();
    }
  }
}

class _PlanLockedNavIcon extends StatelessWidget {
  final IconData icon;
  final bool locked;

  const _PlanLockedNavIcon({required this.icon, required this.locked});

  @override
  Widget build(BuildContext context) {
    if (!locked) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        const Positioned(
          right: -7,
          top: -7,
          child: FaIcon(
            FontAwesomeIcons.crown,
            color: Color(0xFFF5C84C),
            size: 10,
          ),
        ),
      ],
    );
  }
}

class _PlanLockedSectionView extends StatelessWidget {
  final DashboardSection section;

  const _PlanLockedSectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    if (section == DashboardSection.analytics) {
      return const _AnalyticsLockedPreviewView();
    }
    if (section == DashboardSection.leads) {
      return const _LeadsLockedPreviewView();
    }
    if (section == DashboardSection.team) {
      return const _TeamLockedPreviewView();
    }
    if (section == DashboardSection.admin) {
      return const _AdminLockedPreviewView();
    }
    final requiredPlan = switch (section) {
      DashboardSection.team || DashboardSection.admin => 'Empresa',
      _ => 'Premium',
    };
    final title = switch (section) {
      DashboardSection.analytics => 'Analítica',
      DashboardSection.leads => 'Leads',
      DashboardSection.team => 'Equipo',
      DashboardSection.admin => 'Administración',
      _ => 'Función premium',
    };
    final message = switch (section) {
      DashboardSection.analytics =>
        'Consulta vistas, clics, canales y rendimiento detallado de tus perfiles.',
      DashboardSection.leads =>
        'Administra contactos capturados, formularios enviados y oportunidades comerciales.',
      DashboardSection.team =>
        'Invita colaboradores, administra roles y centraliza el trabajo de tu empresa.',
      DashboardSection.admin =>
        'Controla marca, diseño, formularios, integraciones y perfiles administrados por empresa.',
      _ => 'Esta función está disponible al actualizar tu plan.',
    };
    final icon = switch (section) {
      DashboardSection.analytics => Icons.insights_rounded,
      DashboardSection.leads => Icons.handshake_outlined,
      DashboardSection.team => Icons.groups_outlined,
      DashboardSection.admin => Icons.admin_panel_settings_outlined,
      _ => Icons.workspace_premium_outlined,
    };
    return PageShell(
      title: title,
      subtitle: 'Disponible en el plan $requiredPlan.',
      child: _PlanFeatureLockedPanel(
        title: title,
        message: message,
        requiredPlan: requiredPlan,
        icon: icon,
      ),
    );
  }
}

class _AnalyticsLockedPreviewView extends StatelessWidget {
  const _AnalyticsLockedPreviewView();

  static const _visits = [210, 335, 390, 360, 445, 468, 505];
  static const _daily = [24, 15, 31, 27, 14, 36, 22, 19, 31, 25, 18, 28];

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Analítica',
      subtitle:
          'Desbloquea estadísticas avanzadas, clics, visitas y rendimiento de tus perfiles con Premium.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1040;
          final preview = _AnalyticsPreviewMainCard(visits: _visits);
          final cta = const _AnalyticsPremiumActivationCard();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: cta),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: preview),
                  ],
                )
              else ...[
                cta,
                const SizedBox(height: 16),
                preview,
              ],
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, lowerConstraints) {
                  final columns = lowerConstraints.maxWidth >= 980 ? 3 : 1;
                  final cardWidth = columns == 1
                      ? lowerConstraints.maxWidth
                      : (lowerConstraints.maxWidth - 32) / 3;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _LockedPreviewPanel(
                          title: 'Rendimiento por día',
                          child: SizedBox(
                            height: 160,
                            child: _ViewsBarChart(values: _daily),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: const _LockedPreviewPanel(
                          title: 'Canales de origen',
                          child: _MockChannelDonut(),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: const _LockedPreviewPanel(
                          title: 'Perfiles con más interacción',
                          child: _MockTopProfilesList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsPreviewMainCard extends StatelessWidget {
  final List<int> visits;

  const _AnalyticsPreviewMainCard({required this.visits});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 18,
      child: _BlurLockedPreview(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vista previa de Analítica Premium',
                    style: GoogleFonts.outfit(
                      color: context.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _PreviewBadge(),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 4 : 2;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                const items = [
                  ('Visitas', '2,458', '+18.6%'),
                  ('Clics', '1,324', '+24.1%'),
                  ('Taps NFC', '842', '+12.7%'),
                  ('Leads', '128', '+9.3%'),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: width,
                        child: _MockAnalyticsStatCard(
                          label: item.$1,
                          value: item.$2,
                          delta: item.$3,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TaploeColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TaploeColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tendencia de visitas',
                          style: GoogleFonts.outfit(
                            color: context.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const _MockFilterPill(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(height: 180, child: _ViewsLineChart(values: visits)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Actividad reciente',
              style: GoogleFonts.outfit(
                color: context.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const _MockRecentActivityTable(),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsPremiumActivationCard extends StatelessWidget {
  const _AnalyticsPremiumActivationCard();

  @override
  Widget build(BuildContext context) {
    const benefits = [
      (Icons.query_stats_rounded, 'Mide visitas y clics en tiempo real'),
      (
        Icons.dashboard_customize_outlined,
        'Analiza el rendimiento por perfil y tarjeta',
      ),
      (Icons.show_chart_rounded, 'Visualiza tendencias y compara resultados'),
      (
        Icons.shield_outlined,
        'Consulta la actividad reciente de tus contactos',
      ),
      (
        Icons.calendar_month_outlined,
        'Filtra y exporta datos por rango de fechas',
      ),
    ];
    return TaploePanel(
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.crown,
                  color: Color(0xFFF5C84C),
                  size: 28,
                ),
                const SizedBox(width: 18),
                Text(
                  'Activa Premium',
                  style: GoogleFonts.outfit(
                    color: context.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Obtén información valiosa para tomar mejores decisiones y hacer crecer tu red de contactos.',
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 26),
            for (final benefit in benefits) ...[
              _AnalyticsPremiumBenefit(icon: benefit.$1, label: benefit.$2),
              const SizedBox(height: 18),
            ],
            const SizedBox(height: 8),
            Divider(color: TaploeColors.border),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TaploeButton(
                  width: 220,
                  label: 'Elegir plan ideal',
                  icon: Icons.workspace_premium_rounded,
                  onPressed: () => _showPlansDialog(context),
                ),
                TaploeButton(
                  width: 150,
                  label: 'Ver planes',
                  icon: Icons.arrow_forward_rounded,
                  kind: TaploeButtonKind.secondary,
                  onPressed: () => _showPlansDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: TaploeColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cancela cuando quieras. Sin compromisos.',
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadsLockedPreviewView extends StatelessWidget {
  const _LeadsLockedPreviewView();

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Leads',
      subtitle:
          'Captura, organiza y da seguimiento a tus oportunidades comerciales con Premium.',
      child: _LockedPreviewLayout(
        preview: const _LeadsPreviewCard(),
        cta: const _LockedActivationCard(
          title: 'Activa Premium',
          message:
              'Obtén el máximo valor de tus contactos. Organiza, da seguimiento y convierte más oportunidades desde un solo lugar.',
          requiredPlan: 'Premium',
          benefits: [
            (
              Icons.groups_2_outlined,
              'Administra leads y formularios en un solo lugar',
            ),
            (
              Icons.track_changes_rounded,
              'Da seguimiento al estado de cada oportunidad',
            ),
            (Icons.filter_alt_outlined, 'Filtra por fuente, fecha y estado'),
            (
              Icons.contact_page_outlined,
              'Organiza contactos capturados desde tu perfil',
            ),
            (Icons.query_stats_rounded, 'Exporta y analiza tus oportunidades'),
          ],
        ),
        lower: const [
          _LockedPreviewPanel(
            title: 'Fuentes de leads',
            child: _MockLeadSources(),
          ),
          _LockedPreviewPanel(
            title: 'Embudo de conversión',
            child: _MockLeadFunnel(),
          ),
          _LockedPreviewPanel(
            title: 'Actividad reciente',
            child: _MockLeadActivity(),
          ),
        ],
      ),
    );
  }
}

class _TeamLockedPreviewView extends StatelessWidget {
  const _TeamLockedPreviewView();

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Equipo',
      subtitle:
          'Administra colaboradores, perfiles y tarjetas de tu empresa con el plan Empresa.',
      child: _LockedPreviewLayout(
        preview: const _TeamPreviewCard(),
        cta: const _LockedActivationCard(
          title: 'Activa Empresa',
          message:
              'Centraliza a tu equipo, controla accesos y mantén todos los perfiles alineados con tu marca.',
          requiredPlan: 'Empresa',
          benefits: [
            (Icons.group_add_outlined, 'Invita miembros y asigna roles'),
            (Icons.badge_outlined, 'Administra perfiles por colaborador'),
            (Icons.credit_card_outlined, 'Reasigna tarjetas NFC y QR'),
            (Icons.timeline_rounded, 'Consulta actividad por miembro'),
            (
              Icons.admin_panel_settings_outlined,
              'Controla permisos de owners y admins',
            ),
          ],
        ),
        lower: const [
          _LockedPreviewPanel(
            title: 'Directorio del equipo',
            child: _MockTeamDirectory(),
          ),
          _LockedPreviewPanel(
            title: 'Actividad del equipo',
            child: _MockTeamActivity(),
          ),
          _LockedPreviewPanel(
            title: 'Roles y permisos',
            child: _MockTeamRoles(),
          ),
        ],
      ),
    );
  }
}

class _AdminLockedPreviewView extends StatelessWidget {
  const _AdminLockedPreviewView();

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Administración',
      subtitle:
          'Controla marca, diseño, formularios, integraciones y perfiles de empresa.',
      child: _LockedPreviewLayout(
        preview: const _AdminPreviewCard(),
        cta: const _LockedActivationCard(
          title: 'Activa Empresa',
          message:
              'Desbloquea el centro de administración para mantener una experiencia consistente en todos los perfiles.',
          requiredPlan: 'Empresa',
          benefits: [
            (
              Icons.business_center_outlined,
              'Administra datos y marca de empresa',
            ),
            (Icons.palette_outlined, 'Aplica diseño global a perfiles'),
            (Icons.dynamic_form_outlined, 'Gestiona formularios corporativos'),
            (Icons.hub_outlined, 'Configura integraciones compartidas'),
            (
              Icons.verified_user_outlined,
              'Activa o pausa perfiles del equipo',
            ),
          ],
        ),
        lower: const [
          _LockedPreviewPanel(
            title: 'Diseño corporativo',
            child: _MockAdminDesign(),
          ),
          _LockedPreviewPanel(
            title: 'Controles globales',
            child: _MockAdminControls(),
          ),
          _LockedPreviewPanel(
            title: 'Perfiles administrados',
            child: _MockAdminProfiles(),
          ),
        ],
      ),
    );
  }
}

class _LockedPreviewLayout extends StatelessWidget {
  final Widget preview;
  final Widget cta;
  final List<Widget> lower;

  const _LockedPreviewLayout({
    required this.preview,
    required this.cta,
    required this.lower,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: cta),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: preview),
                ],
              )
            else ...[
              cta,
              const SizedBox(height: 16),
              preview,
            ],
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, lowerConstraints) {
                final columns = lowerConstraints.maxWidth >= 980 ? 3 : 1;
                final width = columns == 1
                    ? lowerConstraints.maxWidth
                    : (lowerConstraints.maxWidth - 32) / 3;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final item in lower)
                      SizedBox(width: width, child: item),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _LockedActivationCard extends StatelessWidget {
  final String title;
  final String message;
  final String requiredPlan;
  final List<(IconData, String)> benefits;

  const _LockedActivationCard({
    required this.title,
    required this.message,
    required this.requiredPlan,
    required this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.crown,
                  color: Color(0xFFF5C84C),
                  size: 28,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: context.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              message,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 26),
            for (final benefit in benefits) ...[
              _AnalyticsPremiumBenefit(icon: benefit.$1, label: benefit.$2),
              const SizedBox(height: 18),
            ],
            const SizedBox(height: 8),
            Divider(color: TaploeColors.border),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TaploeButton(
                  width: 220,
                  label: 'Elegir plan ideal',
                  icon: Icons.workspace_premium_rounded,
                  onPressed: () => _showPlansDialog(context),
                ),
                TaploeButton(
                  width: 150,
                  label: 'Ver planes',
                  icon: Icons.arrow_forward_rounded,
                  kind: TaploeButtonKind.secondary,
                  onPressed: () => _showPlansDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Cancela cuando quieras. Sin compromisos.',
                style: GoogleFonts.dmSans(
                  color: context.muted,
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

class _LeadsPreviewCard extends StatelessWidget {
  const _LeadsPreviewCard();

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 18,
      child: _BlurLockedPreview(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vista previa de Leads Premium',
                    style: GoogleFonts.outfit(
                      color: context.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _PreviewBadge(),
              ],
            ),
            const SizedBox(height: 18),
            const _MockLeadStats(),
            const SizedBox(height: 14),
            const _MockLeadFilters(),
            const SizedBox(height: 14),
            const _MockLeadsTable(),
          ],
        ),
      ),
    );
  }
}

class _TeamPreviewCard extends StatelessWidget {
  const _TeamPreviewCard();

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 18,
      child: const _BlurLockedPreview(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MockPreviewHeader(title: 'Vista previa de Equipo Empresa'),
            SizedBox(height: 18),
            _MockTeamStats(),
            SizedBox(height: 14),
            _MockTeamTable(),
          ],
        ),
      ),
    );
  }
}

class _AdminPreviewCard extends StatelessWidget {
  const _AdminPreviewCard();

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 18,
      child: const _BlurLockedPreview(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MockPreviewHeader(title: 'Vista previa de Administración Empresa'),
            SizedBox(height: 18),
            _MockCompanyHeader(),
            SizedBox(height: 14),
            _MockAdminTabs(),
            SizedBox(height: 14),
            _MockAdminPolicyGrid(),
          ],
        ),
      ),
    );
  }
}

class _MockPreviewHeader extends StatelessWidget {
  final String title;

  const _MockPreviewHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const _PreviewBadge(),
      ],
    );
  }
}

class _MockLeadStats extends StatelessWidget {
  const _MockLeadStats();

  @override
  Widget build(BuildContext context) {
    const stats = [
      (Icons.link_rounded, 'Leads totales', '128', TaploeColors.black),
      (Icons.person_outline_rounded, 'Nuevos', '32', TaploeColors.success),
      (Icons.query_stats_rounded, 'Contactados', '56', TaploeColors.blue),
      (Icons.trending_up_rounded, 'Conversión', '18%', Color(0xFF7C3AED)),
    ];
    return Container(
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 720
              ? constraints.maxWidth / 4
              : constraints.maxWidth / 2;
          return Wrap(
            children: [
              for (final stat in stats)
                SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(stat.$1, color: context.muted, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.$2,
                                style: GoogleFonts.dmSans(
                                  color: context.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    stat.$3,
                                    style: GoogleFonts.outfit(
                                      color: stat.$4,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 15,
                                    color: TaploeColors.muted,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MockLeadFilters extends StatelessWidget {
  const _MockLeadFilters();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: const [
        _MockChip(
          label: 'Buscar leads por nombre, empresa o correo...',
          icon: Icons.search_rounded,
          wide: true,
        ),
        _MockChip(
          label: 'Fuente: Todas',
          icon: Icons.keyboard_arrow_down_rounded,
        ),
        _MockChip(
          label: 'Estado: Todos',
          icon: Icons.keyboard_arrow_down_rounded,
        ),
        _MockChip(
          label: 'Ordenar por: Más recientes',
          icon: Icons.sort_rounded,
        ),
      ],
    );
  }
}

class _MockChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool wide;

  const _MockChip({required this.label, required this.icon, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 330 : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, color: context.muted, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockLeadsTable extends StatelessWidget {
  const _MockLeadsTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        'AM',
        'Ana Martínez',
        'Studio Creativo',
        'ana@studiocreativo.com',
        'Nuevo',
        'Formulario web',
        '24 may 2024',
      ),
      (
        'JL',
        'Juan López',
        'Innova Tech',
        'juan.lopez@innovatech.mx',
        'Contactado',
        'Tarjeta digital',
        '23 may 2024',
      ),
      (
        'MC',
        'María Correa',
        'Consultoría MC',
        'maria.correa@cmc.com',
        'Seguimiento',
        'Enlace compartido',
        '22 may 2024',
      ),
      (
        'RP',
        'Roberto Pérez',
        'Diseño & Comunicación',
        'roberto@disenoycom.com',
        'Nuevo',
        'Instagram',
        '21 may 2024',
      ),
    ];
    return _MockTable(
      rows: [
        for (final row in rows)
          [row.$1, '${row.$2}\n${row.$3}', row.$4, row.$5, row.$6, row.$7],
      ],
    );
  }
}

class _MockTable extends StatelessWidget {
  final List<List<String>> rows;

  const _MockTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: TaploeColors.border),
                      ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: TaploeColors.blue.withValues(alpha: .12),
                    child: Text(
                      rows[i].first,
                      style: GoogleFonts.dmSans(
                        color: TaploeColors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  for (final cell in rows[i].skip(1))
                    Expanded(
                      child: Text(
                        cell,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: context.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: TaploeColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MockLeadSources extends StatelessWidget {
  const _MockLeadSources();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 170, child: _MockChannelDonut());
  }
}

class _MockLeadFunnel extends StatelessWidget {
  const _MockLeadFunnel();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Nuevos', 128, 1.0),
      ('Contactados', 56, .44),
      ('Calificados', 23, .18),
      ('Convertidos', 10, .08),
    ];
    return SizedBox(
      height: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final row in rows)
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(row.$1, style: _mockMuted(context)),
                ),
                Expanded(child: _ProgressBar(value: row.$3)),
                const SizedBox(width: 10),
                Text('${row.$2}', style: _mockMuted(context)),
              ],
            ),
        ],
      ),
    );
  }
}

class _MockLeadActivity extends StatelessWidget {
  const _MockLeadActivity();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Nuevo lead desde formulario', 'Hace 10 min'),
      ('Lead contactado por email', 'Hace 1 h'),
      ('Tarjeta digital compartida', 'Hace 3 h'),
      ('Nuevo lead desde enlace', 'Ayer'),
    ];
    return SizedBox(
      height: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final row in rows)
            Row(
              children: [
                const Icon(
                  Icons.person_add_alt_rounded,
                  color: TaploeColors.blue,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(row.$1, style: _mockMuted(context))),
                Text(row.$2, style: _mockMuted(context)),
              ],
            ),
        ],
      ),
    );
  }
}

class _MockTeamStats extends StatelessWidget {
  const _MockTeamStats();

  @override
  Widget build(BuildContext context) {
    return const _SimpleStatGrid(
      items: [
        ('Miembros', '24', Icons.groups_outlined),
        ('Perfiles', '38', Icons.badge_outlined),
        ('Tarjetas', '31', Icons.credit_card_outlined),
        ('Leads equipo', '412', Icons.handshake_outlined),
      ],
    );
  }
}

class _MockTeamTable extends StatelessWidget {
  const _MockTeamTable();

  @override
  Widget build(BuildContext context) {
    return const _MockTable(
      rows: [
        [
          'DV',
          'Daniel Ventas\nOwner',
          '6 perfiles',
          '1,245 vistas',
          '128 leads',
        ],
        ['AM', 'Ana Marketing\nAdmin', '4 perfiles', '982 vistas', '86 leads'],
        [
          'JL',
          'Juan Operaciones\nMiembro',
          '2 perfiles',
          '654 vistas',
          '42 leads',
        ],
        [
          'MC',
          'María Comercial\nMiembro',
          '3 perfiles',
          '521 vistas',
          '37 leads',
        ],
      ],
    );
  }
}

class _MockTeamDirectory extends StatelessWidget {
  const _MockTeamDirectory();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('DV', 'Daniel Ventas', 'Owner', '6 perfiles'),
      ('AM', 'Ana Marketing', 'Admin', '4 perfiles'),
      ('JL', 'Juan Operaciones', 'Miembro', '2 perfiles'),
      ('MC', 'María Comercial', 'Miembro', '3 perfiles'),
    ];
    return SizedBox(
      height: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final row in rows)
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: TaploeColors.blue.withValues(alpha: .12),
                  child: Text(
                    row.$1,
                    style: GoogleFonts.dmSans(
                      color: TaploeColors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: context.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        row.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _mockMuted(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: Text(
                    row.$4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: _mockMuted(context),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.lock_outline_rounded,
                  color: TaploeColors.muted,
                  size: 16,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MockTeamActivity extends StatelessWidget {
  const _MockTeamActivity();

  @override
  Widget build(BuildContext context) => const _MockLeadActivity();
}

class _MockTeamRoles extends StatelessWidget {
  const _MockTeamRoles();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MockRoleRow(label: 'Owner', value: 'Control total'),
          _MockRoleRow(label: 'Admin', value: 'Equipo y perfiles'),
          _MockRoleRow(label: 'Miembro', value: 'Perfil personal'),
          _MockRoleRow(label: 'Viewer', value: 'Solo lectura'),
        ],
      ),
    );
  }
}

class _MockRoleRow extends StatelessWidget {
  final String label;
  final String value;

  const _MockRoleRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: _mockMuted(context))),
        _PreviewBadge(),
        const SizedBox(width: 8),
        Text(value, style: _mockMuted(context)),
      ],
    );
  }
}

class _MockCompanyHeader extends StatelessWidget {
  const _MockCompanyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 28, child: Icon(Icons.business_rounded)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Taploe Enterprise',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                const _PreviewBadge(),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, color: TaploeColors.muted),
        ],
      ),
    );
  }
}

class _MockAdminTabs extends StatelessWidget {
  const _MockAdminTabs();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MockChip(label: 'Diseño global', icon: Icons.palette_outlined),
        _MockChip(label: 'Formularios', icon: Icons.dynamic_form_outlined),
        _MockChip(label: 'Integraciones', icon: Icons.hub_outlined),
        _MockChip(label: 'Perfiles', icon: Icons.badge_outlined),
      ],
    );
  }
}

class _MockAdminPolicyGrid extends StatelessWidget {
  const _MockAdminPolicyGrid();

  @override
  Widget build(BuildContext context) {
    return const _SimpleStatGrid(
      items: [
        ('Diseño', 'Activo', Icons.check_circle_outline),
        ('Forms', '3', Icons.dynamic_form_outlined),
        ('Integraciones', '5', Icons.hub_outlined),
        ('Perfiles', '38', Icons.badge_outlined),
      ],
    );
  }
}

class _MockAdminDesign extends StatelessWidget {
  const _MockAdminDesign();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 170, child: _MockAdminPolicyGrid());
}

class _MockAdminControls extends StatelessWidget {
  const _MockAdminControls();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MockRoleRow(label: 'Forzar diseño', value: 'Activo'),
          _MockRoleRow(label: 'Forzar formularios', value: 'Activo'),
          _MockRoleRow(label: 'Forzar integraciones', value: 'Inactivo'),
        ],
      ),
    );
  }
}

class _MockAdminProfiles extends StatelessWidget {
  const _MockAdminProfiles();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('DV', 'Daniel Ventas', '6 perfiles', '1,245 vistas', '128 leads'),
      ('AM', 'Ana Marketing', '4 perfiles', '982 vistas', '86 leads'),
      ('JL', 'Juan Operaciones', '2 perfiles', '654 vistas', '42 leads'),
    ];
    return SizedBox(
      height: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [for (final row in rows) _MockAdminProfileRow(row: row)],
      ),
    );
  }
}

class _MockAdminProfileRow extends StatelessWidget {
  final (String, String, String, String, String) row;

  const _MockAdminProfileRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: TaploeColors.blue.withValues(alpha: .12),
          child: Text(
            row.$1,
            style: GoogleFonts.dmSans(
              color: TaploeColors.blue,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Text(
            row.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: context.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            row.$3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mockMuted(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            row.$4,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mockMuted(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            row.$5,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mockMuted(context),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.lock_outline_rounded,
          color: TaploeColors.muted,
          size: 16,
        ),
      ],
    );
  }
}

class _SimpleStatGrid extends StatelessWidget {
  final List<(String, String, IconData)> items;

  const _SimpleStatGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? constraints.maxWidth / 4
            : constraints.maxWidth / 2;
        return Wrap(
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: TaploeColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$3, color: TaploeColors.blue),
                      const SizedBox(height: 10),
                      Text(item.$1, style: _mockMuted(context)),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: GoogleFonts.outfit(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

TextStyle _mockMuted(BuildContext context) => GoogleFonts.dmSans(
  color: context.muted,
  fontSize: 12,
  fontWeight: FontWeight.w700,
);

class _AnalyticsPremiumBenefit extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AnalyticsPremiumBenefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.text, size: 22),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: context.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedPreviewPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _LockedPreviewPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 18,
      child: _BlurLockedPreview(
        compact: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: context.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _PreviewBadge(),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _BlurLockedPreview extends StatelessWidget {
  final Widget child;
  final bool compact;

  const _BlurLockedPreview({required this.child, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: compact ? 2.0 : 1.6,
              sigmaY: compact ? 2.0 : 1.6,
            ),
            child: Opacity(opacity: compact ? .55 : .68, child: child),
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: TaploeColors.white.withValues(alpha: compact ? .40 : .28),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        Container(
          width: compact ? 38 : 46,
          height: compact ? 38 : 46,
          decoration: BoxDecoration(
            color: TaploeColors.white.withValues(alpha: .86),
            shape: BoxShape.circle,
            border: Border.all(color: TaploeColors.borderStrong),
            boxShadow: [
              BoxShadow(
                color: TaploeColors.black.withValues(alpha: .08),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: TaploeColors.muted,
          ),
        ),
      ],
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: TaploeColors.blue.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 13,
            color: TaploeColors.blue,
          ),
          const SizedBox(width: 5),
          Text(
            'Vista previa',
            style: GoogleFonts.dmSans(
              color: TaploeColors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockAnalyticsStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;

  const _MockAnalyticsStatCard({
    required this.label,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: TaploeColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: context.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  delta,
                  style: GoogleFonts.dmSans(
                    color: TaploeColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockFilterPill extends StatelessWidget {
  const _MockFilterPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Últimos 7 días',
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: TaploeColors.muted,
          ),
        ],
      ),
    );
  }
}

class _MockRecentActivityTable extends StatelessWidget {
  const _MockRecentActivityTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Visita', 'Perfil digital', 'Ciudad de México, MX', '18 May, 10:24'),
      ('Clic en botón', 'WhatsApp', 'Monterrey, MX', '18 May, 09:41'),
      ('Tap NFC', 'Tarjeta Principal', 'Guadalajara, MX', '18 May, 09:15'),
      ('Clic en botón', 'Sitio web', 'Puebla, MX', '18 May, 08:32'),
      ('Visita', 'Perfil digital', 'Ciudad de México, MX', '17 May, 22:08'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: TaploeColors.border),
                      ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    color: TaploeColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(rows[i].$1, style: _mockRowStyle(context)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(rows[i].$2, style: _mockRowStyle(context)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(rows[i].$3, style: _mockRowStyle(context)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(rows[i].$4, style: _mockRowStyle(context)),
                  ),
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: TaploeColors.muted,
                    size: 17,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _mockRowStyle(BuildContext context) => GoogleFonts.dmSans(
    color: context.muted,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

class _MockChannelDonut extends StatelessWidget {
  const _MockChannelDonut();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _MockDonutPainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _MockChannelRow(label: 'WhatsApp', value: '30%'),
                _MockChannelRow(label: 'NFC', value: '30%'),
                _MockChannelRow(label: 'Instagram', value: '20%'),
                _MockChannelRow(label: 'Código QR', value: '12%'),
                _MockChannelRow(label: 'Otros', value: '8%'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockChannelRow extends StatelessWidget {
  final String label;
  final String value;

  const _MockChannelRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: TaploeColors.blue.withValues(alpha: .35),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockDonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2 - 14;
    final stroke = radius * .34;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;
    final colors = [
      TaploeColors.blue.withValues(alpha: .32),
      TaploeColors.blue.withValues(alpha: .22),
      TaploeColors.blue.withValues(alpha: .15),
      TaploeColors.blue.withValues(alpha: .10),
    ];
    final sweeps = [.34, .26, .22, .18];
    for (var i = 0; i < sweeps.length; i++) {
      paint.color = colors[i];
      final sweep = math.pi * 2 * sweeps[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MockTopProfilesList extends StatelessWidget {
  const _MockTopProfilesList();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Perfil ejecutivo', 1245, .92),
      ('Tarjeta personal', 987, .78),
      ('Evento Expo 2024', 654, .58),
      ('Tarjeta Ventas', 321, .34),
    ];
    return SizedBox(
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final row in rows)
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: TaploeColors.border,
                  child: Text(
                    row.$1.characters.first,
                    style: GoogleFonts.dmSans(
                      color: TaploeColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 94, child: _ProgressBar(value: row.$3)),
                const SizedBox(width: 10),
                Text(
                  '${row.$2}',
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _EntryDialogPlan { individual, team }

enum _EntryBillingCycle { annual, monthly }

class _DashboardEntryDialog extends StatefulWidget {
  final bool initialShowPlanComparison;

  const _DashboardEntryDialog({this.initialShowPlanComparison = true});

  @override
  State<_DashboardEntryDialog> createState() => _DashboardEntryDialogState();
}

class _DashboardEntryDialogState extends State<_DashboardEntryDialog> {
  _EntryDialogPlan? plan;
  _EntryDialogPlan? comparisonCheckoutPlan;
  _EntryBillingCycle billingCycle = _EntryBillingCycle.annual;
  int businessQuantity = TaploePricing.businessMinProfiles;
  late bool showPlanComparison;
  bool checkout = false;

  @override
  void initState() {
    super.initState();
    showPlanComparison = widget.initialShowPlanComparison;
  }

  void _selectPlan(_EntryDialogPlan value) {
    setState(() {
      plan = value;
      billingCycle = _EntryBillingCycle.annual;
      if (value == _EntryDialogPlan.team) {
        businessQuantity = TaploePricing.businessMinProfiles;
      }
      checkout = false;
    });
  }

  void _startTrial() {
    setState(() {
      checkout = true;
    });
  }

  void _goBack() {
    if (showPlanComparison) {
      Navigator.of(context).pop();
      return;
    }
    if (checkout) {
      setState(() {
        checkout = false;
      });
      return;
    }
    if (plan == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      plan = null;
      billingCycle = _EntryBillingCycle.annual;
      checkout = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    if (showPlanComparison) {
      final checkoutPlan = comparisonCheckoutPlan;
      if (checkoutPlan != null) {
        return Dialog.fullscreen(
          backgroundColor: TaploeColors.white,
          child: _EntryPlanCheckoutView(
            mobile: mobile,
            plan: checkoutPlan,
            billingCycle: billingCycle,
            businessQuantity: businessQuantity,
            onBillingCycleChanged: (value) {
              setState(() => billingCycle = value);
            },
            onBusinessQuantityChanged: (value) {
              setState(() => businessQuantity = value);
            },
            onBack: () => setState(() => comparisonCheckoutPlan = null),
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      }

      return Dialog.fullscreen(
        backgroundColor: TaploeColors.white,
        child: _EntryPlanComparisonView(
          mobile: mobile,
          onSkip: () => setState(() => showPlanComparison = false),
          onFree: () => Navigator.of(context).pop(),
          onPremium: () {
            setState(() {
              comparisonCheckoutPlan = _EntryDialogPlan.individual;
              billingCycle = _EntryBillingCycle.annual;
            });
          },
          onTeam: () {
            setState(() {
              comparisonCheckoutPlan = _EntryDialogPlan.team;
              billingCycle = _EntryBillingCycle.annual;
              businessQuantity = TaploePricing.businessMinProfiles;
            });
          },
          onProposal: () {
            showDialog<void>(
              context: context,
              builder: (context) => const _TeamPlanRequestDialog(),
            );
          },
        ),
      );
    }

    final content = plan == null
        ? _EntryDialogChoiceContent(
            mobile: mobile,
            onBack: _goBack,
            onIndividual: () => _selectPlan(_EntryDialogPlan.individual),
            onTeam: () => _selectPlan(_EntryDialogPlan.team),
            onEnterprise: () {
              showDialog<void>(
                context: context,
                builder: (context) => const _TeamPlanRequestDialog(),
              );
            },
            onUnsure: () => Navigator.of(context).pop(),
          )
        : checkout
        ? _EntryDialogCheckoutContent(
            mobile: mobile,
            plan: plan!,
            billingCycle: billingCycle,
            businessQuantity: businessQuantity,
            onBillingCycleChanged: (value) {
              setState(() {
                billingCycle = value;
              });
            },
            onBusinessQuantityChanged: (value) {
              setState(() => businessQuantity = value);
            },
            onBack: _goBack,
          )
        : _EntryDialogPlanContent(
            mobile: mobile,
            plan: plan!,
            onBack: _goBack,
            onStartTrial: _startTrial,
          );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 18 : 42,
        vertical: mobile ? 18 : 36,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: TaploeColors.white,
            child: checkout
                ? Stack(
                    children: [
                      mobile
                          ? SingleChildScrollView(
                              child: Column(
                                children: [
                                  content,
                                  _EntryCheckoutPreviewPane(
                                    plan: plan!,
                                    mobile: true,
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(flex: 6, child: content),
                                Expanded(
                                  flex: 5,
                                  child: _EntryCheckoutPreviewPane(plan: plan!),
                                ),
                              ],
                            ),
                      Positioned(
                        top: 18,
                        right: mobile ? 18 : 28,
                        child: IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: TaploeColors.blue,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  )
                : mobile
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [_EntryDialogVisual(mobile: true), content],
                    ),
                  )
                : Row(
                    children: [
                      Expanded(flex: 6, child: content),
                      const Expanded(flex: 5, child: _EntryDialogVisual()),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _EntryPlanComparisonView extends StatelessWidget {
  final bool mobile;
  final VoidCallback onSkip;
  final VoidCallback onFree;
  final VoidCallback onPremium;
  final VoidCallback onTeam;
  final VoidCallback onProposal;

  const _EntryPlanComparisonView({
    required this.mobile,
    required this.onSkip,
    required this.onFree,
    required this.onPremium,
    required this.onTeam,
    required this.onProposal,
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = mobile ? 20.0 : 52.0;
    final locale = taploeState.localeConfig;
    final t = taploeState.t;
    final premiumAnnualMonthly = TaploePricing.monthlyEquivalent(
      plan: TaploeCatalogPlan.premium,
      period: TaploeCatalogPeriod.annual,
      locale: locale,
    );
    final premiumMonthly = TaploePricing.unitPrice(
      plan: TaploeCatalogPlan.premium,
      period: TaploeCatalogPeriod.monthly,
      locale: locale,
    );
    final businessAnnualMonthly = TaploePricing.monthlyEquivalent(
      plan: TaploeCatalogPlan.business,
      period: TaploeCatalogPeriod.annual,
      locale: locale,
    );
    final businessMonthly = TaploePricing.unitPrice(
      plan: TaploeCatalogPlan.business,
      period: TaploeCatalogPeriod.monthly,
      locale: locale,
    );
    final cards = [
      _PlanComparisonCard(
        title: 'Taploe Premium',
        subtitle: 'Más personalización y herramientas para vender mejor.',
        price: premiumAnnualMonthly.format(),
        cadence: ' ${t.perMonth}',
        note: t.text(
          'Mejor precio anual · mensual ${premiumMonthly.format()}',
          'Best annual price · monthly ${premiumMonthly.format()}',
        ),
        badge: 'Recomendado',
        highlighted: true,
        buttonLabel: 'Probar 7 días gratis',
        onPressed: onPremium,
        features: const [
          (Icons.visibility_off_rounded, 'Perfil profesional sin marca Taploe'),
          (Icons.insights_rounded, 'Visitas y enlaces con más interés'),
          (Icons.palette_rounded, 'Identidad digital personalizada'),
          (Icons.badge_rounded, 'Hasta 5 perfiles digitales'),
        ],
      ),
      _PlanComparisonCard(
        title: 'Empresas',
        subtitle: 'Control, consistencia y medición para equipos.',
        price: businessAnnualMonthly.format(),
        cadence: ' ${t.perProfilePerMonth}',
        note: t.text(
          'Por perfil, facturado anual · mensual ${businessMonthly.format()}',
          'Per profile, billed annually · monthly ${businessMonthly.format()}',
        ),
        buttonLabel: 'Probar 7 días gratis',
        onPressed: onTeam,
        features: const [
          (Icons.groups_rounded, 'Administra tu equipo en un solo lugar'),
          (Icons.palette_rounded, 'Imagen consistente para la empresa'),
          (Icons.sync_rounded, 'Actualiza colaboradores en minutos'),
          (Icons.credit_card_rounded, 'Reasigna tarjetas al cambiar personal'),
          (Icons.query_stats_rounded, 'Rendimiento por colaborador'),
          (Icons.handshake_rounded, 'Leads del equipo centralizados'),
        ],
      ),
      _PlanComparisonCard(
        title: 'Agency or Enterprise',
        subtitle:
            'Get team seats, SSO, dedicated support, and custom contracts.',
        price: 'A medida',
        cadence: '',
        note: 'Solución personalizada para equipos grandes.',
        buttonLabel: 'Solicitar propuesta',
        buttonIcon: Icons.description_outlined,
        onPressed: onProposal,
        features: const [
          (Icons.groups_2_rounded, 'Asientos para equipos'),
          (Icons.security_rounded, 'SSO y seguridad avanzada'),
          (Icons.support_agent_rounded, 'Soporte dedicado'),
          (Icons.article_rounded, 'Contratos personalizados'),
        ],
      ),
    ];
    final freeCard = _FreePlanWideCard(onPressed: onFree);

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: mobile ? 14 : 26,
            left: horizontal,
            child: const TaploeLogo(size: 38),
          ),
          Positioned(
            top: mobile ? 12 : 24,
            right: horizontal,
            child: TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: TaploeColors.blue,
                textStyle: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Omitir'),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                mobile ? 84 : 96,
                horizontal,
                mobile ? 28 : 40,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Elige el plan ideal para ti',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: context.text,
                        fontSize: mobile ? 36 : 52,
                        fontWeight: FontWeight.w700,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Puedes empezar gratis y cambiar de plan cuando lo necesites.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: context.muted,
                        fontSize: mobile ? 16 : 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: mobile ? 30 : 44),
                    mobile
                        ? Column(
                            children: [
                              for (final card in cards) ...[
                                card,
                                const SizedBox(height: 16),
                              ],
                              freeCard,
                            ],
                          )
                        : Column(
                            children: [
                              SizedBox(
                                height: 496,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < cards.length; i++) ...[
                                      Expanded(child: cards[i]),
                                      if (i != cards.length - 1)
                                        const SizedBox(width: 22),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              freeCard,
                            ],
                          ),
                    SizedBox(height: mobile ? 12 : 24),
                    const _PlanTrustBar(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTrustBar extends StatelessWidget {
  const _PlanTrustBar();

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.check_circle_outline_rounded, 'Cambia o cancela cuando quieras'),
      (Icons.check_circle_outline_rounded, 'Cancela cuando quieras'),
      (Icons.support_agent_rounded, 'Soporte prioritario'),
      (Icons.receipt_long_rounded, 'Facturación transparente'),
    ];

    return Wrap(
      spacing: 52,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: TaploeColors.blue,
                size: 22,
              ),
              const SizedBox(width: 9),
              Text(
                item.$2,
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EntryPlanCheckoutView extends StatelessWidget {
  final bool mobile;
  final _EntryDialogPlan plan;
  final _EntryBillingCycle billingCycle;
  final int businessQuantity;
  final ValueChanged<_EntryBillingCycle> onBillingCycleChanged;
  final ValueChanged<int> onBusinessQuantityChanged;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _EntryPlanCheckoutView({
    required this.mobile,
    required this.plan,
    required this.billingCycle,
    required this.businessQuantity,
    required this.onBillingCycleChanged,
    required this.onBusinessQuantityChanged,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final content = _EntryDialogCheckoutContent(
      mobile: mobile,
      plan: plan,
      billingCycle: billingCycle,
      businessQuantity: businessQuantity,
      onBillingCycleChanged: onBillingCycleChanged,
      onBusinessQuantityChanged: onBusinessQuantityChanged,
      onBack: onBack,
    );

    return SafeArea(
      child: Stack(
        children: [
          mobile
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      content,
                      _EntryCheckoutPreviewPane(plan: plan, mobile: true),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Expanded(flex: 6, child: content),
                    Expanded(
                      flex: 5,
                      child: _EntryCheckoutPreviewPane(plan: plan),
                    ),
                  ],
                ),
          Positioned(
            top: 18,
            right: mobile ? 18 : 28,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                color: TaploeColors.blue,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanComparisonCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String cadence;
  final String? badge;
  final String? note;
  final bool highlighted;
  final String buttonLabel;
  final IconData? buttonIcon;
  final VoidCallback onPressed;
  final List<(IconData, String)> features;

  const _PlanComparisonCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.cadence,
    required this.buttonLabel,
    required this.onPressed,
    required this.features,
    this.buttonIcon,
    this.badge,
    this.note,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlighted ? TaploeColors.blue : TaploeColors.border;

    return Container(
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: highlighted ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: highlighted ? TaploeColors.blue : context.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.02,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: TaploeColors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: TaploeColors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          badge!.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            color: TaploeColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
            const SizedBox(height: 34),
            RichText(
              text: TextSpan(
                style: GoogleFonts.outfit(color: context.text),
                children: [
                  TextSpan(
                    text: price,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  TextSpan(
                    text: cadence,
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 7),
              Text(
                note!,
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 18),
            TaploeButton(
              label: buttonLabel,
              icon:
                  buttonIcon ??
                  (highlighted
                      ? Icons.arrow_forward_rounded
                      : Icons.check_rounded),
              kind: highlighted
                  ? TaploeButtonKind.primary
                  : TaploeButtonKind.secondary,
              expanded: true,
              onPressed: onPressed,
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            for (final feature in features) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: TaploeColors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(feature.$1, color: TaploeColors.blue, size: 15),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      feature.$2,
                      style: GoogleFonts.dmSans(
                        color: context.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _FreePlanWideCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _FreePlanWideCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final features = const [
      '1 perfil digital',
      'Enlaces básicos',
      'QR público incluido',
      'Compartir perfil',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 22 : 28),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TaploeColors.border),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FreePlanHeader(onPressed: onPressed, mobile: true),
                const SizedBox(height: 18),
                _FreePlanFeatures(features: features),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gratis',
                        style: GoogleFonts.outfit(
                          color: context.text,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FreePlanFeatures(features: features),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                TaploeButton(
                  label: 'Continuar gratis',
                  icon: Icons.check_rounded,
                  kind: TaploeButtonKind.secondary,
                  width: 220,
                  onPressed: onPressed,
                ),
              ],
            ),
    );
  }
}

class _FreePlanHeader extends StatelessWidget {
  final VoidCallback onPressed;
  final bool mobile;

  const _FreePlanHeader({required this.onPressed, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gratis',
          style: GoogleFonts.outfit(
            color: context.text,
            fontSize: mobile ? 30 : 34,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 16),
        TaploeButton(
          label: 'Continuar gratis',
          icon: Icons.check_rounded,
          kind: TaploeButtonKind.secondary,
          expanded: true,
          onPressed: onPressed,
        ),
      ],
    );
  }
}

class _FreePlanFeatures extends StatelessWidget {
  final List<String> features;

  const _FreePlanFeatures({required this.features});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 22,
      runSpacing: 12,
      children: [
        for (final feature in features)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9ECEF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF363A43),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                feature,
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EntryDialogChoiceContent extends StatelessWidget {
  final bool mobile;
  final VoidCallback onBack;
  final VoidCallback onIndividual;
  final VoidCallback onTeam;
  final VoidCallback onEnterprise;
  final VoidCallback onUnsure;

  const _EntryDialogChoiceContent({
    required this.mobile,
    required this.onBack,
    required this.onIndividual,
    required this.onTeam,
    required this.onEnterprise,
    required this.onUnsure,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 24 : 44,
        mobile ? 24 : 34,
        mobile ? 24 : 44,
        mobile ? 28 : 34,
      ),
      child: Column(
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mobile) const Spacer(),
          const TaploeLogo(size: 42),
          SizedBox(height: mobile ? 28 : 34),
          Text(
            '¿Qué define mejor cómo usarás Taploe?',
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: mobile ? 31 : 34,
              fontWeight: FontWeight.w600,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Te mostraremos la opción más útil para empezar.',
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: mobile ? 16 : 17,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          SizedBox(height: mobile ? 28 : 38),
          _EntryChoiceButton(
            icon: Icons.person_rounded,
            label: 'Usar Taploe para mí',
            onPressed: onIndividual,
          ),
          const SizedBox(height: 12),
          _EntryChoiceButton(
            icon: Icons.groups_rounded,
            label: 'Utilizar Taploe para mi equipo',
            onPressed: onTeam,
          ),
          const SizedBox(height: 12),
          _EntryChoiceButton(
            icon: Icons.business_center_rounded,
            label: 'Enterprise',
            dark: true,
            onPressed: onEnterprise,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: onUnsure,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Aún no estoy seguro'),
              style: TextButton.styleFrom(
                foregroundColor: context.text,
                textStyle: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!mobile) const Spacer(),
        ],
      ),
    );
  }
}

class _EntryDialogPlanContent extends StatelessWidget {
  final bool mobile;
  final _EntryDialogPlan plan;
  final VoidCallback onBack;
  final VoidCallback onStartTrial;

  const _EntryDialogPlanContent({
    required this.mobile,
    required this.plan,
    required this.onBack,
    required this.onStartTrial,
  });

  @override
  Widget build(BuildContext context) {
    final isTeam = plan == _EntryDialogPlan.team;
    final features = isTeam
        ? const [
            (Icons.groups_rounded, 'Administra tu equipo en un solo lugar.'),
            (Icons.palette_rounded, 'Imagen consistente en toda la empresa.'),
            (Icons.sync_rounded, 'Actualiza colaboradores en minutos.'),
            (
              Icons.credit_card_rounded,
              'Reasigna tarjetas cuando alguien cambia.',
            ),
            (Icons.query_stats_rounded, 'Mide el rendimiento por colaborador.'),
            (Icons.handshake_rounded, 'Centraliza todos los leads del equipo.'),
            (Icons.apartment_rounded, 'Refuerza tu marca en cada interacción.'),
            (
              Icons.savings_rounded,
              'Evita reimprimir tarjetas por cada cambio.',
            ),
            (
              Icons.admin_panel_settings_rounded,
              'Control de perfiles y permisos.',
            ),
          ]
        : const [
            (
              Icons.visibility_off_rounded,
              'Perfil profesional sin marca Taploe.',
            ),
            (
              Icons.insights_rounded,
              'Conoce visitas y enlaces con más interés.',
            ),
            (Icons.palette_rounded, 'Personaliza tu identidad digital.'),
            (
              Icons.sync_rounded,
              'Actualiza tu información sin reimprimir tarjetas.',
            ),
            (Icons.badge_rounded, 'Hasta 5 perfiles digitales.'),
            (
              Icons.event_available_rounded,
              'Permite que agenden reuniones contigo.',
            ),
            (
              Icons.business_center_rounded,
              'Imagen más profesional al hacer networking.',
            ),
            (
              Icons.rocket_launch_rounded,
              'Herramientas para generar oportunidades.',
            ),
          ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 24 : 44,
        mobile ? 24 : 34,
        mobile ? 24 : 44,
        mobile ? 28 : 34,
      ),
      child: Column(
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mobile)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Volver',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 28),
              ),
            ),
          SizedBox(height: mobile ? 18 : 28),
          Text(
            isTeam ? 'Taploe para empresas' : 'Taploe Premium',
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: mobile ? 35 : 42,
              fontWeight: FontWeight.w600,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isTeam
                ? 'Herramientas para equipos que necesitan orden, marca y control.'
                : 'Más personalización para que tu perfil se vea profesional y listo para compartir.',
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: mobile ? 15 : 17,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          SizedBox(height: mobile ? 18 : 22),
          Column(
            children: features
                .map(
                  (feature) => Padding(
                    padding: EdgeInsets.only(bottom: mobile ? 9 : 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            feature.$1,
                            color: TaploeColors.blue,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            feature.$2,
                            style: GoogleFonts.dmSans(
                              color: context.text,
                              fontSize: mobile ? 14 : 14.8,
                              fontWeight: FontWeight.w700,
                              height: 1.18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          if (!mobile) const Spacer(),
          SizedBox(height: mobile ? 8 : 14),
          TaploeButton(
            label: 'Iniciar prueba gratis de 7 días',
            icon: Icons.arrow_forward_rounded,
            expanded: true,
            onPressed: onStartTrial,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Sin compromiso, cancela cuando quieras.',
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryDialogCheckoutContent extends StatefulWidget {
  final bool mobile;
  final _EntryDialogPlan plan;
  final _EntryBillingCycle billingCycle;
  final int businessQuantity;
  final ValueChanged<_EntryBillingCycle> onBillingCycleChanged;
  final ValueChanged<int> onBusinessQuantityChanged;
  final VoidCallback onBack;

  const _EntryDialogCheckoutContent({
    required this.mobile,
    required this.plan,
    required this.billingCycle,
    required this.businessQuantity,
    required this.onBillingCycleChanged,
    required this.onBusinessQuantityChanged,
    required this.onBack,
  });

  @override
  State<_EntryDialogCheckoutContent> createState() =>
      _EntryDialogCheckoutContentState();
}

class _EntryDialogCheckoutContentState
    extends State<_EntryDialogCheckoutContent> {
  bool loadingCheckout = false;

  Future<void> _completePurchase() async {
    if (loadingCheckout) return;
    setState(() => loadingCheckout = true);
    try {
      final isTeam = widget.plan == _EntryDialogPlan.team;
      final checkoutUrl = await BillingRepository.createCheckoutSession(
        plan: isTeam ? 'business' : 'premium',
        billingPeriod: widget.billingCycle == _EntryBillingCycle.annual
            ? 'annual'
            : 'monthly',
        quantity: isTeam ? widget.businessQuantity : 1,
        language: taploeState.localeConfig.languageCode,
        market: taploeState.localeConfig.marketCode,
        locale: taploeState.localeConfig.localeCode,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await _openStripeUrl(context, checkoutUrl);
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          safeCheckoutErrorMessage(
            error,
            fallback: taploeState.t.text(
              'No pudimos iniciar Checkout. Intenta de nuevo.',
              'We could not start Checkout. Try again.',
            ),
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => loadingCheckout = false);
    }
  }

  String _checkoutOptionPrice({
    required TaploeCatalogPlan plan,
    required TaploeCatalogPeriod period,
    required int quantity,
  }) {
    final locale = taploeState.localeConfig;
    final t = taploeState.t;
    final unit = TaploePricing.unitPrice(
      plan: plan,
      period: period,
      locale: locale,
    );
    if (plan == TaploeCatalogPlan.business) {
      if (period == TaploeCatalogPeriod.annual) {
        return t.text(
          '${unit.format()} por perfil al año',
          '${unit.format()} per profile per year',
        );
      }
      return t.text(
        '${unit.format()} por perfil al mes',
        '${unit.format()} per profile per month',
      );
    }
    if (period == TaploeCatalogPeriod.annual) {
      return t.text('${unit.format()} al año', '${unit.format()} per year');
    }
    return t.text('${unit.format()} al mes', '${unit.format()} per month');
  }

  @override
  Widget build(BuildContext context) {
    final isTeam = widget.plan == _EntryDialogPlan.team;
    const trialDays = 7;
    final t = taploeState.t;
    final locale = taploeState.localeConfig;
    final catalogPlan = isTeam
        ? TaploeCatalogPlan.business
        : TaploeCatalogPlan.premium;
    final annualSelected = widget.billingCycle == _EntryBillingCycle.annual;
    final selectedPeriod = annualSelected
        ? TaploeCatalogPeriod.annual
        : TaploeCatalogPeriod.monthly;
    final quantity = isTeam ? widget.businessQuantity : 1;
    final title = isTeam
        ? t.text('Prueba Taploe Empresas gratis', 'Try Taploe Business free')
        : t.text('Prueba Taploe Premium gratis', 'Try Taploe Premium free');
    final dueDate = _dateLabel(
      DateTime.now().add(const Duration(days: trialDays)),
    );
    final amount = TaploePricing.total(
      plan: catalogPlan,
      period: selectedPeriod,
      locale: locale,
      quantity: quantity,
    ).format();
    final annualPrice = _checkoutOptionPrice(
      plan: catalogPlan,
      period: TaploeCatalogPeriod.annual,
      quantity: quantity,
    );
    final monthlyPrice = _checkoutOptionPrice(
      plan: catalogPlan,
      period: TaploeCatalogPeriod.monthly,
      quantity: quantity,
    );
    final badge = t.text(
      'MEJOR VALOR - AHORRA ${TaploePricing.annualSavingsPercent(catalogPlan)}%',
      'BEST VALUE - SAVE ${TaploePricing.annualSavingsPercent(catalogPlan)}%',
    );
    final zeroAmount = TaploePrice(
      amount: 0,
      currency: locale.currencyCode,
    ).format();
    final selectedPeriodText = annualSelected
        ? t.text('año', 'year')
        : t.text('mes', 'month');
    final amountAfterTrial = '$amount / $selectedPeriodText';

    final horizontalPadding = widget.mobile ? 22.0 : 40.0;
    final topPadding = widget.mobile ? 22.0 : 34.0;
    final bodyBottomPadding = widget.mobile ? 18.0 : 22.0;
    final footerBottomPadding = widget.mobile ? 18.0 : 22.0;
    final checkoutFooter = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TaploeColors.white,
        border: const Border(top: BorderSide(color: TaploeColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        footerBottomPadding,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CheckoutPrimaryButton(
              label: t.text('Comenzar prueba gratis', 'Start free trial'),
              loading: loadingCheckout,
              onPressed: _completePurchase,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: TaploeColors.muted,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    t.text(
                      'Se te recordará antes de que termine tu prueba.',
                      'We will remind you before your trial ends.',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final checkoutBody = Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bodyBottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            label: Text(t.text('Volver', 'Back')),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: context.text,
              textStyle: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: widget.mobile ? 14 : 22),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: widget.mobile ? 34 : 42,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrialCheckLine(
                t.text(
                  'Prueba gratis de $trialDays días, cancela cuando quieras.',
                  '$trialDays-day free trial, cancel anytime.',
                ),
                compact: true,
              ),
              const SizedBox(height: 12),
              _TrialCheckLine(
                t.text(
                  'Te recordaremos antes de que termine tu prueba.',
                  'We will remind you before your trial ends.',
                ),
                compact: true,
              ),
            ],
          ),
          SizedBox(height: widget.mobile ? 26 : 30),
          if (isTeam) ...[
            _BusinessQuantitySelector(
              quantity: widget.businessQuantity,
              onChanged: widget.onBusinessQuantityChanged,
            ),
            const SizedBox(height: 18),
          ],
          Text(
            t.text(
              'Elige tu periodo de facturación',
              'Choose your billing period',
            ),
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _BillingOption(
            value: _EntryBillingCycle.annual,
            groupValue: widget.billingCycle,
            title: t.annual,
            price: annualPrice,
            badge: badge,
            onChanged: widget.onBillingCycleChanged,
          ),
          const SizedBox(height: 10),
          _BillingOption(
            value: _EntryBillingCycle.monthly,
            groupValue: widget.billingCycle,
            title: t.monthly,
            price: monthlyPrice,
            onChanged: widget.onBillingCycleChanged,
          ),
          Divider(height: widget.mobile ? 30 : 32, color: TaploeColors.border),
          _CheckoutRow(
            label: t.text('Termina prueba', 'Trial ends'),
            value: dueDate,
          ),
          const SizedBox(height: 12),
          _CheckoutRow(label: t.text('Hoy', 'Today'), value: zeroAmount),
          const Divider(height: 28, color: TaploeColors.border),
          _CheckoutRow(
            label: t.text('Después del trial', 'After trial'),
            value: amountAfterTrial,
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        if (!boundedHeight) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [checkoutBody, checkoutFooter],
          );
        }
        return Column(
          children: [
            Expanded(child: SingleChildScrollView(child: checkoutBody)),
            checkoutFooter,
          ],
        );
      },
    );
  }
}

class _TrialCheckLine extends StatelessWidget {
  final String label;
  final bool compact;

  const _TrialCheckLine(this.label, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_rounded,
          color: TaploeColors.success,
          size: compact ? 20 : 26,
        ),
        SizedBox(width: compact ? 8 : 14),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: context.text,
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessQuantitySelector extends StatefulWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _BusinessQuantitySelector({
    required this.quantity,
    required this.onChanged,
  });

  @override
  State<_BusinessQuantitySelector> createState() =>
      _BusinessQuantitySelectorState();
}

class _BusinessQuantitySelectorState extends State<_BusinessQuantitySelector> {
  late final TextEditingController _controller;
  Timer? _minimumResetTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.quantity.toString());
  }

  @override
  void didUpdateWidget(covariant _BusinessQuantitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.quantity.toString();
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _minimumResetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _setQuantity(int value) {
    _minimumResetTimer?.cancel();
    final clamped = value.clamp(
      TaploePricing.businessMinProfiles,
      TaploePricing.businessMaxProfiles,
    );
    widget.onChanged(clamped);
    _controller.text = clamped.toString();
  }

  void _handleChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    if (parsed < TaploePricing.businessMinProfiles) {
      _minimumResetTimer?.cancel();
      _minimumResetTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        final current = int.tryParse(_controller.text);
        if (current != null && current < TaploePricing.businessMinProfiles) {
          _setQuantity(TaploePricing.businessMinProfiles);
        }
      });
      return;
    }
    _minimumResetTimer?.cancel();
    if (parsed > TaploePricing.businessMaxProfiles) {
      _setQuantity(TaploePricing.businessMaxProfiles);
      return;
    }
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final t = taploeState.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: TaploeColors.blue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.text('Perfiles', 'Profiles'),
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t.text(
                    'Mínimo ${TaploePricing.businessMinProfiles}. Se cobrará por perfil.',
                    'Minimum ${TaploePricing.businessMinProfiles}. Billed per profile.',
                  ),
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _QuantityIconButton(
            icon: Icons.remove_rounded,
            onPressed: widget.quantity <= TaploePricing.businessMinProfiles
                ? null
                : () => _setQuantity(widget.quantity - 1),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            height: 44,
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _handleChanged,
              onSubmitted: (value) =>
                  _setQuantity(int.tryParse(value) ?? widget.quantity),
              style: GoogleFonts.dmSans(
                color: context.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: TaploeColors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TaploeColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TaploeColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: TaploeColors.blue,
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _QuantityIconButton(
            icon: Icons.add_rounded,
            onPressed: widget.quantity >= TaploePricing.businessMaxProfiles
                ? null
                : () => _setQuantity(widget.quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _QuantityIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _BillingOption extends StatelessWidget {
  final _EntryBillingCycle value;
  final _EntryBillingCycle groupValue;
  final String title;
  final String price;
  final String? badge;
  final ValueChanged<_EntryBillingCycle> onChanged;

  const _BillingOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.price,
    required this.onChanged,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: selected
                ? TaploeColors.blue.withValues(alpha: .06)
                : TaploeColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? TaploeColors.blue : TaploeColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? TaploeColors.blue : context.muted,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.dmSans(
                            color: context.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if (badge != null)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFBDEFF2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                badge!,
                                style: GoogleFonts.dmSans(
                                  color: const Color(0xFF26747A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      price,
                      style: GoogleFonts.dmSans(
                        color: context.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _CheckoutPrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: TaploeColors.blue,
          foregroundColor: TaploeColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TaploeRadius.pill),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TaploeColors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: Center(child: Text(label))),
                  const Icon(Icons.arrow_forward_rounded, size: 24),
                ],
              ),
      ),
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  final String label;
  final String value;

  const _CheckoutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: context.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EntryDialogVisual extends StatelessWidget {
  final bool mobile;

  const _EntryDialogVisual({this.mobile = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 320 : double.infinity,
      color: const Color(0xFFF3F4F6),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 34 : 52,
                mobile ? 34 : 60,
                mobile ? 34 : 52,
                mobile ? 34 : 60,
              ),
              child: Align(
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/perfil-alerta.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.phone_iphone_rounded,
                    color: TaploeColors.white,
                    size: 96,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: mobile ? 12 : 22,
            right: mobile ? 12 : 22,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              color: TaploeColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCheckoutPreviewPane extends StatelessWidget {
  final _EntryDialogPlan plan;
  final bool mobile;

  const _EntryCheckoutPreviewPane({required this.plan, this.mobile = false});

  @override
  Widget build(BuildContext context) {
    final isTeam = plan == _EntryDialogPlan.team;
    final t = taploeState.t;
    final benefits = isTeam
        ? [
            (
              Icons.groups_rounded,
              t.text('Administra perfiles', 'Manage profiles'),
            ),
            (
              Icons.palette_outlined,
              t.text('Imagen consistente', 'Consistent branding'),
            ),
            (
              Icons.bar_chart_rounded,
              t.text('Leads centralizados', 'Centralized leads'),
            ),
          ]
        : [
            (
              Icons.visibility_off_outlined,
              t.text('Perfil sin marca Taploe', 'Taploe-free profile'),
            ),
            (
              Icons.insights_rounded,
              t.text('Analítica avanzada', 'Advanced analytics'),
            ),
            (
              Icons.palette_outlined,
              t.text('Diseño personalizado', 'Custom design'),
            ),
          ];

    return Container(
      width: double.infinity,
      height: mobile ? null : double.infinity,
      color: const Color(0xFFF4F5F7),
      padding: EdgeInsets.fromLTRB(
        mobile ? 24 : 36,
        mobile ? 24 : 34,
        mobile ? 24 : 36,
        mobile ? 30 : 30,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: mobile ? 280 : 340,
              maxHeight: mobile ? 360 : 520,
            ),
            child: Image.asset(
              'assets/images/perfil-alerta.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.phone_iphone_rounded,
                color: TaploeColors.blue,
                size: 120,
              ),
            ),
          ),
          const SizedBox(height: 26),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              children: [
                for (var i = 0; i < benefits.length; i++) ...[
                  _CheckoutPreviewBenefit(
                    icon: benefits[i].$1,
                    label: benefits[i].$2,
                  ),
                  if (i != benefits.length - 1)
                    const Divider(height: 18, color: TaploeColors.border),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutPreviewBenefit extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CheckoutPreviewBenefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: TaploeColors.blue, size: 23),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: context.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback onPressed;

  const _EntryChoiceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? context.text : TaploeColors.white,
          foregroundColor: dark ? TaploeColors.white : context.text,
          side: BorderSide(color: dark ? context.text : TaploeColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProfileRequiredView extends StatefulWidget {
  final ValueChanged<DigitalProfileModel> onProfileCreated;

  const _ProfileRequiredView({required this.onProfileCreated});

  @override
  State<_ProfileRequiredView> createState() => _ProfileRequiredViewState();
}

class _ProfileRequiredViewState extends State<_ProfileRequiredView> {
  final slugController = TextEditingController();
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final user = taploeState.currentUser;
    final base = user?.username.trim().isNotEmpty == true
        ? user!.username
        : user?.email.split('@').first ?? '';
    slugController.text = normalizePublicSlug(base);
  }

  @override
  void dispose() {
    slugController.dispose();
    super.dispose();
  }

  Future<void> createProfile() async {
    if (saving) return;
    var user = taploeState.currentUser;
    if (user == null) {
      setState(() => errorText = 'Inicia sesión para crear tu perfil.');
      return;
    }

    final slug = normalizePublicSlug(slugController.text);
    if (slug.length < 3) {
      setState(
        () => errorText = 'La ruta debe tener al menos 3 letras o números.',
      );
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
      slugController.text = slug;
    });

    try {
      if (UserRepository.normalizeUsername(user.username) != slug) {
        if (await UserRepository.usernameExists(slug, excludeUserId: user.id)) {
          if (!mounted) return;
          setState(() {
            saving = false;
            errorText = 'Ese nombre de usuario ya está en uso.';
          });
          return;
        }

        user = await UserRepository.updateCurrentUser(
          username: slug,
          phone: user.phone,
          timezone: user.timezone,
        );
        taploeState.updateCurrentUser(user);
      }

      final profile = await ProfileRepository.createProfileForUser(
        user,
        displayName: slug,
        publicSlug: slug,
      );
      await taploeState.refreshProfiles();
      DigitalProfileModel? activeProfile;
      for (final item in taploeState.profiles) {
        if (item.id == profile.id) {
          activeProfile = item;
          break;
        }
      }
      taploeState.setActiveProfile(activeProfile ?? profile);
      if (!mounted) return;
      widget.onProfileCreated(activeProfile ?? profile);
    } catch (error) {
      safePrintError(error);
      if (!mounted) return;
      setState(() {
        saving = false;
        errorText = _createProfileErrorMessage(error, slug);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = taploeState.currentUser;
    final titleName = user?.username.trim().isNotEmpty == true
        ? user!.username.trim()
        : 'Taploe';

    return Scaffold(
      backgroundColor: TaploeColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TaploeLogo(size: 46),
                  const SizedBox(height: 42),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.isMobile ? 22 : 54,
                      vertical: context.isMobile ? 30 : 46,
                    ),
                    decoration: BoxDecoration(
                      color: TaploeColors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: TaploeColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          color: TaploeColors.blue,
                          size: 46,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Crea tu perfil digital',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: context.text,
                            fontSize: context.isMobile ? 32 : 42,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Hola, $titleName. Elige la ruta pública de tu perfil digital.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: context.muted,
                            fontSize: 17,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _PublicSlugInput(
                          controller: slugController,
                          errorText: taploeLocalizeNullableText(
                            context,
                            errorText,
                          ),
                          onChanged: (_) {
                            if (errorText != null) {
                              setState(() => errorText = null);
                            }
                          },
                          onSubmitted: (_) => createProfile(),
                        ),
                        const SizedBox(height: 22),
                        TaploeButton(
                          label: 'Crear perfil digital',
                          icon: Icons.add_rounded,
                          loading: saving,
                          expanded: true,
                          onPressed: createProfile,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Después podrás vincular una tarjeta Taploe si quieres usar NFC o QR físico.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: context.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextButton.icon(
                    onPressed: taploeState.signOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicSlugInput extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _PublicSlugInput({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_PublicSlugInput> createState() => _PublicSlugInputState();
}

class _PublicSlugInputState extends State<_PublicSlugInput> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final focused = focusNode.hasFocus;
    final borderColor = hasError
        ? TaploeColors.error
        : focused
        ? TaploeColors.blue
        : TaploeColors.borderStrong;
    const inactiveLabelColor = Color(0xFF9AA1B2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => focusNode.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: 76,
            decoration: BoxDecoration(
              color: focused ? const Color(0xFFF8FAFF) : TaploeColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
                width: hasError || focused ? 1.8 : 1,
              ),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color: TaploeColors.blue.withValues(alpha: 0.12),
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 26, right: 18),
                  child: Text(
                    'app.taploe.com/',
                    style: GoogleFonts.dmSans(
                      color: focused ? TaploeColors.blue : inactiveLabelColor,
                      fontSize: context.isMobile ? 17 : 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'username',
                          style: GoogleFonts.dmSans(
                            color: focused
                                ? TaploeColors.blue
                                : inactiveLabelColor,
                            fontSize: context.isMobile ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                        SizedBox(
                          height: 30,
                          child: TextField(
                            focusNode: focusNode,
                            controller: widget.controller,
                            enabled: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            keyboardType: TextInputType.url,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9-]'),
                              ),
                            ],
                            onChanged: widget.onChanged,
                            onSubmitted: widget.onSubmitted,
                            style: GoogleFonts.outfit(
                              color: context.text,
                              fontSize: context.isMobile ? 20 : 23,
                              fontWeight: FontWeight.w400,
                              height: 1.05,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              hintText: taploeLocalizeText(
                                context,
                                'tu-nombre',
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.errorText!,
              style: GoogleFonts.dmSans(
                color: TaploeColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InitialCardLinkView extends StatelessWidget {
  final VoidCallback onLinkCard;
  final VoidCallback onSkip;

  const _InitialCardLinkView({required this.onLinkCard, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final profile = taploeState.activeProfile;
    final titleName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName.trim()
        : 'tu perfil';

    return Scaffold(
      backgroundColor: TaploeColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TaploeLogo(size: 46),
                  const SizedBox(height: 42),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.isMobile ? 22 : 54,
                      vertical: context.isMobile ? 30 : 46,
                    ),
                    decoration: BoxDecoration(
                      color: TaploeColors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: TaploeColors.border),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/tarjeta-nfc.png',
                          height: context.isMobile ? 118 : 150,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.credit_card_rounded,
                            color: TaploeColors.blue,
                            size: 78,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Vincula una tarjeta Taploe',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: context.text,
                            fontSize: context.isMobile ? 32 : 42,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '$titleName ya está listo. Puedes conectar una tarjeta NFC o QR físico ahora, o hacerlo después desde Tarjetas.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: context.muted,
                            fontSize: 17,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 30),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: TaploePrimaryButton(
                            label: 'Vincular tarjeta',
                            icon: Icons.qr_code_scanner_rounded,
                            onPressed: onLinkCard,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: onSkip,
                          child: const Text('Omitir por ahora'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextButton.icon(
                    onPressed: taploeState.signOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final DashboardSection selected;
  final ValueChanged<DashboardSection> onSelected;

  const _TopHeader({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final profile = taploeState.activeProfile;
    final incomplete = _profileCompletion(profile) < 80;
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: TaploeColors.white,
        border: Border(bottom: BorderSide(color: TaploeColors.border)),
      ),
      child: Row(
        children: [
          if (taploeState.profiles.isNotEmpty)
            SizedBox(
              width: 250,
              child: _ActiveProfileSelector(
                profile: profile,
                profiles: taploeState.profiles,
                onSelected: taploeState.setActiveProfile,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (incomplete)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _SmallPill(
                          label: 'Perfil incompleto',
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                    _HeaderVerifiedBadgeToggle(profile: profile),
                    const SizedBox(width: 10),
                    _NotificationBell(
                      onOpenLeads: () => onSelected(DashboardSection.leads),
                      onOpenTeam: () => onSelected(DashboardSection.team),
                    ),
                    const SizedBox(width: 10),
                    TaploeButton(
                      width: 154,
                      label: 'Ver perfil',
                      icon: Icons.open_in_new_rounded,
                      kind: TaploeButtonKind.secondary,
                      onPressed: profile == null
                          ? null
                          : () => onSelected(DashboardSection.profile),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<String>(
                      tooltip: 'Cuenta',
                      offset: const Offset(0, 12),
                      constraints: const BoxConstraints(minWidth: 220),
                      color: TaploeColors.white,
                      surfaceTintColor: TaploeColors.white,
                      elevation: 10,
                      shadowColor: TaploeColors.black.withValues(alpha: .12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: TaploeColors.border),
                      ),
                      onSelected: (value) async {
                        if (value == 'settings') {
                          onSelected(DashboardSection.settings);
                        }
                        if (value == 'logout') await taploeState.signOut();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'settings',
                          child: _AccountMenuItem(
                            icon: Icons.settings_outlined,
                            label: 'Configuración',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: _AccountMenuItem(
                            icon: Icons.logout_rounded,
                            label: 'Cerrar sesión',
                          ),
                        ),
                      ],
                      child: _UserAvatar(
                        label:
                            taploeState.currentUser?.username.isNotEmpty == true
                            ? taploeState.currentUser!.username
                            : taploeState.currentUser?.email ?? 'T',
                        imageUrl: taploeState.activeProfile?.profilePhotoUrl,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderVerifiedBadgeToggle extends StatefulWidget {
  final DigitalProfileModel? profile;

  const _HeaderVerifiedBadgeToggle({required this.profile});

  @override
  State<_HeaderVerifiedBadgeToggle> createState() =>
      _HeaderVerifiedBadgeToggleState();
}

class _HeaderVerifiedBadgeToggleState
    extends State<_HeaderVerifiedBadgeToggle> {
  bool saving = false;

  Future<void> toggle(bool value) async {
    final profile = widget.profile;
    if (profile == null || saving) return;
    if (!_canEditProfile(profile)) {
      taploeToast(
        context,
        'Solo puedes actualizar tu perfil o perfiles que administras.',
        error: true,
      );
      return;
    }
    if (value && !taploeState.capabilities.canShowVerifiedBadge) {
      _showPlansDialog(context);
      return;
    }
    setState(() => saving = true);
    final updated = profile.copyWith(showVerifiedBadge: value);
    taploeState.updateActiveProfile(updated);
    try {
      final saved = await ProfileRepository.updateVerifiedBadge(
        profile: profile,
        value: value,
      );
      taploeState.updateActiveProfile(saved);
      await taploeState.refreshProfiles();
      if (mounted) {
        taploeToast(
          context,
          value
              ? 'Marca verificada activada.'
              : 'Marca verificada desactivada.',
        );
      }
    } catch (e) {
      safePrintError(e);
      taploeState.updateActiveProfile(profile);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos actualizar el verificado.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final active = profile?.showVerifiedBadge ?? false;
    return Opacity(
      opacity: profile == null || saving ? .55 : 1,
      child: Container(
        height: 46,
        padding: const EdgeInsets.only(left: 14, right: 8),
        decoration: BoxDecoration(
          color: TaploeColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? TaploeColors.blueBorder : TaploeColors.borderStrong,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_rounded,
              color: TaploeColors.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Verificado',
              style: GoogleFonts.dmSans(
                color: context.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: active,
              onChanged: profile == null || !_canEditProfile(profile)
                  ? null
                  : toggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AccountMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TaploeColors.textSecondary),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: TaploeColors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final double radius;
  final double fontSize;

  const _UserAvatar({
    required this.label,
    this.imageUrl,
    this.radius = 20,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl?.trim();
    if (cleanUrl?.isNotEmpty == true) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            cleanUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _InitialAvatar(
              label: label,
              radius: radius,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }
    return _InitialAvatar(label: label, radius: radius, fontSize: fontSize);
  }
}

class _InitialAvatar extends StatelessWidget {
  final String label;
  final double radius;
  final double fontSize;

  const _InitialAvatar({
    required this.label,
    required this.radius,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: TaploeColors.black,
      child: Text(
        initials(label),
        style: TextStyle(color: Colors.white, fontSize: fontSize),
      ),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  final VoidCallback onOpenLeads;
  final VoidCallback onOpenTeam;

  const _NotificationBell({
    required this.onOpenLeads,
    required this.onOpenTeam,
  });

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  List<AppNotificationModel> notifications = const [];
  final Set<String> _announcedUnreadIds = {};
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();
  TaploeRealtimeSubscription? _subscription;
  String? _subscribedUserId;
  bool _didLoadNotifications = false;
  bool loading = false;

  int get unreadCount =>
      notifications.where((notification) => notification.isUnread).length;

  @override
  void initState() {
    super.initState();
    taploeState.addListener(_handleTaploeStateChanged);
    _load();
  }

  @override
  void dispose() {
    taploeState.removeListener(_handleTaploeStateChanged);
    _subscription?.close();
    super.dispose();
  }

  void _handleTaploeStateChanged() {
    final user = taploeState.currentUser;
    if (user == null) {
      _subscription?.close();
      _subscription = null;
      _subscribedUserId = null;
      _announcedUnreadIds.clear();
      _didLoadNotifications = false;
      if (mounted && notifications.isNotEmpty) {
        setState(() => notifications = const []);
      }
      return;
    }
    if (user.id != _subscribedUserId) _load();
  }

  Future<void> _load() async {
    final user = taploeState.currentUser;
    if (user == null) return;
    _ensureNotificationSubscription(user.id);
    if (mounted) setState(() => loading = true);
    final rows = await NotificationRepository.fetchRecent(user.id);
    if (mounted) _showNewUnreadToast(rows);
    if (mounted) {
      setState(() {
        notifications = rows;
        loading = false;
      });
    }
  }

  void _ensureNotificationSubscription(String userId) {
    if (_subscribedUserId == userId) return;
    _subscription?.close();
    _subscribedUserId = userId;
    _subscription = TaploeRealtimeSubscription.forNotifications(
      userId: userId,
      onRefresh: _load,
    );
  }

  void _showNewUnreadToast(List<AppNotificationModel> rows) {
    final unread = rows.where((notification) => notification.isUnread).toList();
    if (!_didLoadNotifications) {
      _announcedUnreadIds
        ..clear()
        ..addAll(unread.map((notification) => notification.id));
      _didLoadNotifications = true;
      if (unread.isNotEmpty) _showUnreadToast(unread.first);
      return;
    }

    for (final notification in unread) {
      if (_announcedUnreadIds.add(notification.id)) {
        _showUnreadToast(notification);
        break;
      }
    }
  }

  void _showUnreadToast(AppNotificationModel notification) {
    taploeNotificationToast(
      context,
      title: _notificationToastTitle(notification),
      reason: _notificationReason(notification),
      actionLabel: 'Ver',
      onAction: () async {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await _load();
        if (!mounted) return;
        _menuKey.currentState?.showButtonMenu();
      },
    );
  }

  Future<void> _markAllAsRead() async {
    final user = taploeState.currentUser;
    if (user == null) return;
    await NotificationRepository.markAllAsRead(user.id);
    await _load();
  }

  Future<void> _openNotification(AppNotificationModel notification) async {
    if (notification.notificationType == 'team_invitation') {
      await _openTeamInvitation(notification);
      return;
    }
    if (notification.isUnread) {
      await NotificationRepository.markAsRead(notification.id);
      await _load();
    }
    widget.onOpenLeads();
  }

  Future<void> _openTeamInvitation(AppNotificationModel notification) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => _TeamInvitationDialog(notification: notification),
    );
    if (accepted == null) return;
    await _respondToTeamInvitation(notification, accept: accepted);
  }

  Future<void> _respondToTeamInvitation(
    AppNotificationModel notification, {
    required bool accept,
  }) async {
    final invitationId = notification.metadata['invitation_id']?.toString();
    final currentUser = taploeState.currentUser;
    if (invitationId == null || invitationId.isEmpty || currentUser == null) {
      return;
    }
    try {
      final orgId = notification.metadata['org_id']?.toString();
      await TeamRepository.respondToInvitation(
        invitationId: invitationId,
        user: currentUser,
        accept: accept,
      );
      if (accept && mounted) {
        OrganizationModel? org;
        if (orgId != null && orgId.isNotEmpty) {
          org = await OrganizationRepository.fetchById(orgId);
        }
        if (!mounted) return;
        await _showTeamWelcome(
          orgName:
              org?.name ??
              notification.metadata['org_name']?.toString() ??
              'tu nuevo equipo',
          logoUrl: org?.logoUrl,
        );
      }
      await taploeState.bootstrap();
      await _load();
      if (!mounted) return;
      if (accept) widget.onOpenTeam();
      if (!accept) taploeToast(context, 'Invitación declinada.');
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos responder esta invitación.');
      }
    }
  }

  Future<void> _showTeamWelcome({
    required String orgName,
    required String? logoUrl,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Bienvenido',
      barrierColor: TaploeColors.black.withValues(alpha: .36),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _TeamWelcomeToast(orgName: orgName, logoUrl: logoUrl),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: _menuKey,
      tooltip: 'Notificaciones',
      offset: const Offset(0, 12),
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 390),
      color: TaploeColors.white,
      surfaceTintColor: TaploeColors.white,
      elevation: 12,
      shadowColor: TaploeColors.black.withValues(alpha: .14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: TaploeColors.border),
      ),
      onOpened: _load,
      onSelected: (value) async {
        if (value == 'mark_all') {
          await _markAllAsRead();
          return;
        }
        if (value.startsWith('accept_team:') ||
            value.startsWith('decline_team:')) {
          final accept = value.startsWith('accept_team:');
          final notificationId = value.substring(value.indexOf(':') + 1);
          AppNotificationModel? notification;
          for (final item in notifications) {
            if (item.id == notificationId) {
              notification = item;
              break;
            }
          }
          if (notification != null) {
            await _respondToTeamInvitation(notification, accept: accept);
          }
          return;
        }
        AppNotificationModel? notification;
        for (final item in notifications) {
          if (item.id == value) {
            notification = item;
            break;
          }
        }
        if (notification != null) await _openNotification(notification);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: _NotificationsHeader(
            unreadCount: unreadCount,
            onMarkAllRead: unreadCount == 0
                ? null
                : () {
                    Navigator.of(context).pop('mark_all');
                  },
          ),
        ),
        if (loading && notifications.isEmpty)
          const PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (notifications.isEmpty)
          const PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: _EmptyNotifications(),
          )
        else
          ...notifications.map(
            (notification) => PopupMenuItem<String>(
              value: notification.id,
              enabled: notification.notificationType != 'team_invitation',
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: _NotificationTile(
                notification: notification,
                onAcceptTeam: notification.notificationType == 'team_invitation'
                    ? () => Navigator.of(
                        context,
                      ).pop('accept_team:${notification.id}')
                    : null,
                onDeclineTeam:
                    notification.notificationType == 'team_invitation'
                    ? () => Navigator.of(
                        context,
                      ).pop('decline_team:${notification.id}')
                    : null,
              ),
            ),
          ),
      ],
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: TaploeColors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: TaploeColors.borderStrong),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: TaploeColors.black,
                size: 22,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: TaploeColors.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: TaploeColors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: GoogleFonts.dmSans(
                      color: TaploeColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _notificationReason(AppNotificationModel notification) {
  return switch (notification.notificationType) {
    'lead_created' => 'Nuevo lead',
    'form_submit' => 'Formulario enviado',
    'team_invitation' => 'Invitación de equipo',
    'team_removed' => 'Cambio de equipo',
    'profile_view' => 'Visita al perfil',
    _ =>
      notification.title.trim().isEmpty ||
              notification.title.trim() == 'Notificación'
          ? 'Tienes pendientes'
          : notification.title.trim(),
  };
}

String _notificationToastTitle(AppNotificationModel notification) {
  return switch (notification.notificationType) {
    'lead_created' || 'form_submit' => 'Recibiste un lead',
    'team_invitation' => 'Recibiste una invitación',
    'team_removed' => 'Cambio en tu equipo',
    _ => 'Recibiste una notificación',
  };
}

class _NotificationsHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  const _NotificationsHeader({
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones',
                  style: GoogleFonts.outfit(
                    color: context.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  unreadCount == 0
                      ? 'Todo está leído'
                      : '$unreadCount sin leer',
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onMarkAllRead,
            child: const Text('Marcar leídas'),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationModel notification;
  final VoidCallback? onAcceptTeam;
  final VoidCallback? onDeclineTeam;

  const _NotificationTile({
    required this.notification,
    this.onAcceptTeam,
    this.onDeclineTeam,
  });

  @override
  Widget build(BuildContext context) {
    final showTeamActions =
        notification.notificationType == 'team_invitation' &&
        onAcceptTeam != null &&
        onDeclineTeam != null &&
        notification.metadata['status'] != 'accepted' &&
        notification.metadata['status'] != 'declined';

    return SizedBox(
      width: 340,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(
              _notificationIcon(notification.notificationType),
              color: TaploeColors.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: context.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (notification.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: TaploeColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _relativeTime(notification.createdAt),
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showTeamActions) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onDeclineTeam,
                        style: TextButton.styleFrom(
                          foregroundColor: TaploeColors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Declinar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: onAcceptTeam,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Aceptar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: TaploeColors.blue,
                          foregroundColor: TaploeColors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamWelcomeToast extends StatefulWidget {
  final String orgName;
  final String? logoUrl;

  const _TeamWelcomeToast({required this.orgName, required this.logoUrl});

  @override
  State<_TeamWelcomeToast> createState() => _TeamWelcomeToastState();
}

class _TeamWelcomeToastState extends State<_TeamWelcomeToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final random = math.Random(42);
    _pieces = List.generate(
      52,
      (_) => _ConfettiPiece(
        x: random.nextDouble(),
        delay: random.nextDouble() * .45,
        speed: .65 + random.nextDouble() * .55,
        size: 5 + random.nextDouble() * 8,
        drift: -42 + random.nextDouble() * 84,
        rotation: random.nextDouble() * math.pi,
        color: [
          TaploeColors.blue,
          TaploeColors.error,
          TaploeColors.success,
          const Color(0xFFFFC857),
          const Color(0xFF7C3AED),
        ][random.nextInt(5)],
      ),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = widget.logoUrl;
    final hasLogo = logoUrl != null && logoUrl.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  top: -90,
                  bottom: -40,
                  left: -32,
                  right: -32,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _controller.value,
                        pieces: _pieces,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                  decoration: BoxDecoration(
                    color: TaploeColors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: TaploeColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: TaploeColors.black.withValues(alpha: .16),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 116,
                        height: 78,
                        child: hasLogo
                            ? Image.network(
                                logoUrl.trim(),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    _TeamWelcomeFallbackLogo(
                                      orgName: widget.orgName,
                                    ),
                              )
                            : _TeamWelcomeFallbackLogo(orgName: widget.orgName),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Bienvenido a tu nuevo equipo',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: context.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.orgName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: TaploeColors.blue,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ],
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

class _TeamWelcomeFallbackLogo extends StatelessWidget {
  final String orgName;

  const _TeamWelcomeFallbackLogo({required this.orgName});

  @override
  Widget build(BuildContext context) {
    final cleanName = orgName.trim();
    return Center(
      child: Text(
        cleanName.isEmpty ? 'T' : cleanName.characters.first.toUpperCase(),
        style: GoogleFonts.outfit(
          color: TaploeColors.blue,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  final double x;
  final double delay;
  final double speed;
  final double size;
  final double drift;
  final double rotation;
  final Color color;

  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.drift,
    required this.rotation,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiPiece> pieces;

  const _ConfettiPainter({required this.progress, required this.pieces});

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final localProgress = ((progress - piece.delay) * piece.speed).clamp(
        0.0,
        1.0,
      );
      if (localProgress <= 0 || localProgress >= 1) continue;
      final opacity = localProgress < .82
          ? 1.0
          : (1 - ((localProgress - .82) / .18)).clamp(0.0, 1.0);
      final x =
          (piece.x * size.width) +
          (math.sin((progress * math.pi * 2) + piece.rotation) * piece.drift);
      final y =
          -24 + (size.height + 48) * Curves.easeOut.transform(localProgress);
      final paint = Paint()..color = piece.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation + (progress * math.pi * 3));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * .55,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pieces != pieces;
}

class _TeamInvitationDialog extends StatelessWidget {
  final AppNotificationModel notification;

  const _TeamInvitationDialog({required this.notification});

  @override
  Widget build(BuildContext context) {
    final orgName = notification.metadata['org_name']?.toString() ?? 'equipo';
    final invitedBy =
        notification.metadata['invited_by_name']?.toString() ?? 'Taploe';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.groups_rounded, color: TaploeColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Invitación de equipo',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Text(
        '$invitedBy te invitó a unirte a $orgName. Al aceptar podrás ver la analítica y actividad del equipo.',
        style: GoogleFonts.dmSans(color: context.muted, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Declinar'),
        ),
        TaploeButton(
          label: 'Aceptar',
          icon: Icons.check_rounded,
          width: 168,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: TaploeColors.blue,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Sin notificaciones recientes',
              style: GoogleFonts.dmSans(
                color: context.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuando lleguen nuevos leads aparecerán aquí.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _notificationIcon(String type) {
  return switch (type) {
    'team_invitation' => Icons.group_add_rounded,
    'lead_created' => Icons.person_add_alt_1_rounded,
    'form_submit' => Icons.dynamic_form_rounded,
    'profile_view' => Icons.visibility_outlined,
    _ => Icons.notifications_none_rounded,
  };
}

class _Sidebar extends StatelessWidget {
  final DashboardSection selected;
  final ValueChanged<DashboardSection> onSelected;

  const _Sidebar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = taploeState.t;
    final items = [
      (DashboardSection.home, Icons.space_dashboard_outlined, t.home),
      (
        DashboardSection.profile,
        Icons.person_outline_rounded,
        t.digitalProfile,
      ),
      (DashboardSection.cards, Icons.credit_card_rounded, t.cards),
      (
        DashboardSection.redirects,
        Icons.alt_route_rounded,
        t.text('Redirección', 'Redirects'),
      ),
      (DashboardSection.share, Icons.ios_share_rounded, t.share),
      (DashboardSection.analytics, Icons.insights_rounded, t.analytics),
      (DashboardSection.leads, Icons.handshake_outlined, 'Leads'),
      (DashboardSection.team, Icons.groups_outlined, t.team),
      (
        DashboardSection.admin,
        Icons.admin_panel_settings_outlined,
        t.administration,
      ),
      (DashboardSection.settings, Icons.settings_outlined, t.settings),
    ];
    final user = taploeState.currentUser;
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: TaploeColors.white,
        border: Border(right: BorderSide(color: TaploeColors.border)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
              children: [
                const TaploeLogo(size: 34, centered: true),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _UserAvatar(
                        label: user?.username.isNotEmpty == true
                            ? user!.username
                            : user?.email ?? 'T',
                        imageUrl: taploeState.activeProfile?.profilePhotoUrl,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user?.username.isNotEmpty == true
                              ? user!.username
                              : user?.email ?? 'Taploe',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ActiveProfileSelector(
                  profile: taploeState.activeProfile,
                  profiles: taploeState.profiles,
                  onSelected: taploeState.setActiveProfile,
                  sidebar: true,
                ),
                const SizedBox(height: 18),
                _CreateDropdownButton(
                  expanded: true,
                  onNewProfile: () => _showCreateProfileDialog(context),
                  onAddCard: () => _showCardLinkingDialog(context),
                ),
                const SizedBox(height: 18),
                Text(
                  'MENÚ',
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map((item) {
                  final active = selected == item.$1;
                  final showPremiumCrown = !_canViewDashboardSection(item.$1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelected(item.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: active ? TaploeColors.black : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: active
                                ? TaploeColors.black
                                : TaploeColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.$2,
                              size: 20,
                              color: active ? Colors.white : context.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : context.text,
                                ),
                              ),
                            ),
                            if (showPremiumCrown) ...[
                              const SizedBox(width: 8),
                              const FaIcon(
                                FontAwesomeIcons.crown,
                                color: Color(0xFF9CA3AF),
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (!taploeState.capabilities.hasPremiumFeatures)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  showDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => const _DashboardEntryDialog(
                      initialShowPlanComparison: false,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF315EF8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.crown,
                        color: Color(0xFFF5C84C),
                        size: 17,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Elegir plan ideal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: TaploeColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateDropdownButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onNewProfile;
  final VoidCallback onAddCard;

  const _CreateDropdownButton({
    required this.onNewProfile,
    required this.onAddCard,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final canCreateProfile = taploeState.capabilities.canCreateProfile(
      taploeState.profiles.length,
    );
    return PopupMenuButton<String>(
      tooltip: 'Crear',
      offset: const Offset(0, 58),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'profile') onNewProfile();
        if (value == 'card') onAddCard();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Nuevo perfil')),
              if (!canCreateProfile)
                const FaIcon(
                  FontAwesomeIcons.crown,
                  color: Color(0xFF9CA3AF),
                  size: 13,
                ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'card',
          child: Row(
            children: [
              Icon(Icons.add_card_rounded, size: 20),
              SizedBox(width: 10),
              Text('Vincular tarjeta'),
            ],
          ),
        ),
      ],
      child: Container(
        width: expanded ? double.infinity : null,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: TaploeColors.blue,
          borderRadius: BorderRadius.circular(TaploeRadius.pill),
          border: Border.all(color: TaploeColors.blue),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: TaploeColors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Crear',
              style: GoogleFonts.dmSans(
                color: TaploeColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: TaploeColors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCardLinkingDialog(BuildContext context) async {
  final user = taploeState.currentUser;

  if (user == null) {
    taploeToast(
      context,
      'Inicia sesión para vincular tu tarjeta.',
      error: true,
    );
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return TaploeCardLinkModal(
        user: user,
        onViewCard: () {
          Navigator.pop(dialogContext);
          context.go('/profile?step=design');
        },
        onCloseSuccess: () {
          Navigator.pop(dialogContext);
          context.go('/');
        },
      );
    },
  );
}

void _showPlansDialog(BuildContext context) {
  if (_hasActivePaidPlan()) {
    _showCurrentPlanManagement(context);
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        const _DashboardEntryDialog(initialShowPlanComparison: true),
  );
}

void _showCurrentPlanManagement(BuildContext context) {
  final subscription = _effectiveBillingSubscription();
  final user = taploeState.currentUser;
  final ownerCanManage =
      user != null &&
      (subscription == null ||
          subscription.ownerUserId.isEmpty ||
          subscription.ownerUserId == user.id);

  if (subscription?.stripeCustomerId?.trim().isNotEmpty == true &&
      ownerCanManage) {
    _openBillingPortal(
      context,
      scope: subscription!.isOrganizationScope ? 'organization' : 'user',
    );
    return;
  }

  taploeToast(
    context,
    ownerCanManage
        ? taploeState.t.text(
            'Ya tienes un plan de pago activo.',
            'You already have an active paid plan.',
          )
        : taploeState.t.text(
            'Tu equipo ya tiene un plan activo. Solo el owner puede administrar la suscripción.',
            'Your team already has an active plan. Only the owner can manage the subscription.',
          ),
  );
}

Future<void> _openStripeUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    taploeToast(context, 'Stripe devolvió una URL inválida.', error: true);
    return;
  }
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      taploeToast(context, 'No se pudo abrir Stripe.', error: true);
    }
  }
}

Future<void> _openBillingPortal(
  BuildContext context, {
  required String scope,
}) async {
  try {
    final portalUrl = await BillingRepository.createPortalSession(scope: scope);
    if (context.mounted) await _openStripeUrl(context, portalUrl);
  } catch (error) {
    safePrintError(error);
    if (context.mounted) {
      taploeToast(
        context,
        'No pudimos abrir el portal de facturación.',
        error: true,
      );
    }
  }
}

Future<DigitalProfileModel?> _showCreateProfileDialog(
  BuildContext context, {
  PhysicalCardModel? assignToCard,
}) async {
  final user = taploeState.currentUser;

  if (user == null) {
    taploeToast(context, 'Inicia sesión para crear un perfil.', error: true);
    return null;
  }

  final capabilities = taploeState.capabilities;
  if (!capabilities.canCreateProfile(taploeState.profiles.length)) {
    _showPlansDialog(context);
    return null;
  }

  final createdProfile = await showDialog<DigitalProfileModel>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _CreateProfileModal(user: user, assignToCard: assignToCard);
    },
  );

  if (createdProfile != null && context.mounted) {
    taploeToast(
      context,
      assignToCard == null
          ? 'Perfil creado.'
          : 'Perfil creado y vinculado a la tarjeta.',
    );
  }

  return createdProfile;
}

class _CreateProfileModal extends StatefulWidget {
  final AppUserModel user;
  final PhysicalCardModel? assignToCard;

  const _CreateProfileModal({required this.user, this.assignToCard});

  @override
  State<_CreateProfileModal> createState() => _CreateProfileModalState();
}

class _CreateProfileModalState extends State<_CreateProfileModal> {
  final nameController = TextEditingController();
  bool saving = false;
  String? errorText;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (saving) return;
    final capabilities = taploeState.capabilities;
    if (!capabilities.canCreateProfile(taploeState.profiles.length)) {
      Navigator.of(context).pop();
      _showPlansDialog(context);
      return;
    }
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => errorText = 'Escribe un nombre para el perfil.');
      return;
    }
    final normalizedName = name.toLowerCase();
    final duplicateName = taploeState.profiles.any(
      (profile) => profile.displayName.trim().toLowerCase() == normalizedName,
    );
    if (duplicateName) {
      setState(
        () => errorText =
            'Ya tienes un perfil llamado "$name". Usa otro nombre para distinguirlo.',
      );
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });

    try {
      final profile = await ProfileRepository.createProfileForUser(
        widget.user,
        displayName: name,
      );
      if (widget.assignToCard != null) {
        await CardRepository.changeActiveProfile(
          card: widget.assignToCard!,
          profile: profile,
          userId: widget.user.id,
        );
        await taploeState.refreshProfiles();
        await taploeState.refreshCards();
      } else {
        await taploeState.refreshProfiles();

        DigitalProfileModel? activeProfile;
        for (final item in taploeState.profiles) {
          if (item.id == profile.id) {
            activeProfile = item;
            break;
          }
        }
        taploeState.setActiveProfile(activeProfile ?? profile);
      }

      if (mounted) Navigator.pop(context, profile);
    } catch (error) {
      safePrintError(error);
      if (!mounted) return;
      setState(() {
        saving = false;
        errorText = _createProfileErrorMessage(error, name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Nuevo perfil',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.assignToCard == null
                  ? 'Crea un perfil adicional para compartir otra identidad, área o contacto.'
                  : 'Crea un perfil y vincúlalo a esta tarjeta.',
              style: GoogleFonts.dmSans(color: context.muted),
            ),
            const SizedBox(height: 18),
            TaploeTextField(
              label: 'Nombre del perfil',
              hint: 'Ej. Ventas Norte',
              controller: nameController,
              errorText: taploeLocalizeNullableText(context, errorText),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TaploeButton(
          width: 130,
          label: 'Cancelar',
          kind: TaploeButtonKind.secondary,
          onPressed: saving ? null : () => Navigator.pop(context),
        ),
        TaploeButton(
          width: 180,
          label: 'Crear perfil',
          icon: Icons.person_add_alt_1_rounded,
          loading: saving,
          onPressed: submit,
        ),
      ],
    );
  }
}

String _createProfileErrorMessage(Object error, String requestedName) {
  if (error is ArgumentError) {
    final message = error.message?.toString();
    if (message == 'profile_slug_taken') {
      return 'app.taploe.com/$requestedName ya está en uso. Elige otra ruta.';
    }
    if (message == 'profile_slug_too_short') {
      return 'La ruta debe tener al menos 3 letras o números.';
    }
    if (message == 'profile_limit_reached') {
      final capabilities = taploeState.capabilities;
      final limit = capabilities.maxProfiles ?? 0;
      return 'Tu plan ${capabilities.label} permite hasta $limit perfil${limit == 1 ? '' : 'es'}.';
    }
  }

  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    final details = (error.details ?? '').toString().toLowerCase();
    final combined = '$message $details';

    if (error.code == '23505') {
      if (combined.contains('public_slug') ||
          combined.contains('digital_profiles_public_slug_key')) {
        return 'app.taploe.com/$requestedName ya está en uso. Elige otra ruta.';
      }
      if (combined.contains('profile_name') ||
          combined.contains('display_name')) {
        return 'Ya existe un perfil con ese nombre. Escribe un nombre diferente.';
      }
      return 'Ya existe un registro con esos datos. Cambia el nombre e intenta de nuevo.';
    }

    if (error.code == '23514') {
      return 'El nombre genera un enlace público inválido. Usa letras, números o espacios.';
    }

    if (error.code == '42501' || combined.contains('row-level security')) {
      return 'Tu sesión no tiene permiso para crear perfiles. Cierra sesión, vuelve a entrar e intenta de nuevo.';
    }

    if (error.code == '23503') {
      return 'No pudimos asociar el perfil con tu usuario. Vuelve a iniciar sesión e intenta de nuevo.';
    }
  }

  final message = error.toString().toLowerCase();
  if (message.contains('duplicate key') || message.contains('already exists')) {
    return 'Ya existe un perfil con esos datos. Usa otro nombre.';
  }
  if (message.contains('network') || message.contains('failed to fetch')) {
    return 'No pudimos conectarnos con el servidor. Revisa tu conexión e intenta de nuevo.';
  }

  return 'No pudimos crear el perfil por un error inesperado. Intenta de nuevo.';
}

enum _CardLinkingStep { intro, scanning, validating, linking, success, error }

class TaploeCardLinkModal extends StatefulWidget {
  final AppUserModel user;
  final VoidCallback onViewCard;
  final VoidCallback onCloseSuccess;

  const TaploeCardLinkModal({
    super.key,
    required this.user,
    required this.onViewCard,
    required this.onCloseSuccess,
  });

  @override
  State<TaploeCardLinkModal> createState() => _TaploeCardLinkModalState();
}

class _TaploeCardLinkModalState extends State<TaploeCardLinkModal> {
  _CardLinkingStep step = _CardLinkingStep.intro;
  String? scannedToken;
  AccessResolutionModel? resolution;
  String? errorMessage;
  String? linkedProfileName;

  PhysicalCardModel? get card => resolution?.physicalCard;

  Future<void> _handleDetected(String rawValue) async {
    final token = _extractTaploeActivationToken(rawValue);
    _debugCardLink('QR detectado: raw="$rawValue", token="$token"');
    if (token == null) {
      setState(() {
        step = _CardLinkingStep.error;
        errorMessage = 'No pudimos reconocer este QR como una tarjeta Taploe.';
      });
      return;
    }

    setState(() {
      step = _CardLinkingStep.validating;
      scannedToken = token;
      errorMessage = null;
      resolution = null;
    });

    try {
      final resolved = await CardActivationService.resolveAccessToken(token);
      _debugCardLink(
        'Resolución: action=${resolved.action.name}, '
        'accessPoint=${resolved.accessPoint?.id}, '
        'targetType=${resolved.accessPoint?.targetType}, '
        'isActive=${resolved.accessPoint?.isActive}, '
        'physicalCardId=${resolved.accessPoint?.physicalCardId}, '
        'card=${resolved.physicalCard?.id}, '
        'cardStatus=${resolved.physicalCard?.status}, '
        'cardOwner=${resolved.physicalCard?.ownerUserId}, '
        'cardProfile=${resolved.physicalCard?.activeProfileId}',
      );
      final validationError = _validateResolvedCard(resolved);
      if (!mounted) return;
      if (validationError != null) {
        _debugCardLink('Validación rechazada: $validationError');
        setState(() {
          step = _CardLinkingStep.error;
          errorMessage = validationError;
          resolution = resolved;
        });
        return;
      }

      setState(() {
        resolution = resolved;
      });
      await _linkCard();
    } catch (error, stackTrace) {
      _debugCardLink('Error resolviendo token: $error');
      _debugCardLink(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        step = _CardLinkingStep.error;
        errorMessage = 'Esta tarjeta no está disponible para vincular.';
      });
    }
  }

  String? _validateResolvedCard(AccessResolutionModel resolved) {
    final accessPoint = resolved.accessPoint;
    final resolvedCard = resolved.physicalCard;

    if (accessPoint == null ||
        resolved.action == AccessResolutionAction.notFound) {
      _debugCardLink(
        'No se pudo leer profile_access_points desde el cliente. '
        'Se intentará validar durante la vinculación directa.',
      );
      return null;
    }

    if (!accessPoint.isActive ||
        resolved.action == AccessResolutionAction.disabled) {
      return 'Esta tarjeta no está disponible para vincular.';
    }

    if (accessPoint.targetType != 'activation' ||
        resolved.action != AccessResolutionAction.activate) {
      if (resolvedCard?.ownerUserId == widget.user.id) {
        return 'Esta tarjeta ya está vinculada a tu cuenta.';
      }
      if (resolvedCard?.ownerUserId != null) {
        return 'Esta tarjeta ya fue vinculada a otra cuenta.';
      }
      return 'Esta tarjeta no está disponible para vincular.';
    }

    if (accessPoint.physicalCardId == null || resolvedCard == null) {
      if (accessPoint.physicalCardId != null && resolvedCard == null) {
        _debugCardLink(
          'No se pudo leer physical_cards desde el cliente. '
          'Se intentará validar durante la vinculación directa.',
        );
        return null;
      }
      return 'Esta tarjeta no está disponible para vincular.';
    }

    if (resolvedCard.status == 'disabled' ||
        resolvedCard.status == 'lost' ||
        resolvedCard.status == 'replaced') {
      return 'Esta tarjeta no está disponible para vincular.';
    }

    if (resolvedCard.status == 'claimed' ||
        resolvedCard.ownerUserId != null ||
        resolvedCard.activeProfileId != null) {
      if (resolvedCard.ownerUserId == widget.user.id) {
        return 'Esta tarjeta ya está vinculada a tu cuenta.';
      }
      return 'Esta tarjeta ya fue vinculada a otra cuenta.';
    }

    return null;
  }

  Future<void> _linkCard() async {
    final token = scannedToken;
    if (token == null) return;

    setState(() => step = _CardLinkingStep.linking);

    try {
      await CardActivationService.activateCardByToken(token: token);
      await taploeState.refreshAll();
      if (!mounted) return;
      final fallbackName = widget.user.username.trim().isEmpty
          ? 'tu perfil Taploe'
          : widget.user.username.trim();
      setState(() {
        linkedProfileName =
            taploeState.activeProfile?.displayName ?? fallbackName;
        step = _CardLinkingStep.success;
      });
    } catch (error, stackTrace) {
      _debugCardLink('Error activando tarjeta: $error');
      _debugCardLink(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        step = _CardLinkingStep.error;
        errorMessage = _friendlyCardLinkError(error);
      });
    }
  }

  void _scanAgain() {
    setState(() {
      step = _CardLinkingStep.intro;
      scannedToken = null;
      resolution = null;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (step) {
            _CardLinkingStep.intro => _CardLinkingIntroCard(
              key: const ValueKey('intro'),
              onContinue: () =>
                  setState(() => step = _CardLinkingStep.scanning),
              onCancel: () => Navigator.pop(context),
            ),
            _CardLinkingStep.scanning => TaploeQrScannerView(
              key: const ValueKey('scanner'),
              onDetected: _handleDetected,
              onCancel: () => Navigator.pop(context),
            ),
            _CardLinkingStep.validating => _CardLinkingStatusCard(
              key: const ValueKey('validating'),
              title: 'Validando tarjeta',
              text: 'Estamos identificando tu tarjeta Taploe.',
              loading: true,
              onClose: () => Navigator.pop(context),
            ),
            _CardLinkingStep.linking => _CardLinkingStatusCard(
              key: const ValueKey('linking'),
              title: 'Vinculando tarjeta',
              text: 'Estamos conectando tu tarjeta al perfil.',
              loading: true,
              onClose: () {},
              showClose: false,
            ),
            _CardLinkingStep.success => _CardLinkingSuccessCard(
              key: const ValueKey('success'),
              profileName:
                  linkedProfileName ??
                  taploeState.activeProfile?.displayName ??
                  (widget.user.username.trim().isEmpty
                      ? 'tu perfil Taploe'
                      : widget.user.username.trim()),
              onViewCard: widget.onViewCard,
              onClose: widget.onCloseSuccess,
            ),
            _CardLinkingStep.error => _CardLinkingErrorCard(
              key: const ValueKey('error'),
              message:
                  errorMessage ??
                  'Esta tarjeta no está disponible para vincular.',
              onRetry: _scanAgain,
              onCancel: () => Navigator.pop(context),
            ),
          },
        ),
      ),
    );
  }
}

String? _extractTaploeActivationToken(String rawValue) {
  final value = rawValue.trim();
  final uri = Uri.tryParse(value);
  if (uri == null) return null;

  final segments = uri.pathSegments;
  if (segments.length < 2 || segments.first != 'a') return null;

  final token = segments[1].trim();
  if (token.isEmpty || token.length < 6) return null;
  return token;
}

void _debugCardLink(String message) {
  debugPrint('[TaploeCardLink] $message');
}

String _friendlyCardLinkError(Object error) {
  return safeActivationErrorMessage(
    error,
    fallback: 'Esta tarjeta no está disponible para vincular.',
  );
}

class _CardLinkingIntroCard extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const _CardLinkingIntroCard({
    super.key,
    required this.onContinue,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _CardLinkingShell(
      onClose: onCancel,
      backgroundColor: TaploeColors.white,
      borderColor: TaploeColors.border,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escanea el QR de tu tarjeta',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Localiza el QR impreso en tu tarjeta Taploe. En el siguiente paso activaremos la cámara para escanearlo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: TaploeColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TaploeColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: const _TaploeScanQrIllustration(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_rounded,
                color: TaploeColors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'El QR está en la tarjeta física. Colócalo frente a la cámara para vincularla.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TaploePrimaryButton(
            label: 'Continuar con escaneo',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: onContinue,
          ),
          const SizedBox(height: 10),
          TaploeOutlineButton(
            label: 'Cancelar',
            icon: Icons.close_rounded,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _TaploeScanQrIllustration extends StatelessWidget {
  const _TaploeScanQrIllustration();

  static const _assetPath = 'assets/images/taploe-scanqr.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Image.network(
        _assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.qr_code_scanner_rounded,
            color: TaploeColors.blue,
            size: 72,
          ),
        ),
      ),
    );
  }
}

class _CardLinkingStatusCard extends StatelessWidget {
  final String title;
  final String text;
  final bool loading;
  final VoidCallback onClose;
  final bool showClose;

  const _CardLinkingStatusCard({
    super.key,
    required this.title,
    required this.text,
    required this.loading,
    required this.onClose,
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) {
    return _CardLinkingShell(
      onClose: onClose,
      showClose: showClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loading
              ? const CircularProgressIndicator(color: TaploeColors.blue)
              : const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 42,
                  color: TaploeColors.blue,
                ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 30,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _CardLinkingSuccessCard extends StatelessWidget {
  final String profileName;
  final VoidCallback onViewCard;
  final VoidCallback onClose;

  const _CardLinkingSuccessCard({
    super.key,
    required this.profileName,
    required this.onViewCard,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return _CardLinkingShell(
      onClose: onClose,
      backgroundColor: TaploeColors.white,
      borderColor: TaploeColors.border,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 50,
            color: TaploeColors.success,
          ),
          const SizedBox(height: 18),
          Text(
            'Tarjeta vinculada',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.dmSans(color: context.muted, height: 1.45),
              children: [
                TextSpan(
                  text: taploeState.t.text(
                    'Tu tarjeta ya está conectada al perfil ',
                    'Your card is already connected to the ',
                  ),
                ),
                TextSpan(
                  text: profileName,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: taploeState.t.text('.', ' profile.')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TaploePrimaryButton(
            label: 'Completar mi perfil',
            icon: Icons.person_outline_rounded,
            onPressed: onViewCard,
          ),
          const SizedBox(height: 10),
          TaploeOutlineButton(
            label: 'Cerrar',
            icon: Icons.close_rounded,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _CardLinkingErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _CardLinkingErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _CardLinkingShell(
      onClose: onCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 46,
            color: TaploeColors.error,
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 25,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 24),
          TaploePrimaryButton(
            label: 'Intentar nuevamente',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: onRetry,
          ),
          const SizedBox(height: 10),
          TaploeOutlineButton(
            label: 'Cancelar',
            icon: Icons.close_rounded,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _CardLinkingShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onClose;
  final bool showClose;
  final Color backgroundColor;
  final Color borderColor;

  const _CardLinkingShell({
    required this.child,
    required this.onClose,
    this.showClose = true,
    this.backgroundColor = TaploeColors.white,
    this.borderColor = TaploeColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showClose)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Cerrar',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          child,
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
    this.subtitle,
    required this.child,
    this.leading,
    this.footer,
    this.maxWidth = 720,
    this.centeredHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 560;
    return Dialog(
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 24,
        vertical: 20,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              color: TaploeColors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: TaploeColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 20 : 28,
                      18,
                      isCompact ? 20 : 28,
                      footer == null ? 24 : 18,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: centeredHeader
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(height: 14),
                        ],
                        Text(
                          title,
                          textAlign: centeredHeader
                              ? TextAlign.center
                              : TextAlign.left,
                          style: GoogleFonts.outfit(
                            fontSize: isCompact ? 26 : 30,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: context.text,
                            height: 1.05,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            subtitle!,
                            textAlign: centeredHeader
                                ? TextAlign.center
                                : TextAlign.left,
                            style: GoogleFonts.dmSans(
                              color: context.muted,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
                if (footer != null)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 20 : 28,
                      14,
                      isCompact ? 20 : 28,
                      18,
                    ),
                    decoration: const BoxDecoration(
                      color: TaploeColors.white,
                      border: Border(
                        top: BorderSide(color: TaploeColors.border),
                      ),
                    ),
                    child: footer!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkTypeGridButton extends StatelessWidget {
  final _LinkTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _LinkTypeGridButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final faIcon = _fontAwesomeIconForLinkType(option.type);
    final color = _brandColorForLinkType(option.type) ?? TaploeColors.blue;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? TaploeColors.blue.withValues(alpha: .06)
              : TaploeColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? TaploeColors.blue : TaploeColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (faIcon != null)
                    FaIcon(faIcon, color: color, size: 23)
                  else
                    Icon(option.icon, color: color, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: context.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: TaploeColors.blue,
                  size: 17,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TaploePrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  const TaploePrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF2458FF),
          foregroundColor: TaploeColors.white,
          disabledBackgroundColor: TaploeColors.border,
          disabledForegroundColor: context.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TaploeRadius.pill),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class TaploeOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  const TaploeOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.text,
          side: const BorderSide(color: TaploeColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TaploeRadius.pill),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class TaploeSelectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final FaIconData? faIcon;
  final Color? faIconColor;
  final String? assetPath;
  final bool selected;
  final VoidCallback onTap;

  const TaploeSelectCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.faIcon,
    this.faIconColor,
    this.assetPath,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TaploeColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? TaploeColors.blue : TaploeColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            if (assetPath != null)
              TaploeAssetIcon(
                assetPath: assetPath,
                fallbackIcon: icon,
                size: 26,
              )
            else if (faIcon != null)
              FaIcon(faIcon, color: faIconColor ?? TaploeColors.blue, size: 24)
            else
              Icon(icon, color: TaploeColors.blue, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      color: context.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: TaploeColors.blue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class TaploeToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const TaploeToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: TaploeColors.blue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
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
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2458FF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaploeStepData {
  final IconData icon;
  final String label;
  final bool active;

  const TaploeStepData({
    required this.icon,
    required this.label,
    this.active = false,
  });
}

class TaploeStepIndicator extends StatelessWidget {
  final List<TaploeStepData> steps;

  const TaploeStepIndicator({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(child: _TaploeStep(data: steps[i])),
          if (i != steps.length - 1) const _TaploeStepLine(),
        ],
      ],
    );
  }
}

class _TaploeStep extends StatelessWidget {
  final TaploeStepData data;

  const _TaploeStep({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.active ? TaploeColors.blue : context.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: TaploeColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: data.active ? TaploeColors.blue : TaploeColors.border,
            ),
          ),
          child: Icon(data.icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: data.active ? context.text : context.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TaploeStepLine extends StatelessWidget {
  const _TaploeStepLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: CustomPaint(
        painter: _DashedLinePainter(color: TaploeColors.borderStrong),
        child: const SizedBox(height: 44),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 5.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class TaploePreviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const TaploePreviewCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: TaploeColors.blue, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(color: context.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class TaploeModalFooter extends StatelessWidget {
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback? onCancel;

  const TaploeModalFooter({
    super.key,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 430;
        final cancel = TextButton(
          onPressed: onCancel ?? () => Navigator.pop(context),
          child: const Text('Cancelar'),
        );
        final save = TaploePrimaryButton(
          label: primaryLabel,
          icon: primaryIcon,
          onPressed: onPrimary,
          height: 50,
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [save, const SizedBox(height: 8), cancel],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            cancel,
            const SizedBox(width: 12),
            SizedBox(width: 190, child: save),
          ],
        );
      },
    );
  }
}

class TaploeAssetIcon extends StatelessWidget {
  final String? assetPath;
  final IconData fallbackIcon;
  final double size;

  const TaploeAssetIcon({
    super.key,
    this.assetPath,
    required this.fallbackIcon,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path == null || path.isEmpty) {
      return Icon(fallbackIcon, color: TaploeColors.blue, size: size);
    }
    final fallback = Icon(fallbackIcon, color: TaploeColors.blue, size: size);
    return kIsWeb
        ? Image.network(
            path,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.asset(
            path,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => fallback,
          );
  }
}

class HomeOverviewView extends StatefulWidget {
  final ValueChanged<DashboardSection> onSelected;

  const HomeOverviewView({super.key, required this.onSelected});

  @override
  State<HomeOverviewView> createState() => _HomeOverviewViewState();
}

class _HomeOverviewViewState extends State<HomeOverviewView> {
  _HomeOverviewData? data;
  bool loading = true;
  String? _profileId;
  String? _capabilityKey;

  @override
  void initState() {
    super.initState();
    _load();
    taploeState.addListener(_handleTaploeStateChanged);
  }

  @override
  void dispose() {
    taploeState.removeListener(_handleTaploeStateChanged);
    super.dispose();
  }

  void _handleTaploeStateChanged() {
    final nextProfileId = taploeState.activeProfile?.id;
    final nextCapabilityKey = taploeState.capabilities.plan.name;
    if (nextProfileId != _profileId || nextCapabilityKey != _capabilityKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final p = taploeState.activeProfile;
    _profileId = p?.id;
    final capabilities = taploeState.capabilities;
    _capabilityKey = capabilities.plan.name;
    if (p == null) {
      if (mounted) {
        setState(() {
          data = null;
          loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => loading = true);

    const emptySummary = AnalyticsSummaryModel(
      profileViews: 0,
      nfcViews: 0,
      qrViews: 0,
      directViews: 0,
      linkClicks: 0,
      contactsSaved: 0,
      formSubmits: 0,
      viewsByDay: [],
      clicksByLabel: {},
    );
    final results = await Future.wait<Object>([
      capabilities.canViewAnalytics
          ? AnalyticsRepository.fetchSummary(p.id)
          : Future<AnalyticsSummaryModel>.value(emptySummary),
      capabilities.canViewLeads
          ? LeadRepository.fetchForProfile(p.id)
          : Future<List<LeadModel>>.value(const []),
      capabilities.canUseForms
          ? SmartFormRepository.fetchActiveForms(p.id)
          : Future<List<SmartFormModel>>.value(const []),
      capabilities.canViewAnalytics
          ? AnalyticsRepository.fetchRecentEvents(p.id)
          : Future<List<AnalyticsEventModel>>.value(const []),
    ]);

    if (taploeState.activeProfile?.id != p.id) return;
    if (mounted) {
      setState(() {
        data = _HomeOverviewData(
          summary: results[0] as AnalyticsSummaryModel,
          leads: results[1] as List<LeadModel>,
          forms: results[2] as List<SmartFormModel>,
          events: results[3] as List<AnalyticsEventModel>,
        );
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = taploeState.currentUser;
    final p = taploeState.activeProfile;
    final d = data;
    final s = d?.summary;
    final capabilities = taploeState.capabilities;
    final profileCards = p == null
        ? <PhysicalCardModel>[]
        : taploeState.cards
              .where((card) => card.activeProfileId == p.id)
              .toList();
    final completion = _profileCompletion(p);
    final ctr = (s == null || s.profileViews == 0)
        ? 0
        : ((s.linkClicks / s.profileViews) * 100).round();
    return PageShell(
      title: 'Hola, ${user?.username.split(' ').first ?? 'Taploe'}',
      subtitle: 'Aquí tienes un resumen de tu actividad y rendimiento.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
          ? const TaploeEmpty(
              title: 'Sin perfil seleccionado',
              message: 'Crea o selecciona un perfil para empezar.',
            )
          : Column(
              children: [
                if (!taploeState.hasLinkedCard) ...[
                  const _LinkCardPromptPanel(),
                  const SizedBox(height: 16),
                ],
                PwaInstallPanel(profile: p, compact: false),
                const SizedBox(height: 16),
                _HomeMetricsBar(
                  metrics: [
                    _HomeMetricData(
                      label: 'Vistas',
                      value: '${s?.profileViews ?? 0}',
                      icon: Icons.visibility_outlined,
                    ),
                    _HomeMetricData(
                      label: 'NFC',
                      value: '${s?.nfcViews ?? 0}',
                      icon: Icons.nfc_rounded,
                    ),
                    _HomeMetricData(
                      label: 'QR',
                      value: '${s?.qrViews ?? 0}',
                      icon: Icons.qr_code_rounded,
                    ),
                    _HomeMetricData(
                      label: 'Clicks',
                      value: '${s?.linkClicks ?? 0}',
                      icon: Icons.ads_click_rounded,
                    ),
                    _HomeMetricData(
                      label: 'Leads',
                      value: '${d?.leads.length ?? 0}',
                      icon: Icons.link_rounded,
                    ),
                    _HomeMetricData(
                      label: 'Tarjetas',
                      value: '${profileCards.length}',
                      icon: Icons.credit_card_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ResponsivePair(
                  breakpoint: 980,
                  leftFlex: 6,
                  rightFlex: 4,
                  left: Column(
                    children: [
                      if (!capabilities.canViewAnalytics)
                        const _PlanFeatureLockedPanel(
                          title: 'Rendimiento reciente',
                          message:
                              'Consulta vistas, clics, CTR y formularios enviados con Premium o Empresa.',
                          requiredPlan: 'Premium',
                          icon: Icons.show_chart_rounded,
                        )
                      else ...[
                        TaploePanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PanelHeader(
                                title: 'Rendimiento reciente',
                                icon: Icons.show_chart_rounded,
                                trailing: 'Últimos 7 días',
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 220,
                                child: _ViewsLineChart(
                                  values: s?.viewsByDay ?? const [],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _InsightChip(
                                    label: '$ctr% CTR',
                                    icon: Icons.ads_click_rounded,
                                  ),
                                  _InsightChip(
                                    label:
                                        '${s?.contactsSaved ?? 0} contactos guardados',
                                    icon: Icons.person_add_alt_rounded,
                                  ),
                                  if (capabilities.canUseForms)
                                    _InsightChip(
                                      label:
                                          '${s?.formSubmits ?? 0} formularios',
                                      icon: Icons.dynamic_form_rounded,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _QuickActionsPanel(
                        onShare: () =>
                            widget.onSelected(DashboardSection.share),
                        onProfile: () =>
                            widget.onSelected(DashboardSection.profile),
                        onCards: () =>
                            widget.onSelected(DashboardSection.cards),
                        onAnalytics: () =>
                            widget.onSelected(DashboardSection.analytics),
                      ),
                      const SizedBox(height: 16),
                      TaploePanel(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enlace público',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    TaploeConfig.profileUrl(p.publicSlug),
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      color: TaploeColors.blue,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TaploeButton(
                              width: 120,
                              label: 'Copiar',
                              kind: TaploeButtonKind.secondary,
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: TaploeConfig.profileUrl(p.publicSlug),
                                  ),
                                );
                                taploeToast(context, 'Enlace copiado.');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  right: Column(
                    children: [
                      TaploePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PanelHeader(
                              title: 'Salud del perfil',
                              icon: Icons.verified_user_outlined,
                            ),
                            const SizedBox(height: 14),
                            _ProgressBar(value: completion / 100),
                            const SizedBox(height: 10),
                            Text(
                              '$completion% completo',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: context.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _CheckRow(
                              label: 'Datos de contacto',
                              done:
                                  p.vcard?.email?.isNotEmpty == true ||
                                  p.vcard?.mobilePhone?.isNotEmpty == true,
                            ),
                            _CheckRow(
                              label: 'Enlace público listo',
                              done: p.publicSlug.isNotEmpty,
                            ),
                            _CheckRow(
                              label: 'Enlaces visibles',
                              done: p.links.isNotEmpty,
                            ),
                            _CheckRow(
                              label: 'Tarjeta conectada',
                              done: profileCards.isNotEmpty,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (capabilities.canViewAnalytics)
                        TaploePanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PanelHeader(
                                title: 'Actividad reciente',
                                icon: Icons.bolt_outlined,
                              ),
                              const SizedBox(height: 10),
                              _HomeActivityPanel(
                                events: d?.events ?? const [],
                                onAnalytics: () => widget.onSelected(
                                  DashboardSection.analytics,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const _PlanFeatureLockedPanel(
                          title: 'Actividad reciente',
                          message:
                              'Revisa eventos recientes de visitas, clics y conversiones con Premium o Empresa.',
                          requiredPlan: 'Premium',
                          icon: Icons.bolt_outlined,
                        ),
                      if (!capabilities.hasPremiumFeatures) ...[
                        const SizedBox(height: 16),
                        _ProPromptPanel(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _HomeOverviewData {
  final AnalyticsSummaryModel summary;
  final List<LeadModel> leads;
  final List<SmartFormModel> forms;
  final List<AnalyticsEventModel> events;

  const _HomeOverviewData({
    required this.summary,
    required this.leads,
    required this.forms,
    required this.events,
  });
}

class _HomeMetricData {
  final String label;
  final String value;
  final IconData icon;

  const _HomeMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _HomeMetricsBar extends StatelessWidget {
  final List<_HomeMetricData> metrics;

  const _HomeMetricsBar({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Wrap(
              spacing: 18,
              runSpacing: 20,
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width: (constraints.maxWidth - 18) / 2,
                      child: _HomeMetricItem(metric: metric),
                    ),
                  )
                  .toList(),
            );
          }
          return Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                Expanded(child: _HomeMetricItem(metric: metrics[i])),
                if (i != metrics.length - 1)
                  Container(
                    width: 1,
                    height: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: TaploeColors.border,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HomeMetricItem extends StatelessWidget {
  final _HomeMetricData metric;

  const _HomeMetricItem({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(metric.icon, color: TaploeColors.blue, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  style: GoogleFonts.outfit(
                    color: context.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onProfile;
  final VoidCallback onCards;
  final VoidCallback onAnalytics;

  const _QuickActionsPanel({
    required this.onShare,
    required this.onProfile,
    required this.onCards,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        title: 'Compartir perfil',
        subtitle: 'Comparte tu enlace público',
        icon: Icons.link_rounded,
        onTap: onShare,
      ),
      _QuickActionData(
        title: 'Ver mi perfil',
        subtitle: 'Revisa cómo ven tu perfil los demás',
        icon: Icons.badge_outlined,
        onTap: onProfile,
      ),
      _QuickActionData(
        title: 'Gestionar tarjetas',
        subtitle: 'Administra tus tarjetas NFC y QR',
        icon: Icons.credit_card_rounded,
        onTap: onCards,
      ),
      _QuickActionData(
        title: 'Ver analítica',
        subtitle: 'Mira el rendimiento detallado',
        icon: Icons.bar_chart_rounded,
        locked: !taploeState.capabilities.canViewAnalytics,
        onTap: onAnalytics,
      ),
    ];

    return TaploePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acciones rápidas',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.text,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: actions
                      .map(
                        (action) => SizedBox(
                          width: (constraints.maxWidth - 18) / 2,
                          child: _QuickActionItem(action: action),
                        ),
                      )
                      .toList(),
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    Expanded(child: _QuickActionItem(action: actions[i])),
                    if (i != actions.length - 1)
                      Container(
                        width: 1,
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        color: TaploeColors.border,
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool locked;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.locked = false,
    required this.onTap,
  });
}

class _QuickActionItem extends StatelessWidget {
  final _QuickActionData action;

  const _QuickActionItem({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: action.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(action.icon, color: TaploeColors.blue, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: context.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontWeight: FontWeight.w600,
                      height: 1.18,
                    ),
                  ),
                ],
              ),
            ),
            if (action.locked) ...[
              const SizedBox(width: 8),
              const FaIcon(
                FontAwesomeIcons.crown,
                color: Color(0xFFF5C84C),
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeActivityPanel extends StatelessWidget {
  final List<AnalyticsEventModel> events;
  final VoidCallback onAnalytics;

  const _HomeActivityPanel({required this.events, required this.onAnalytics});

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events
        .where((event) => !_isLegacyProfileInstallEvent(event.eventType))
        .take(5)
        .toList();
    if (visibleEvents.isNotEmpty) {
      return Column(children: visibleEvents.map(_ActivityTile.new).toList());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.bolt_rounded, color: TaploeColors.blue, size: 34),
            const SizedBox(height: 14),
            Text(
              'Sin actividad reciente.',
              style: GoogleFonts.dmSans(
                color: context.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuando tengas actividad, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            TaploeButton(
              width: 170,
              label: 'Ver analítica',
              icon: Icons.bar_chart_rounded,
              kind: TaploeButtonKind.secondary,
              onPressed: onAnalytics,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProPromptPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Necesitas más?',
                style: GoogleFonts.outfit(
                  color: context.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Descubre todas las funciones Pro para potenciar tu perfil.',
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          );
          final button = TaploeButton(
            width: 168,
            label: 'Explorar planes',
            icon: Icons.arrow_forward_rounded,
            kind: TaploeButtonKind.secondary,
            onPressed: () {},
          );

          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.diamond_outlined,
                  color: TaploeColors.blue,
                  size: 32,
                ),
                const SizedBox(height: 12),
                textContent,
                const SizedBox(height: 18),
                button,
              ],
            );
          }

          return Row(
            children: [
              const Icon(
                Icons.diamond_outlined,
                color: TaploeColors.blue,
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(child: textContent),
              const SizedBox(width: 14),
              button,
            ],
          );
        },
      ),
    );
  }
}

int _profileCompletion(DigitalProfileModel? profile) {
  if (profile == null) return 0;
  final checks = [
    profile.displayName.trim().isNotEmpty,
    profile.publicSlug.trim().isNotEmpty,
    profile.jobTitle?.trim().isNotEmpty == true,
    profile.companyName?.trim().isNotEmpty == true,
    profile.vcard?.email?.trim().isNotEmpty == true ||
        profile.vcard?.mobilePhone?.trim().isNotEmpty == true,
    profile.links.isNotEmpty,
  ];
  final done = checks.where((value) => value).length;
  return ((done / checks.length) * 100).round();
}

class _ResponsivePair extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double breakpoint;
  final int leftFlex;
  final int rightFlex;

  const _ResponsivePair({
    required this.left,
    required this.right,
    this.breakpoint = 900,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: leftFlex, child: left),
              const SizedBox(width: 16),
              Expanded(flex: rightFlex, child: right),
            ],
          );
        }
        return Column(children: [left, const SizedBox(height: 16), right]);
      },
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final FaIconData? faIcon;
  final Color? faIconColor;
  final String? trailing;

  const _PanelHeader({
    required this.title,
    required this.icon,
    this.faIcon,
    this.faIconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (faIcon != null)
          FaIcon(faIcon, color: faIconColor ?? TaploeColors.blue, size: 19)
        else
          Icon(icon, color: TaploeColors.blue, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.text,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              color: context.muted,
            ),
          ),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InsightChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: TaploeColors.blue),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              color: context.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;

  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 10,
        value: value.clamp(0, 1),
        backgroundColor: TaploeColors.subtle,
        valueColor: const AlwaysStoppedAnimation(TaploeColors.blue),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool done;

  const _CheckRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? TaploeColors.success : TaploeColors.muted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: context.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;

  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: GoogleFonts.dmSans(color: context.muted));
  }
}

class _ActivityTile extends StatelessWidget {
  final AnalyticsEventModel event;

  const _ActivityTile(this.event);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsEventIcon(event: event),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityEventLabel(event),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: context.text,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: context.muted,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _analyticsLocation(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: context.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fullDateTime12(event.occurredAt),
            style: GoogleFonts.dmSans(color: context.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _activityEventLabel(AnalyticsEventModel event) {
  final metadataLabel = event.metadata['label']?.toString().trim();
  final linkLabel = event.linkLabel?.trim();
  final label = metadataLabel?.isNotEmpty == true ? metadataLabel : linkLabel;
  final type = event.metadata['type']?.toString().trim();
  return switch (event.eventType) {
    'link_click' =>
      'Click en ${label?.isNotEmpty == true ? label : type ?? 'enlace'}',
    'calendar_click' =>
      label?.isNotEmpty == true ? 'Click en $label' : 'Click en agenda',
    _ => _eventLabel(event.eventType),
  };
}

class _SmallPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SmallPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TaploeColors.page,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TaploeColors.blue),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 118;
        return Container(
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            color: TaploeColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TaploeColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 16 : 18, color: TaploeColors.blue),
              SizedBox(height: compact ? 5 : 8),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: compact ? 22 : 24,
                  fontWeight: FontWeight.w600,
                  color: context.text,
                  height: 1,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: compact ? 12 : 14,
                  height: 1.1,
                  color: context.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopied;

  const _CopyRow({required this.label, required this.value, this.onCopied});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: context.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            onCopied?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: TaploeColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TaploeColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.copy_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TaploeColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TaploeColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: TaploeColors.blue),
              const SizedBox(width: 12),
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
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(color: context.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                color: context.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewsLineChart extends StatelessWidget {
  final List<int> values;

  const _ViewsLineChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final data = values.isEmpty ? List<int>.filled(7, 0) : values;
    final maxY = data.fold<int>(1, (max, value) => value > max ? value : max);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxY + 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: TaploeColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final labels = ['-6', '-5', '-4', '-3', '-2', 'Ayer', 'Hoy'];
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  labels[index],
                  style: GoogleFonts.dmSans(color: context.muted, fontSize: 11),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => TaploeColors.white,
            tooltipBorder: const BorderSide(color: TaploeColors.borderStrong),
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipMargin: 10,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    spot.y.toInt().toString(),
                    GoogleFonts.outfit(
                      color: TaploeColors.blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: TaploeColors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: TaploeColors.blue.withValues(alpha: .12),
            ),
            spots: [
              for (var i = 0; i < data.length; i++)
                FlSpot(i.toDouble(), data[i].toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _eventIcon(String type) {
  switch (type) {
    case 'profile_view':
      return Icons.visibility_outlined;
    case 'link_click':
    case 'calendar_click':
      return Icons.ads_click_rounded;
    case 'contact_save':
      return Icons.person_add_alt_rounded;
    case 'form_submit':
      return Icons.dynamic_form_rounded;
    case 'card_claimed':
      return Icons.credit_card_rounded;
    default:
      return Icons.bolt_outlined;
  }
}

String _eventLabel(String type) {
  switch (type) {
    case 'profile_view':
      return 'Visita al perfil';
    case 'link_click':
      return 'Click en enlace';
    case 'calendar_click':
      return 'Click en calendario';
    case 'contact_save':
      return 'Contacto guardado';
    case 'form_submit':
      return 'Formulario enviado';
    case 'card_claimed':
      return 'Tarjeta activada';
    default:
      return type.replaceAll('_', ' ');
  }
}

bool _isLegacyProfileInstallEvent(String type) {
  return type ==
      String.fromCharCodes(const [
        119,
        97,
        108,
        108,
        101,
        116,
        95,
        97,
        100,
        100,
      ]);
}

String _relativeTime(DateTime? date) {
  if (date == null) return '-';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return dateShort(date);
}

String _timeOnly(DateTime? date) {
  if (date == null) return '--:--';
  final period = date.hour >= 12 ? 'PM' : 'AM';
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final hour = hour12.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

String _fullDateTime12(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year} ${_timeOnly(date)}';
}

String _timelineDate(DateTime? date) {
  if (date == null) return '-';
  return dateShort(date).replaceAll('.', '');
}

String _timelineEventLabel(AnalyticsEventModel event) {
  final metadataLabel = event.metadata['label']?.toString().trim();
  final linkLabel = event.linkLabel?.trim();
  final label = metadataLabel?.isNotEmpty == true ? metadataLabel : linkLabel;
  final type = event.metadata['type']?.toString().trim();
  return switch (event.eventType) {
    'profile_view' =>
      event.accessChannel == 'nfc'
          ? 'Abrió el perfil desde NFC'
          : event.accessChannel == 'qr'
          ? 'Abrió el perfil desde QR'
          : 'Abrió el perfil digital',
    'link_click' =>
      'Hizo click en ${label?.isNotEmpty == true ? label : type ?? 'enlace'}',
    'calendar_click' => 'Hizo click en agenda',
    'contact_save' => 'Guardó el contacto',
    'form_submit' => 'Hizo el llenado de formulario',
    'lead_created' => 'Registró sus datos',
    _ => _eventLabel(event.eventType),
  };
}

IconData _timelineIcon(AnalyticsEventModel event) {
  return switch (event.eventType) {
    'profile_view' => Icons.language_rounded,
    'link_click' => Icons.ads_click_rounded,
    'calendar_click' => Icons.calendar_month_rounded,
    'contact_save' => Icons.person_add_alt_1_rounded,
    'form_submit' => Icons.assignment_outlined,
    _ => Icons.circle_outlined,
  };
}

String _leadSourceLabel(String? channel) {
  return switch (channel) {
    'nfc' => 'Llegó desde tarjeta NFC',
    'qr' => 'Llegó desde código QR',
    'manual' => 'Registro manual',
    'direct' || null || '' => 'Llegó desde enlace público',
    _ => 'Llegó desde $channel',
  };
}

String _shortLeadSourceLabel(String? channel) {
  return switch (channel) {
    'nfc' => 'Tarjeta NFC',
    'qr' => 'Código QR',
    'manual' => 'Contacto directo',
    'direct' || null || '' => 'Sitio web',
    _ => channel,
  };
}

IconData _leadSourceIcon(String? channel) {
  return switch (channel) {
    'nfc' => Icons.nfc_rounded,
    'qr' => Icons.qr_code_rounded,
    'manual' => Icons.person_outline_rounded,
    _ => Icons.language_rounded,
  };
}

String _leadStatusLabel(String status) {
  return switch (status) {
    'contacted' => 'Contactado',
    'new' => 'Nuevo',
    _ => status,
  };
}

Color _leadStatusColor(String status) {
  return switch (status) {
    'contacted' => TaploeColors.success,
    'new' => TaploeColors.blue,
    _ => TaploeColors.blue,
  };
}

String _numericDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

Future<void> _showSubmissionInfo(
  BuildContext context,
  AnalyticsEventModel event,
) async {
  final id = event.formSubmissionId;
  if (id == null) return;
  final submission = await LeadRepository.fetchSubmissionById(id);
  if (submission == null) {
    if (context.mounted) {
      taploeToast(context, 'No pudimos cargar la información.', error: true);
    }
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _SubmissionInfoDialog(submission: submission),
  );
}

class _SubmissionInfoDialog extends StatelessWidget {
  final FormSubmissionModel submission;

  const _SubmissionInfoDialog({required this.submission});

  @override
  Widget build(BuildContext context) {
    final entries = submission.data.entries
        .where((entry) => entry.value != null && '${entry.value}'.isNotEmpty)
        .where((entry) => entry.key != 'form_key')
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.dynamic_form_rounded,
                    color: TaploeColors.blue,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información registrada',
                          style: GoogleFonts.outfit(
                            color: context.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Formulario enviado ${_relativeTime(submission.submittedAt)}',
                          style: GoogleFonts.dmSans(
                            color: context.muted,
                            fontWeight: FontWeight.w600,
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
              if (entries.isEmpty)
                const _MutedText('El formulario no contiene datos visibles.')
              else ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 600;
                        final width = twoColumns
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: entries.map((entry) {
                            final value = '${entry.value}';
                            final action = _submissionActionForField(
                              context,
                              entry.key,
                              value,
                            );
                            return _SubmissionInfoField(
                              width: width,
                              icon: _submissionIconForKey(entry.key),
                              label: _prettySubmissionKey(entry.key),
                              value: value,
                              actionIcon: action?.icon,
                              actionTooltip: action?.tooltip,
                              onAction: action?.onPressed,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionFieldAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _SubmissionFieldAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
}

Future<void> _openSubmissionUri(BuildContext context, Uri uri) async {
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      taploeToast(context, 'No se pudo abrir la acción.', error: true);
    }
  }
}

_SubmissionFieldAction? _submissionActionForField(
  BuildContext context,
  String key,
  String value,
) {
  final normalized = key.toLowerCase();
  final cleanValue = value.trim();
  if (cleanValue.isEmpty) return null;
  if (normalized.contains('mail') || normalized.contains('correo')) {
    return _SubmissionFieldAction(
      icon: Icons.send_rounded,
      tooltip: 'Enviar correo',
      onPressed: () =>
          _openSubmissionUri(context, Uri(scheme: 'mailto', path: cleanValue)),
    );
  }
  if (normalized.contains('phone') ||
      normalized.contains('tel') ||
      normalized.contains('whatsapp')) {
    return _SubmissionFieldAction(
      icon: Icons.call_rounded,
      tooltip: 'Llamar',
      onPressed: () => _openSubmissionUri(
        context,
        Uri(scheme: 'tel', path: _cleanPhone(cleanValue)),
      ),
    );
  }
  return null;
}

class _SubmissionInfoField extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  const _SubmissionInfoField({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TaploeColors.blue, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null && actionIcon != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: actionTooltip,
              onPressed: onAction,
              style: IconButton.styleFrom(
                foregroundColor: TaploeColors.blue,
                minimumSize: const Size(36, 36),
                fixedSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              icon: Icon(actionIcon, size: 19),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _submissionIconForKey(String key) {
  final normalized = key.toLowerCase();
  if (normalized.contains('mail') || normalized.contains('correo')) {
    return Icons.mail_rounded;
  }
  if (normalized.contains('phone') ||
      normalized.contains('tel') ||
      normalized.contains('whatsapp')) {
    return Icons.phone_rounded;
  }
  if (normalized.contains('company') || normalized.contains('empresa')) {
    return Icons.business_rounded;
  }
  if (normalized.contains('message') || normalized.contains('mensaje')) {
    return Icons.notes_rounded;
  }
  if (normalized.contains('name') || normalized.contains('nombre')) {
    return Icons.person_rounded;
  }
  if (normalized.contains('job') || normalized.contains('cargo')) {
    return Icons.badge_rounded;
  }
  if (normalized.contains('location') || normalized.contains('ubicacion')) {
    return Icons.location_on_rounded;
  }
  return Icons.label_rounded;
}

String _prettySubmissionKey(String key) {
  const known = {
    'name': 'Nombre',
    'nombre': 'Nombre',
    'full_name': 'Nombre',
    'email': 'Email',
    'correo': 'Correo',
    'phone': 'Teléfono',
    'telefono': 'Teléfono',
    'company': 'Empresa',
    'empresa': 'Empresa',
    'message': 'Mensaje',
    'mensaje': 'Mensaje',
  };
  final mapped = known[key];
  if (mapped != null) return mapped;
  return key
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _MetricPanel extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricPanel({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: TaploeColors.blue, size: 22),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: context.text,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(color: context.muted, height: 1.15),
          ),
        ],
      ),
    );
  }
}

class _ActiveProfileSelector extends StatelessWidget {
  final DigitalProfileModel? profile;
  final List<DigitalProfileModel> profiles;
  final ValueChanged<DigitalProfileModel> onSelected;
  final bool sidebar;

  const _ActiveProfileSelector({
    required this.profile,
    required this.profiles,
    required this.onSelected,
    this.sidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName.trim()
        : 'Sin perfil seleccionado';
    final selectedId = profiles.any((item) => item.id == profile?.id)
        ? profile!.id
        : null;
    final radius = sidebar ? 16.0 : TaploeRadius.pill;

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedId,
        isExpanded: true,
        menuWidth: sidebar ? 222 : 250,
        borderRadius: BorderRadius.circular(16),
        icon: const SizedBox.shrink(),
        selectedItemBuilder: (context) => profiles
            .map(
              (_) => _ActiveProfileSelectorFace(
                name: name,
                sidebar: sidebar,
                radius: radius,
              ),
            )
            .toList(),
        items: profiles
            .map(
              (profile) => DropdownMenuItem<String>(
                value: profile.id,
                child: _ActiveProfileMenuItem(
                  profile: profile,
                  active: profile.id == selectedId,
                ),
              ),
            )
            .toList(),
        onChanged: profiles.isEmpty
            ? null
            : (id) {
                if (id == null) return;
                final match = profiles.where((item) => item.id == id);
                if (match.isNotEmpty) onSelected(match.first);
              },
        hint: _ActiveProfileSelectorFace(
          name: name,
          sidebar: sidebar,
          radius: radius,
        ),
      ),
    );
  }
}

class _ActiveProfileMenuItem extends StatelessWidget {
  final DigitalProfileModel profile;
  final bool active;

  const _ActiveProfileMenuItem({required this.profile, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.person_outline_rounded,
          size: 18,
          color: active ? TaploeColors.blue : context.muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            profile.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: context.text,
              fontWeight: active ? FontWeight.w600 : FontWeight.w600,
            ),
          ),
        ),
        if (active) ...[
          const SizedBox(width: 10),
          const Icon(Icons.check_rounded, size: 18, color: TaploeColors.blue),
        ],
      ],
    );
  }
}

class _ActiveProfileSelectorFace extends StatelessWidget {
  final String name;
  final bool sidebar;
  final double radius;

  const _ActiveProfileSelectorFace({
    required this.name,
    required this.sidebar,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: sidebar ? 66 : 68,
      padding: EdgeInsets.symmetric(
        horizontal: sidebar ? 12 : 14,
        vertical: sidebar ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: TaploeColors.blue),
      ),
      child: Row(
        children: [
          if (sidebar)
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: TaploeColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: TaploeColors.success.withValues(alpha: .42),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            )
          else
            const Icon(
              Icons.person_outline_rounded,
              color: TaploeColors.blue,
              size: 24,
            ),
          SizedBox(width: sidebar ? 8 : 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perfil seleccionado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (sidebar) ...[
                      const Icon(
                        Icons.person_outline_rounded,
                        color: TaploeColors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: context.text,
                          fontWeight: FontWeight.w600,
                          fontSize: sidebar ? 13 : 14,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: TaploeColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class ProfileEditorView extends StatefulWidget {
  final int initialStep;
  final VoidCallback onManageCompanyLogo;

  const ProfileEditorView({
    super.key,
    this.initialStep = 0,
    required this.onManageCompanyLogo,
  });

  @override
  State<ProfileEditorView> createState() => _ProfileEditorViewState();
}

class _ProfileEditorViewState extends State<ProfileEditorView> {
  final displayName = TextEditingController();
  final jobTitle = TextEditingController();
  final company = TextEditingController();
  final bio = TextEditingController();
  final slug = TextEditingController();
  final profilePhoto = TextEditingController();
  final logo = TextEditingController();
  final cover = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final website = TextEditingController();
  final address1 = TextEditingController();
  final address2 = TextEditingController();
  final city = TextEditingController();
  final region = TextEditingController();
  final postalCode = TextEditingController();
  final country = TextEditingController();
  final note = TextEditingController();
  late int step;
  bool saving = false;
  String? uploadingAsset;
  String? _loadedProfileId;
  String? _extrasProfileId;
  String? _extrasCapabilityKey;
  List<SmartFormModel> _forms = [];
  List<ProfileIntegrationModel> _integrations = [];
  bool _hydratingControllers = false;
  bool showVerifiedBadge = false;
  String? _loadedDesignPolicyOrgId;
  String? _loadedDesignPolicyFingerprint;
  bool _teamDesignLocked = false;
  bool _teamFormsLocked = false;
  bool _teamIntegrationsLocked = false;

  bool _isCompanyLinkedProfile(DigitalProfileModel profile) =>
      profile.orgId?.trim().isNotEmpty == true;

  String? _companyLogoUrlFor(DigitalProfileModel profile) {
    if (!_isCompanyLinkedProfile(profile)) return null;
    final org = taploeState.organization;
    final logoUrl = org?.logoUrl?.trim();
    return logoUrl == null || logoUrl.isEmpty ? null : logoUrl;
  }

  static int _clampStep(int value) {
    if (value < 0) return 0;
    if (value > 5) return 5;
    return value;
  }

  @override
  void initState() {
    super.initState();
    step = _clampStep(widget.initialStep);
    _fill();
    for (final controller in _previewControllers) {
      controller.addListener(_handlePreviewInputChanged);
    }
    taploeState.addListener(_fill);
  }

  @override
  void didUpdateWidget(covariant ProfileEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStep != widget.initialStep) {
      setState(() => step = _clampStep(widget.initialStep));
    }
  }

  @override
  void dispose() {
    taploeState.removeListener(_fill);
    for (final controller in _previewControllers) {
      controller.removeListener(_handlePreviewInputChanged);
    }
    for (final c in [
      displayName,
      jobTitle,
      company,
      bio,
      slug,
      profilePhoto,
      logo,
      cover,
      email,
      phone,
      whatsapp,
      website,
      address1,
      address2,
      city,
      region,
      postalCode,
      country,
      note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _previewControllers => [
    displayName,
    jobTitle,
    company,
    bio,
    slug,
    profilePhoto,
    logo,
    cover,
    email,
    phone,
    whatsapp,
    website,
    address1,
    address2,
    city,
    region,
    postalCode,
    country,
    note,
  ];

  void _handlePreviewInputChanged() {
    if (_hydratingControllers || !mounted) return;
    setState(() {});
  }

  void _fill() {
    final p = taploeState.activeProfile;
    if (p == null) return;
    final org = taploeState.organization;
    if (org == null && _loadedDesignPolicyOrgId != null) {
      _loadedDesignPolicyOrgId = null;
      _loadedDesignPolicyFingerprint = null;
      _teamDesignLocked = false;
      _teamFormsLocked = false;
      _teamIntegrationsLocked = false;
    } else if (org != null &&
        (_loadedDesignPolicyOrgId != org.id ||
            _loadedDesignPolicyFingerprint != _teamPolicyFingerprint(org))) {
      _loadedDesignPolicyOrgId = org.id;
      _loadedDesignPolicyFingerprint = _teamPolicyFingerprint(org);
      _loadTeamDesignPolicy(org);
    }
    if (_loadedProfileId != p.id) {
      _hydratingControllers = true;
      _loadedProfileId = p.id;
      _extrasProfileId = null;
      _extrasCapabilityKey = null;
      _forms = [];
      _integrations = [];
      displayName.text = p.displayName;
      jobTitle.text = p.jobTitle ?? '';
      company.text = p.companyName ?? '';
      bio.text = p.bio ?? '';
      slug.text = p.publicSlug;
      profilePhoto.text = p.profilePhotoUrl ?? '';
      logo.text = p.logoUrl ?? '';
      cover.text = p.coverPhotoUrl ?? '';
      showVerifiedBadge = p.showVerifiedBadge;
      email.text = p.vcard?.email ?? '';
      phone.text = p.vcard?.mobilePhone ?? p.vcard?.phone ?? '';
      whatsapp.text = p.vcard?.whatsappPhone ?? '';
      website.text = p.vcard?.websiteUrl ?? '';
      address1.text = p.vcard?.addressLine1 ?? '';
      address2.text = p.vcard?.addressLine2 ?? '';
      city.text = p.vcard?.city ?? '';
      region.text = p.vcard?.state ?? '';
      postalCode.text = p.vcard?.postalCode ?? '';
      country.text = p.vcard?.country ?? '';
      note.text = p.vcard?.note ?? '';
      _hydratingControllers = false;
      _loadProfileExtras(p.id);
    }
    if (_isCompanyLinkedProfile(p)) {
      logo.text = _companyLogoUrlFor(p) ?? '';
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadTeamDesignPolicy(OrganizationModel org) async {
    if (!mounted || taploeState.organization?.id != org.id) return;
    setState(() {
      _teamDesignLocked = org.enforceTeamProfileTheme;
      _teamFormsLocked = org.enforceTeamProfileForms;
      _teamIntegrationsLocked = org.enforceTeamProfileIntegrations;
    });
  }

  Future<void> _loadProfileExtras(String profileId) async {
    final capabilities = taploeState.capabilities;
    final capabilityKey = capabilities.plan.name;
    if (_extrasProfileId == profileId &&
        _extrasCapabilityKey == capabilityKey) {
      return;
    }
    _extrasProfileId = profileId;
    _extrasCapabilityKey = capabilityKey;
    final results = await Future.wait<Object>([
      capabilities.canUseForms
          ? SmartFormRepository.fetchForms(profileId)
          : Future<List<SmartFormModel>>.value(const []),
      capabilities.canUseIntegrations
          ? IntegrationRepository.fetchForProfile(profileId: profileId)
          : Future<List<ProfileIntegrationModel>>.value(const []),
    ]);
    if (!mounted || taploeState.activeProfile?.id != profileId) return;
    setState(() {
      _forms = results[0] as List<SmartFormModel>;
      _integrations = results[1] as List<ProfileIntegrationModel>;
    });
  }

  Future<void> _refreshProfileExtras() async {
    final p = taploeState.activeProfile;
    if (p == null) return;
    _extrasProfileId = null;
    await _loadProfileExtras(p.id);
  }

  void _handleVerifiedBadgeChanged(bool value) {
    if (value && !taploeState.capabilities.canShowVerifiedBadge) {
      setState(() => showVerifiedBadge = false);
      _showPlansDialog(context);
      return;
    }
    setState(() => showVerifiedBadge = value);
  }

  Future<void> save() async {
    final p = taploeState.activeProfile;
    if (p == null) return;
    if (!_canEditProfile(p)) {
      taploeToast(
        context,
        'Solo puedes actualizar tu perfil o perfiles que administras.',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      final cleanSlug = slugify(slug.text);
      final slugIsTaken = await ProfileRepository.slugExists(
        cleanSlug,
        excludeProfileId: p.id,
      );
      if (slugIsTaken) {
        if (mounted) {
          taploeToast(
            context,
            'Ese slug publico ya esta en uso. Elige otro.',
            error: true,
          );
        }
        return;
      }
      final capabilities = taploeState.capabilities;
      final updated = p.copyWith(
        displayName: displayName.text.trim(),
        jobTitle: jobTitle.text.trim(),
        companyName: company.text.trim(),
        bio: bio.text.trim(),
        publicSlug: cleanSlug,
        profilePhotoUrl: profilePhoto.text.trim().isEmpty
            ? null
            : profilePhoto.text.trim(),
        logoUrl: _isCompanyLinkedProfile(p)
            ? null
            : logo.text.trim().isEmpty
            ? null
            : logo.text.trim(),
        clearLogoUrl: _isCompanyLinkedProfile(p),
        coverPhotoUrl: capabilities.canUseDesign
            ? (cover.text.trim().isEmpty ? null : cover.text.trim())
            : p.coverPhotoUrl,
        showVerifiedBadge: capabilities.canShowVerifiedBadge
            ? showVerifiedBadge
            : false,
        vcard: ProfileVcardModel(
          id: p.vcard?.id,
          profileId: p.id,
          firstName: displayName.text.trim(),
          organization: company.text.trim(),
          title: jobTitle.text.trim(),
          email: email.text.trim(),
          mobilePhone: phone.text.trim(),
          whatsappPhone: whatsapp.text.trim(),
          websiteUrl: website.text.trim(),
          addressLine1: address1.text.trim(),
          addressLine2: address2.text.trim(),
          city: city.text.trim(),
          state: region.text.trim(),
          postalCode: postalCode.text.trim(),
          country: country.text.trim(),
          note: note.text.trim(),
        ),
      );
      taploeState.updateActiveProfile(updated);
      await ProfileRepository.updateProfile(updated);
      await taploeState.refreshProfiles();
      if (mounted) taploeToast(context, 'Perfil actualizado.');
    } catch (e) {
      safePrintError(e);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos guardar los cambios. Intenta de nuevo.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> uploadProfileAsset(
    String kind,
    TextEditingController controller,
  ) async {
    final p = taploeState.activeProfile;
    final user = taploeState.currentUser;
    final authUserId = taploeState.client.auth.currentUser?.id;
    if (p == null || user == null || authUserId == null) return;
    if (!_canEditProfile(p)) {
      taploeToast(
        context,
        'Solo puedes actualizar tu perfil o perfiles que administras.',
        error: true,
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _profileAssetAllowedExtensions,
      withData: true,
      allowMultiple: false,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (!_isAllowedProfileAsset(file.name)) {
      if (mounted) {
        taploeToast(
          context,
          'Solo puedes cargar imágenes JPG, PNG, WEBP, HEIC, HEIF o SVG.',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;

    Uint8List editorBytes;
    try {
      editorBytes = _isSvgProfileAsset(file.name)
          ? await _rasterizeSvgToPng(context, bytes, kind: kind)
          : bytes;
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos convertir el SVG a imagen. Revisa el archivo.',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;

    final editedBytes = await _showProfileAssetEditor(
      context,
      kind: kind,
      bytes: editorBytes,
    );
    if (editedBytes == null) return;

    setState(() => uploadingAsset = kind);
    try {
      final url = await ProfileAssetRepository.uploadProfileAsset(
        authUserId: authUserId,
        profileId: p.id,
        kind: kind,
        bytes: editedBytes,
        fileName: '$kind.jpg',
      );
      controller.text = url;
      await save();
      if (mounted) taploeToast(context, 'Imagen cargada.');
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos cargar la imagen. Revisa Storage.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => uploadingAsset = null);
    }
  }

  Future<void> uploadCompanyLogoFromDesign() async {
    final p = taploeState.activeProfile;
    final org = taploeState.organization;
    final authUserId = taploeState.client.auth.currentUser?.id;
    if (p == null || org == null || authUserId == null) return;
    if (!_isCompanyLinkedProfile(p)) return;
    if (!_canEditProfile(p)) {
      taploeToast(
        context,
        'Solo puedes actualizar tu perfil o perfiles que administras.',
        error: true,
      );
      return;
    }
    if (org.enforceTeamProfileTheme) {
      taploeToast(
        context,
        'El diseño corporativo está administrado desde Administración.',
        error: true,
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _profileAssetAllowedExtensions,
      withData: true,
      allowMultiple: false,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (!_isAllowedProfileAsset(file.name)) {
      if (mounted) {
        taploeToast(
          context,
          'Solo puedes cargar imágenes JPG, PNG, WEBP, HEIC, HEIF o SVG.',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;

    Uint8List editorBytes;
    try {
      editorBytes = _isSvgProfileAsset(file.name)
          ? await _rasterizeSvgToPng(context, bytes, kind: 'logo')
          : bytes;
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos convertir el SVG a imagen. Revisa el archivo.',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;

    final editedBytes = await _showProfileAssetEditor(
      context,
      kind: 'logo',
      bytes: editorBytes,
    );
    if (editedBytes == null) return;

    setState(() => uploadingAsset = 'company-logo');
    try {
      final url = await OrganizationAssetRepository.uploadCompanyLogo(
        authUserId: authUserId,
        bytes: editedBytes,
        fileName: 'company-logo.jpg',
      );
      await OrganizationRepository.updateCompanyLogo(org: org, logoUrl: url);
      logo.text = url;
      await taploeState.refreshAll();
      if (mounted) taploeToast(context, 'Logo de empresa actualizado.');
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos actualizar el logo.', error: true);
      }
    } finally {
      if (mounted) setState(() => uploadingAsset = null);
    }
  }

  DigitalProfileModel _previewProfile(DigitalProfileModel profile) {
    final capabilities = taploeState.capabilities;
    final links =
        profile.links.map((link) => _previewLinkWithCurrentValue(link)).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return profile.copyWith(
      displayName: displayName.text.trim().isEmpty
          ? profile.displayName
          : displayName.text.trim(),
      jobTitle: jobTitle.text.trim(),
      companyName: company.text.trim(),
      bio: bio.text.trim(),
      publicSlug: slugify(slug.text),
      profilePhotoUrl: profilePhoto.text.trim().isEmpty
          ? profile.profilePhotoUrl
          : profilePhoto.text.trim(),
      logoUrl: capabilities.canUseDesign
          ? _companyLogoUrlFor(profile) ??
                (logo.text.trim().isEmpty ? profile.logoUrl : logo.text.trim())
          : null,
      clearLogoUrl:
          !capabilities.canUseDesign ||
          (_isCompanyLinkedProfile(profile) &&
              _companyLogoUrlFor(profile) == null),
      coverPhotoUrl: capabilities.canUseDesign
          ? (cover.text.trim().isEmpty
                ? profile.coverPhotoUrl
                : cover.text.trim())
          : null,
      showVerifiedBadge: capabilities.canShowVerifiedBadge
          ? showVerifiedBadge
          : false,
      vcard: ProfileVcardModel(
        id: profile.vcard?.id,
        profileId: profile.id,
        firstName: displayName.text.trim(),
        organization: company.text.trim(),
        title: jobTitle.text.trim(),
        email: email.text.trim(),
        mobilePhone: phone.text.trim(),
        whatsappPhone: whatsapp.text.trim(),
        websiteUrl: website.text.trim(),
        addressLine1: address1.text.trim(),
        addressLine2: address2.text.trim(),
        city: city.text.trim(),
        state: region.text.trim(),
        postalCode: postalCode.text.trim(),
        country: country.text.trim(),
        note: note.text.trim(),
      ),
      links: links,
    );
  }

  ProfileLinkModel _previewLinkWithCurrentValue(ProfileLinkModel link) {
    final value = switch (link.linkType) {
      'email' => email.text.trim(),
      'phone' => phone.text.trim(),
      'whatsapp' => whatsapp.text.trim(),
      'website' => website.text.trim(),
      'maps' => [
        address1.text,
        city.text,
        region.text,
        country.text,
      ].where((part) => part.trim().isNotEmpty).join(', '),
      _ => null,
    };
    if (value == null || value.isEmpty) return link;
    return ProfileLinkModel(
      id: link.id,
      profileId: link.profileId,
      linkType: link.linkType,
      label: link.label,
      value: value,
      url: _linkUrlFor(link.linkType, value),
      iconKey: link.iconKey,
      isVisible: link.isVisible,
      isFeatured: link.isFeatured,
      sortOrder: link.sortOrder,
      openMode: link.openMode,
      metadata: link.metadata,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = taploeState.activeProfile;
    final capabilities = taploeState.capabilities;
    final allSteps = const [
      (0, 'Perfil'),
      (1, 'Contacto'),
      (2, 'Enlaces'),
      (3, 'Diseño'),
      (4, 'Formularios'),
      (5, 'Integraciones'),
    ];
    final steps = allSteps;
    if (!steps.any((item) => item.$1 == step)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => step = steps.first.$1);
      });
    }
    final stepPosition = steps.indexWhere((item) => item.$1 == step);
    final effectiveStepPosition = stepPosition < 0 ? 0 : stepPosition;
    final currentStep = steps[effectiveStepPosition];
    return PageShell(
      title: 'Perfil digital',
      subtitle:
          'Edita tu perfil, contacto, diseño y flujos de captura desde un mismo lugar.',
      actions: [
        _SmallPill(
          label:
              'Paso ${effectiveStepPosition + 1} de ${steps.length}: ${currentStep.$2}',
          icon: Icons.route_outlined,
        ),
        IconButton.outlined(
          tooltip: 'Paso anterior',
          onPressed: effectiveStepPosition == 0
              ? null
              : () =>
                    setState(() => step = steps[effectiveStepPosition - 1].$1),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        IconButton.outlined(
          tooltip: 'Siguiente paso',
          onPressed: effectiveStepPosition == steps.length - 1
              ? null
              : () =>
                    setState(() => step = steps[effectiveStepPosition + 1].$1),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        TaploeButton(
          label: 'Guardar cambios',
          width: 190,
          loading: saving,
          onPressed: save,
        ),
      ],
      child: p == null
          ? const TaploeEmpty(
              title: 'Sin perfil',
              message: 'No hay perfil para editar.',
            )
          : _ResponsivePair(
              breakpoint: 1120,
              leftFlex: 8,
              rightFlex: 3,
              left: _ResponsivePair(
                breakpoint: 820,
                leftFlex: 2,
                rightFlex: 5,
                left: TaploePanel(
                  child: Column(
                    children: [
                      for (final item in steps)
                        _WizardStepTile(
                          index: item.$1,
                          label: item.$2,
                          active: step == item.$1,
                          locked:
                              (item.$1 == 3 && !capabilities.canUseDesign) ||
                              (item.$1 == 4 && !capabilities.canUseForms) ||
                              (item.$1 == 5 &&
                                  !capabilities.canUseIntegrations) ||
                              (item.$1 == 3 && _teamDesignLocked) ||
                              (item.$1 == 4 && _teamFormsLocked) ||
                              (item.$1 == 5 && _teamIntegrationsLocked),
                          premiumLocked:
                              (item.$1 == 3 && !capabilities.canUseDesign) ||
                              (item.$1 == 4 && !capabilities.canUseForms) ||
                              (item.$1 == 5 &&
                                  !capabilities.canUseIntegrations),
                          done: _profileStepDone(
                            p,
                            item.$1,
                            forms: _forms,
                            integrations: _integrations,
                          ),
                          onTap: () => setState(() => step = item.$1),
                        ),
                    ],
                  ),
                ),
                right: _ProfileStepPanel(
                  step: step,
                  profile: p,
                  displayName: displayName,
                  jobTitle: jobTitle,
                  company: company,
                  bio: bio,
                  slug: slug,
                  profilePhoto: profilePhoto,
                  logo: logo,
                  cover: cover,
                  showVerifiedBadge: showVerifiedBadge,
                  onVerifiedBadgeChanged: _handleVerifiedBadgeChanged,
                  capabilities: capabilities,
                  uploadingAsset: uploadingAsset,
                  onUploadProfilePhoto: () =>
                      uploadProfileAsset('profile-photo', profilePhoto),
                  onUploadLogo: _isCompanyLinkedProfile(p)
                      ? uploadCompanyLogoFromDesign
                      : () => uploadProfileAsset('logo', logo),
                  onManageCompanyLogo:
                      _isCompanyLinkedProfile(p) && !_teamDesignLocked
                      ? uploadCompanyLogoFromDesign
                      : widget.onManageCompanyLogo,
                  companyLogoUrl: _companyLogoUrlFor(p),
                  companyLinked: _isCompanyLinkedProfile(p),
                  onUploadCover: () => uploadProfileAsset('cover', cover),
                  designLocked: _teamDesignLocked,
                  formsLocked: _teamFormsLocked,
                  integrationsLocked: _teamIntegrationsLocked,
                  email: email,
                  phone: phone,
                  whatsapp: whatsapp,
                  website: website,
                  address1: address1,
                  address2: address2,
                  city: city,
                  region: region,
                  postalCode: postalCode,
                  country: country,
                  note: note,
                  save: save,
                  forms: _forms,
                  integrations: _integrations,
                  onChangedExtras: _refreshProfileExtras,
                ),
              ),
              right: TaploePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PanelHeader(
                      title: 'Vista previa',
                      icon: Icons.phone_iphone_rounded,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Así se verá tu perfil público en Taploe.',
                      style: GoogleFonts.dmSans(color: context.muted),
                    ),
                    const SizedBox(height: 14),
                    _CopyRow(
                      label: 'URL pública',
                      value: TaploeConfig.profileUrl(slugify(slug.text)),
                      onCopied: () => taploeToast(context, 'URL copiada.'),
                    ),
                    const SizedBox(height: 16),
                    _DigitalProfilePhonePreview(
                      profile: _previewProfile(p),
                      forms: capabilities.canUseForms ? _forms : const [],
                      integrations: capabilities.canUseIntegrations
                          ? _integrations
                          : const [],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

bool _profileStepDone(
  DigitalProfileModel profile,
  int step, {
  List<SmartFormModel> forms = const [],
  List<ProfileIntegrationModel> integrations = const [],
}) {
  switch (step) {
    case 0:
      return profile.displayName.isNotEmpty && profile.publicSlug.isNotEmpty;
    case 1:
      return profile.vcard?.email?.isNotEmpty == true ||
          profile.vcard?.mobilePhone?.isNotEmpty == true ||
          profile.vcard?.websiteUrl?.isNotEmpty == true;
    case 2:
      return profile.links.where((link) => link.isVisible).isNotEmpty;
    case 3:
      return profile.theme != null;
    case 4:
      return forms.isNotEmpty;
    case 5:
      return integrations.isNotEmpty;
    default:
      return false;
  }
}

class _WizardStepTile extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  final bool done;
  final bool locked;
  final bool premiumLocked;
  final VoidCallback onTap;

  const _WizardStepTile({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
    this.locked = false,
    this.premiumLocked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: active ? TaploeColors.black : TaploeColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? TaploeColors.black : TaploeColors.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: active ? Colors.white : TaploeColors.page,
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.dmSans(
                    color: active ? TaploeColors.black : context.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: active ? Colors.white : context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (premiumLocked)
                FaIcon(
                  FontAwesomeIcons.crown,
                  size: 15,
                  color: active ? const Color(0xFFF5C84C) : TaploeColors.muted,
                )
              else
                Icon(
                  locked
                      ? Icons.lock_rounded
                      : done
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 18,
                  color: locked
                      ? TaploeColors.warning
                      : done
                      ? TaploeColors.success
                      : active
                      ? Colors.white70
                      : TaploeColors.borderStrong,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedBadgeToggleCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _VerifiedBadgeToggleCard({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value ? TaploeColors.blueBorder : TaploeColors.border,
          width: value ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            color: TaploeColors.blue,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Verificado',
                      style: GoogleFonts.outfit(
                        color: context.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: TaploeColors.blue.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Premium',
                        style: GoogleFonts.dmSans(
                          color: TaploeColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Mostrar marca de verificado junto a tu nombre público.',
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

class _ProfileStepPanel extends StatelessWidget {
  final int step;
  final DigitalProfileModel profile;
  final TextEditingController displayName;
  final TextEditingController jobTitle;
  final TextEditingController company;
  final TextEditingController bio;
  final TextEditingController slug;
  final TextEditingController profilePhoto;
  final TextEditingController logo;
  final TextEditingController cover;
  final bool showVerifiedBadge;
  final ValueChanged<bool> onVerifiedBadgeChanged;
  final TaploePlanCapabilities capabilities;
  final String? uploadingAsset;
  final VoidCallback onUploadProfilePhoto;
  final VoidCallback onUploadLogo;
  final VoidCallback onManageCompanyLogo;
  final VoidCallback onUploadCover;
  final String? companyLogoUrl;
  final bool companyLinked;
  final bool designLocked;
  final bool formsLocked;
  final bool integrationsLocked;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController whatsapp;
  final TextEditingController website;
  final TextEditingController address1;
  final TextEditingController address2;
  final TextEditingController city;
  final TextEditingController region;
  final TextEditingController postalCode;
  final TextEditingController country;
  final TextEditingController note;
  final VoidCallback save;
  final List<SmartFormModel> forms;
  final List<ProfileIntegrationModel> integrations;
  final Future<void> Function() onChangedExtras;

  const _ProfileStepPanel({
    required this.step,
    required this.profile,
    required this.displayName,
    required this.jobTitle,
    required this.company,
    required this.bio,
    required this.slug,
    required this.profilePhoto,
    required this.logo,
    required this.cover,
    required this.showVerifiedBadge,
    required this.onVerifiedBadgeChanged,
    required this.capabilities,
    required this.uploadingAsset,
    required this.onUploadProfilePhoto,
    required this.onUploadLogo,
    required this.onManageCompanyLogo,
    required this.onUploadCover,
    required this.companyLogoUrl,
    required this.companyLinked,
    this.designLocked = false,
    this.formsLocked = false,
    this.integrationsLocked = false,
    required this.email,
    required this.phone,
    required this.whatsapp,
    required this.website,
    required this.address1,
    required this.address2,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.note,
    required this.save,
    required this.forms,
    required this.integrations,
    required this.onChangedExtras,
  });

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step == 0) ...[
            _PanelHeader(title: 'Perfil', icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            Center(
              child: _ProfilePhotoHeroPicker(
                value: profilePhoto.text,
                loading: uploadingAsset == 'profile-photo',
                onTap: onUploadProfilePhoto,
              ),
            ),
            const SizedBox(height: 18),
            TaploeTextField(
              label: 'Nombre completo',
              controller: displayName,
              hint: 'Tu nombre',
              onSubmitted: (_) => save(),
            ),
            const SizedBox(height: 14),
            _VerifiedBadgeToggleCard(
              value: showVerifiedBadge,
              onChanged: onVerifiedBadgeChanged,
            ),
            const SizedBox(height: 14),
            TaploeTextField(
              label: 'Cargo / rol',
              controller: jobTitle,
              hint: 'Director comercial',
              onSubmitted: (_) => save(),
            ),
            const SizedBox(height: 14),
            TaploeTextField(
              label: 'Empresa',
              controller: company,
              hint: 'Taploe',
              onSubmitted: (_) => save(),
            ),
            const SizedBox(height: 14),
            TaploeTextField(
              label: 'Bio',
              controller: bio,
              hint: 'Ayudo a equipos a compartir contactos con NFC y QR.',
              maxLines: 3,
            ),
          ],
          if (step == 1) ...[
            _PanelHeader(
              title: 'Información de contacto',
              icon: Icons.contact_mail_outlined,
              faIcon: FontAwesomeIcons.whatsapp,
              faIconColor: _brandColorForLinkType('whatsapp'),
            ),
            const SizedBox(height: 8),
            Text(
              'Completa tus datos y decide cuáles aparecerán como acciones en tu perfil público.',
              style: GoogleFonts.dmSans(color: context.muted),
            ),
            const SizedBox(height: 16),
            _ContactFieldCard(
              icon: Icons.mail_outline_rounded,
              iconColor: _brandColorForLinkType('email') ?? TaploeColors.blue,
              faIcon: FontAwesomeIcons.envelope,
              title: 'Correo',
              helper: 'Tu correo electrónico principal',
              controller: email,
              hint: 'da@ejemplo.com',
              keyboardType: TextInputType.emailAddress,
              visible: _contactLinkVisible(profile, 'email'),
              onSubmitted: save,
              onVisibilityChanged: (visible) => _toggleContactLink(
                context,
                profile: profile,
                type: 'email',
                label: 'Enviar correo',
                value: email.text,
                visible: visible,
              ),
            ),
            const SizedBox(height: 12),
            _ContactFieldCard(
              icon: Icons.phone_outlined,
              iconColor: TaploeColors.success,
              title: 'Teléfono',
              helper: 'Número de contacto principal',
              controller: phone,
              hint: '+52 664 123 4567',
              keyboardType: TextInputType.phone,
              visible: _contactLinkVisible(profile, 'phone'),
              onSubmitted: save,
              onVisibilityChanged: (visible) => _toggleContactLink(
                context,
                profile: profile,
                type: 'phone',
                label: 'Llamar',
                value: phone.text,
                visible: visible,
              ),
            ),
            const SizedBox(height: 12),
            _ContactFieldCard(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor:
                  _brandColorForLinkType('whatsapp') ?? TaploeColors.blue,
              faIcon: FontAwesomeIcons.whatsapp,
              title: 'WhatsApp',
              helper: 'Chat directo con mensaje listo',
              controller: whatsapp,
              hint: '+52 664 765 4321',
              keyboardType: TextInputType.phone,
              visible: _contactLinkVisible(profile, 'whatsapp'),
              onSubmitted: save,
              onVisibilityChanged: (visible) => _toggleContactLink(
                context,
                profile: profile,
                type: 'whatsapp',
                label: 'Enviar WhatsApp',
                value: whatsapp.text,
                visible: visible,
              ),
            ),
            const SizedBox(height: 12),
            _ContactFieldCard(
              icon: Icons.public_rounded,
              iconColor: TaploeColors.blue,
              title: 'Sitio web',
              helper: 'Tu página o sitio oficial',
              controller: website,
              hint: 'https://taploe.com',
              keyboardType: TextInputType.url,
              visible: _contactLinkVisible(profile, 'website'),
              onSubmitted: save,
              onVisibilityChanged: (visible) => _toggleContactLink(
                context,
                profile: profile,
                type: 'website',
                label: 'Visitar sitio web',
                value: website.text,
                visible: visible,
              ),
            ),
            const SizedBox(height: 12),
            _ContactFieldCard(
              icon: Icons.location_on_outlined,
              iconColor: TaploeColors.warning,
              title: 'Dirección',
              helper: 'Dirección de tu negocio',
              controller: address1,
              hint: 'Av. Paseo de los Héroes 123',
              visible: _contactLinkVisible(profile, 'maps'),
              onSubmitted: save,
              onVisibilityChanged: (visible) => _toggleContactLink(
                context,
                profile: profile,
                type: 'maps',
                label: 'Cómo llegar',
                value: [
                  address1.text,
                  city.text,
                  region.text,
                  country.text,
                ].where((part) => part.trim().isNotEmpty).join(', '),
                visible: visible,
              ),
            ),
            const SizedBox(height: 12),
            _ResponsivePair(
              left: _ContactFieldCard(
                icon: Icons.apartment_rounded,
                iconColor: TaploeColors.blue,
                title: 'Ciudad',
                helper: 'Ciudad o localidad',
                controller: city,
                hint: 'Tijuana',
                compact: true,
                onSubmitted: save,
              ),
              right: _ContactFieldCard(
                icon: Icons.map_outlined,
                iconColor: TaploeColors.blue,
                title: 'Estado',
                helper: 'Estado o provincia',
                controller: region,
                hint: 'Baja California',
                compact: true,
                onSubmitted: save,
              ),
            ),
            const SizedBox(height: 12),
            _ResponsivePair(
              left: TaploeTextField(
                label: 'Dirección línea 2',
                controller: address2,
                hint: 'Piso 4, oficina 402',
                onSubmitted: (_) => save(),
              ),
              right: TaploeTextField(
                label: 'País',
                controller: country,
                hint: 'México',
                onSubmitted: (_) => save(),
              ),
            ),
            const SizedBox(height: 12),
            _ResponsivePair(
              left: TaploeTextField(
                label: 'Código postal',
                controller: postalCode,
                hint: '22010',
                onSubmitted: (_) => save(),
              ),
              right: TaploeTextField(
                label: 'Nota de contacto',
                controller: note,
                hint: 'Horario de atención o referencia.',
                onSubmitted: (_) => save(),
              ),
            ),
            const SizedBox(height: 16),
            TaploeButton(
              label: 'Descargar vCard',
              icon: Icons.contact_page_outlined,
              kind: TaploeButtonKind.secondary,
              onPressed: () => _showVcardDialog(
                context,
                profile.copyWith(
                  displayName: displayName.text.trim().isEmpty
                      ? profile.displayName
                      : displayName.text.trim(),
                  vcard: ProfileVcardModel(
                    profileId: profile.id,
                    firstName: displayName.text.trim(),
                    organization: company.text.trim(),
                    title: jobTitle.text.trim(),
                    email: email.text.trim(),
                    mobilePhone: phone.text.trim(),
                    whatsappPhone: whatsapp.text.trim(),
                    websiteUrl: website.text.trim(),
                    addressLine1: address1.text.trim(),
                    addressLine2: address2.text.trim(),
                    city: city.text.trim(),
                    state: region.text.trim(),
                    postalCode: postalCode.text.trim(),
                    country: country.text.trim(),
                    note: note.text.trim(),
                  ),
                ),
              ),
            ),
          ],
          if (step == 2) ...[
            _PanelHeader(
              title: 'Enlaces principales',
              icon: Icons.link_rounded,
              trailing: '${profile.links.length}/$taploeMaxProfileLinks',
            ),
            const SizedBox(height: 8),
            Text(
              'Administra los enlaces que aparecerán en tu perfil. Ordena, edita y destaca los más importantes.',
              style: GoogleFonts.dmSans(color: context.muted),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TaploeButton(
                width: 210,
                label: 'Añadir enlace',
                icon: Icons.add_rounded,
                onPressed: () {
                  if (profile.links.length >= taploeMaxProfileLinks) {
                    taploeToast(
                      context,
                      'Puedes agregar hasta $taploeMaxProfileLinks enlaces por perfil.',
                      error: true,
                    );
                    return;
                  }
                  _showLinkEditorDialog(context, profile: profile);
                },
              ),
            ),
            const SizedBox(height: 12),
            if (profile.links.isEmpty)
              const SizedBox(
                width: double.infinity,
                child: TaploeEmpty(
                  title: 'Sin enlaces',
                  message:
                      'Agrega WhatsApp, sitio web, redes o enlaces comerciales.',
                  icon: Icons.link_off_rounded,
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: profile.links.length,
                buildDefaultDragHandles: false,
                // ignore: deprecated_member_use
                onReorder: (oldIndex, newIndex) async {
                  final links = [...profile.links];
                  if (newIndex > oldIndex) newIndex -= 1;
                  final moved = links.removeAt(oldIndex);
                  links.insert(newIndex, moved);
                  final reordered = [
                    for (var i = 0; i < links.length; i++)
                      _copyLink(links[i], sortOrder: i + 1),
                  ];
                  taploeState.updateActiveProfile(
                    profile.copyWith(links: reordered),
                  );
                  for (var i = 0; i < links.length; i++) {
                    await ProfileRepository.updateLink(
                      _copyLink(links[i], sortOrder: i + 1),
                    );
                  }
                  await taploeState.refreshProfiles();
                },
                itemBuilder: (context, index) {
                  final link = profile.links[index];
                  return _ProfileLinkRow(
                    key: ValueKey(link.id),
                    index: index,
                    link: link,
                    onVisibleChanged: (visible) async {
                      final updated = _copyLink(link, isVisible: visible);
                      taploeState.updateActiveProfile(
                        profile.copyWith(
                          links: profile.links
                              .map(
                                (item) => item.id == link.id ? updated : item,
                              )
                              .toList(),
                        ),
                      );
                      await ProfileRepository.updateLink(updated);
                      await taploeState.refreshProfiles();
                    },
                    onFeaturedChanged: (featured) async {
                      final updated = _copyLink(link, isFeatured: featured);
                      taploeState.updateActiveProfile(
                        profile.copyWith(
                          links: profile.links
                              .map(
                                (item) => item.id == link.id ? updated : item,
                              )
                              .toList(),
                        ),
                      );
                      await ProfileRepository.updateLink(updated);
                      await taploeState.refreshProfiles();
                    },
                    onEdit: () => _showLinkEditorDialog(
                      context,
                      profile: profile,
                      link: link,
                    ),
                    onDelete: () async {
                      taploeState.updateActiveProfile(
                        profile.copyWith(
                          links: profile.links
                              .where((item) => item.id != link.id)
                              .toList(),
                        ),
                      );
                      await ProfileRepository.deleteLink(link.id);
                      await taploeState.refreshProfiles();
                    },
                  );
                },
              ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TaploeColors.page,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TaploeColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: TaploeColors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Arrastra para reordenar. Los enlaces destacados se muestran con mayor prioridad en la vista pública.',
                      style: GoogleFonts.dmSans(
                        color: context.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (step == 3) ...[
            if (!capabilities.canUseDesign)
              _ProfileFeatureLockedPreview(
                kind: _ProfileLockedFeature.design,
                profile: profile,
              )
            else if (designLocked)
              _TeamManagedSectionLockedPanel(
                title: 'Diseño administrado por tu empresa',
                message:
                    'Tu empresa usa el mismo diseño para todos los perfiles. Solo un owner o admin puede modificarlo desde Administración.',
                actionLabel: companyLinked
                    ? companyLogoUrl?.trim().isNotEmpty == true
                          ? 'Modificar logo'
                          : 'Cargar logo'
                    : null,
                actionIcon: Icons.business_center_outlined,
                onAction: companyLinked ? onManageCompanyLogo : null,
              )
            else
              _DesignStudio(
                profile: profile,
                logo: logo,
                cover: cover,
                showVerifiedBadge: showVerifiedBadge,
                onVerifiedBadgeChanged: onVerifiedBadgeChanged,
                uploadingAsset: uploadingAsset,
                onUploadLogo: onUploadLogo,
                onManageCompanyLogo: onManageCompanyLogo,
                onUploadCover: onUploadCover,
                companyLogoUrl: companyLogoUrl,
                companyLogoManaged: companyLinked,
              ),
          ],
          if (step == 4) ...[
            if (!capabilities.canUseForms)
              _ProfileFeatureLockedPreview(
                kind: _ProfileLockedFeature.forms,
                profile: profile,
              )
            else if (formsLocked)
              const _TeamManagedSectionLockedPanel(
                title: 'Formularios administrados por tu empresa',
                message:
                    'Los formularios de este perfil se controlan desde Administración.',
              )
            else
              _CaptureFormsSection(
                forms: forms,
                onCreate: () async {
                  await _showFormEditorDialog(context, profile: profile);
                  await onChangedExtras();
                },
                onEdit: (form) async {
                  await _showFormEditorDialog(
                    context,
                    profile: profile,
                    form: form,
                  );
                  await onChangedExtras();
                },
              ),
          ],
          if (step == 5) ...[
            if (!capabilities.canUseIntegrations)
              _ProfileFeatureLockedPreview(
                kind: _ProfileLockedFeature.integrations,
                profile: profile,
              )
            else if (integrationsLocked)
              const _TeamManagedSectionLockedPanel(
                title: 'Integraciones administradas por tu empresa',
                message:
                    'Las integraciones de este perfil se controlan desde Administración.',
              )
            else
              _IntegrationsSection(
                integrations: integrations,
                onCreate: () async {
                  await _showIntegrationEditorDialog(context, profile: profile);
                  await onChangedExtras();
                },
                onEdit: (integration) async {
                  await _showIntegrationEditorDialog(
                    context,
                    profile: profile,
                    integration: integration,
                  );
                  await onChangedExtras();
                },
              ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TaploeButton(
              label: 'Guardar cambios',
              icon: Icons.save_outlined,
              iconColor: TaploeColors.blue,
              kind: TaploeButtonKind.secondary,
              onPressed: save,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactFieldCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final FaIconData? faIcon;
  final String title;
  final String helper;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool compact;
  final bool? visible;
  final ValueChanged<bool>? onVisibilityChanged;
  final VoidCallback? onSubmitted;

  const _ContactFieldCard({
    required this.icon,
    required this.iconColor,
    this.faIcon,
    required this.title,
    required this.helper,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.compact = false,
    this.visible,
    this.onVisibilityChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 520;
          final leading = Row(
            children: [
              faIcon == null
                  ? Icon(icon, color: iconColor, size: 24)
                  : FaIcon(faIcon, color: iconColor, size: 22),
              const SizedBox(width: 12),
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
                    Text(
                      helper,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: context.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final field = TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmitted?.call(),
            decoration: InputDecoration(
              hintText: taploeLocalizeNullableText(context, hint),
            ),
          );

          final visibility = visible == null
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: visible!
                            ? TaploeColors.success.withValues(alpha: .10)
                            : TaploeColors.page,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        visible! ? 'Visible' : 'Oculto',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: visible!
                              ? TaploeColors.success
                              : context.muted,
                        ),
                      ),
                    ),
                    Switch(value: visible!, onChanged: onVisibilityChanged),
                  ],
                );

          if (compact || stacked) {
            return Column(
              children: [
                leading,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: field),
                    if (visible != null) ...[
                      const SizedBox(width: 8),
                      visibility,
                    ],
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 4, child: leading),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: field),
              if (visible != null) ...[const SizedBox(width: 8), visibility],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileLinkRow extends StatelessWidget {
  final int index;
  final ProfileLinkModel link;
  final ValueChanged<bool> onVisibleChanged;
  final ValueChanged<bool> onFeaturedChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileLinkRow({
    super.key,
    required this.index,
    required this.link,
    required this.onVisibleChanged,
    required this.onFeaturedChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator_rounded),
          ),
          const SizedBox(width: 8),
          _fontAwesomeIconForLinkType(link.linkType) == null
              ? Icon(
                  _linkIcon(link.linkType),
                  color: TaploeColors.blue,
                  size: 24,
                )
              : FaIcon(
                  _fontAwesomeIconForLinkType(link.linkType),
                  color: _brandColorForLinkType(link.linkType),
                  size: 22,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  link.value ?? link.url ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(color: context.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(value: link.isVisible, onChanged: onVisibleChanged),
          IconButton(
            tooltip: link.isFeatured ? 'Quitar destacado' : 'Destacar',
            onPressed: () => onFeaturedChanged(!link.isFeatured),
            icon: Icon(
              link.isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
              color: link.isFeatured ? TaploeColors.warning : context.muted,
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LinkTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onSelected;

  const _LinkTypeSelector({
    required this.selectedType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de enlace',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: context.text,
          ),
        ),
        const SizedBox(height: 10),
        ..._linkOptions.map((option) {
          final selected = selectedType == option.type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(option.type),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected
                      ? TaploeColors.blue.withValues(alpha: .06)
                      : TaploeColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? TaploeColors.blue : TaploeColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    _LinkGlyph(type: option.type, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              color: context.text,
                            ),
                          ),
                          Text(
                            option.inputLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: context.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: TaploeColors.blue,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ignore: unused_element
class _LinkPreviewCard extends StatelessWidget {
  final _LinkTypeOption option;
  final String label;

  const _LinkPreviewCard({required this.option, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaploeColors.page,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          _LinkGlyph(type: option.type, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.trim().isEmpty ? option.label : label.trim(),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: context.text,
                  ),
                ),
                Text(
                  'Vista previa en el perfil público',
                  style: GoogleFonts.dmSans(fontSize: 12, color: context.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _LinkGlyph extends StatelessWidget {
  final String type;
  final double size;

  const _LinkGlyph({required this.type, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final text = _brandGlyph(type);
    if (text != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: size * .72,
              height: 1,
              fontWeight: FontWeight.w600,
              color: _linkBrandColor(type),
            ),
          ),
        ),
      );
    }
    return Icon(_linkIcon(type), color: _linkBrandColor(type), size: size);
  }
}

class _TeamManagedSectionLockedPanel extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _TeamManagedSectionLockedPanel({
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded, color: TaploeColors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: context.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.dmSans(
              color: context.muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            TaploeButton(
              width: 190,
              label: actionLabel!,
              icon: actionIcon ?? Icons.arrow_forward_rounded,
              kind: TaploeButtonKind.secondary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

enum _ProfileLockedFeature { design, forms, integrations }

class _ProfileFeatureLockedPreview extends StatelessWidget {
  final _ProfileLockedFeature kind;
  final DigitalProfileModel profile;

  const _ProfileFeatureLockedPreview({
    required this.kind,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      _ProfileLockedFeature.design => 'Diseño personalizado',
      _ProfileLockedFeature.forms => 'Formularios',
      _ProfileLockedFeature.integrations => 'Integraciones',
    };
    final message = switch (kind) {
      _ProfileLockedFeature.design =>
        'Personaliza logo, portada, colores, estilos y apariencia pública con Premium o Empresa.',
      _ProfileLockedFeature.forms =>
        'Crea formularios de contacto, cotización o agenda para capturar leads con Premium o Empresa.',
      _ProfileLockedFeature.integrations =>
        'Conecta calendario, servicios externos y herramientas comerciales con Premium o Empresa.',
    };
    final icon = switch (kind) {
      _ProfileLockedFeature.design => Icons.palette_outlined,
      _ProfileLockedFeature.forms => Icons.dynamic_form_outlined,
      _ProfileLockedFeature.integrations => Icons.hub_outlined,
    };
    final preview = switch (kind) {
      _ProfileLockedFeature.design => const _MockDesignPreview(),
      _ProfileLockedFeature.forms => const _MockFormsPreview(),
      _ProfileLockedFeature.integrations => const _MockIntegrationsPreview(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LockedPreviewPanel(title: title, child: preview),
        const SizedBox(height: 16),
        _PlanFeatureLockedPanel(
          title: title,
          message: message,
          requiredPlan: 'Premium',
          icon: icon,
        ),
      ],
    );
  }
}

class _MockDesignPreview extends StatelessWidget {
  const _MockDesignPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _MockDesignSettingRow(
          icon: Icons.palette_outlined,
          title: 'Paleta de marca',
          value: 'Azul principal',
          swatches: [TaploeColors.blue, Color(0xFFF59E0B), Color(0xFFF7F8FB)],
        ),
        SizedBox(height: 10),
        _MockDesignSettingRow(
          icon: Icons.image_outlined,
          title: 'Portada pública',
          value: 'Imagen corporativa',
        ),
        SizedBox(height: 10),
        _MockDesignSettingRow(
          icon: Icons.smart_button_outlined,
          title: 'Estilo de botones',
          value: 'Redondeado',
        ),
        SizedBox(height: 10),
        _MockDesignSettingRow(
          icon: Icons.verified_outlined,
          title: 'Insignia y marca',
          value: 'Taploe visible',
        ),
      ],
    );
  }
}

class _MockDesignSettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final List<Color> swatches;

  const _MockDesignSettingRow({
    required this.icon,
    required this.title,
    required this.value,
    this.swatches = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: TaploeColors.blue.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: TaploeColors.blue, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mockMuted(context),
                ),
              ],
            ),
          ),
          if (swatches.isNotEmpty) ...[
            const SizedBox(width: 8),
            for (final color in swatches)
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(left: 5),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: TaploeColors.border),
                ),
              ),
          ],
          const SizedBox(width: 8),
          const Icon(
            Icons.lock_outline_rounded,
            color: TaploeColors.muted,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _MockFormsPreview extends StatelessWidget {
  const _MockFormsPreview();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 300),
      child: Column(
        children: [
          const _SimpleStatGrid(
            items: [
              ('Formularios', '3', Icons.dynamic_form_outlined),
              ('Activos', '2', Icons.toggle_on_outlined),
              ('Envíos', '128', Icons.inbox_outlined),
              ('Conversión', '18%', Icons.trending_up_rounded),
            ],
          ),
          const SizedBox(height: 14),
          const _CompactMockList(
            rows: [
              ('CT', 'Contacto rápido', 'Activo', '87 envíos'),
              ('CO', 'Cotización', 'Activo', '31 envíos'),
              ('AG', 'Agenda', 'Pausado', '10 envíos'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockIntegrationsPreview extends StatelessWidget {
  const _MockIntegrationsPreview();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 300),
      child: Column(
        children: [
          const _SimpleStatGrid(
            items: [
              ('Calendario', 'Activo', Icons.calendar_month_outlined),
              ('CRM', 'Listo', Icons.hub_outlined),
              ('Webhook', '2', Icons.webhook_outlined),
              ('Email', 'Activo', Icons.mail_outline_rounded),
            ],
          ),
          const SizedBox(height: 14),
          const _CompactMockList(
            rows: [
              ('GC', 'Google Calendar', 'Activa', 'Calendario'),
              ('HS', 'HubSpot', 'Activa', 'CRM'),
              ('ZP', 'Zapier', 'Pausada', 'Webhook'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMockList extends StatelessWidget {
  final List<(String, String, String, String)> rows;

  const _CompactMockList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: TaploeColors.border),
                      ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: TaploeColors.blue.withValues(alpha: .12),
                    child: Text(
                      rows[i].$1,
                      style: GoogleFonts.dmSans(
                        color: TaploeColors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: context.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 82),
                    child: Text(
                      rows[i].$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: _mockMuted(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 78),
                    child: Text(
                      rows[i].$4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: _mockMuted(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: TaploeColors.muted,
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanFeatureLockedPanel extends StatelessWidget {
  final String title;
  final String message;
  final String requiredPlan;
  final IconData icon;

  const _PlanFeatureLockedPanel({
    required this.title,
    required this.message,
    required this.requiredPlan,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, color: TaploeColors.blue, size: 34)),
                const Positioned(
                  right: 0,
                  top: 0,
                  child: FaIcon(
                    FontAwesomeIcons.crown,
                    color: Color(0xFFF5C84C),
                    size: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: context.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _PremiumMiniBadge(label: requiredPlan),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TaploeButton(
                      width: 210,
                      label: 'Elegir plan ideal',
                      icon: Icons.workspace_premium_rounded,
                      onPressed: () => _showPlansDialog(context),
                    ),
                    TaploeButton(
                      width: 150,
                      label: 'Ver planes',
                      icon: Icons.arrow_forward_rounded,
                      kind: TaploeButtonKind.secondary,
                      onPressed: () => _showPlansDialog(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMiniBadge extends StatelessWidget {
  final String label;

  const _PremiumMiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        border: Border.all(color: TaploeColors.blue),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(
            FontAwesomeIcons.crown,
            color: Color(0xFFF5C84C),
            size: 10,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: TaploeColors.blue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignStudio extends StatelessWidget {
  final DigitalProfileModel profile;
  final TextEditingController logo;
  final TextEditingController cover;
  final bool showVerifiedBadge;
  final ValueChanged<bool> onVerifiedBadgeChanged;
  final String? uploadingAsset;
  final VoidCallback onUploadLogo;
  final VoidCallback? onManageCompanyLogo;
  final VoidCallback onUploadCover;
  final String? companyLogoUrl;
  final bool companyLogoManaged;
  final Future<void> Function(ProfileThemeModel theme)? onThemeChanged;
  final String title;
  final String description;
  final bool showIdentityControls;
  final bool showPreviewButton;
  final bool showVerifiedControl;

  const _DesignStudio({
    required this.profile,
    required this.logo,
    required this.cover,
    required this.showVerifiedBadge,
    required this.onVerifiedBadgeChanged,
    required this.uploadingAsset,
    required this.onUploadLogo,
    this.onManageCompanyLogo,
    required this.onUploadCover,
    this.companyLogoUrl,
    this.companyLogoManaged = false,
    this.onThemeChanged,
    this.title = 'Diseño de tu perfil',
    this.description =
        'Elige un estilo profesional y personaliza tu perfil en segundos.',
    this.showIdentityControls = true,
    this.showPreviewButton = true,
    this.showVerifiedControl = true,
  });

  Future<void> _saveTheme(
    DigitalProfileModel profile,
    ProfileThemeModel theme,
  ) async {
    final handler = onThemeChanged;
    if (handler != null) {
      await handler(theme);
      return;
    }
    await _saveThemeQuick(profile, theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = profile.theme ?? ProfileThemeModel(profileId: profile.id);
    final presets = _designPresets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.palette_outlined,
              color: TaploeColors.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  color: context.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => taploeToast(
                context,
                'Usa colores con contraste alto y una portada limpia.',
              ),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
              label: const Text('Consejos de diseño'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(description, style: GoogleFonts.dmSans(color: context.muted)),
        if (showIdentityControls) ...[
          const SizedBox(height: 18),
          const _DesignSectionTitle('Identidad visual'),
          const SizedBox(height: 14),
          if (companyLogoManaged) ...[
            _CompanyManagedLogoCard(
              logoUrl: companyLogoUrl,
              loading: uploadingAsset == 'company-logo',
              onPressed: onManageCompanyLogo,
            ),
            const SizedBox(height: 14),
            _ProfileAssetPicker(
              label: 'Portada',
              value: cover.text,
              icon: Icons.image_outlined,
              loading: uploadingAsset == 'cover',
              onTap: onUploadCover,
              wide: true,
            ),
          ] else
            _ResponsivePair(
              left: _ProfileAssetPicker(
                label: 'Logo',
                value: logo.text,
                icon: Icons.workspace_premium_outlined,
                loading: uploadingAsset == 'logo',
                onTap: onUploadLogo,
                fallback: const TaploeLogo(size: 24),
                wide: true,
              ),
              right: _ProfileAssetPicker(
                label: 'Portada',
                value: cover.text,
                icon: Icons.image_outlined,
                loading: uploadingAsset == 'cover',
                onTap: onUploadCover,
                wide: true,
              ),
            ),
          const SizedBox(height: 14),
          _LogoLayoutControls(
            theme: theme,
            onPreviewChanged: (next) {
              taploeState.updateActiveProfile(profile.copyWith(theme: next));
            },
            onSave: (next) => _saveTheme(profile, next),
          ),
          if (showVerifiedControl) ...[
            const SizedBox(height: 22),
            _VerifiedBadgeToggleCard(
              value: showVerifiedBadge,
              onChanged: onVerifiedBadgeChanged,
            ),
          ],
        ],
        const SizedBox(height: 22),
        const _DesignSectionTitle('Estilos rápidos'),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: presets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.isWide ? 5 : 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 170,
          ),
          itemBuilder: (context, index) {
            final preset = presets[index];
            return _DesignPresetCard(
              preset: preset,
              selected: preset.matches(theme),
              onTap: () => _saveTheme(profile, preset.toTheme(theme)),
            );
          },
        ),
        const SizedBox(height: 22),
        const _DesignSectionTitle('Personaliza tu diseño'),
        const SizedBox(height: 14),
        _ResponsivePair(
          left: _ColorSwatches(
            title: 'Color principal',
            selected: theme.primaryColor,
            colors: const [
              '#2458FF',
              '#10B981',
              '#7C3AED',
              '#F43F5E',
              '#F97316',
              '#050505',
            ],
            onChanged: (value) =>
                _saveTheme(profile, theme.copyWithPrimary(value)),
          ),
          right: _ColorSwatches(
            title: 'Color de acento',
            selected: theme.accentColor,
            colors: const [
              '#2458FF',
              '#10B981',
              '#7C3AED',
              '#F43F5E',
              '#F97316',
              '#050505',
            ],
            onChanged: (value) =>
                _saveTheme(profile, theme.copyWithAccent(value)),
          ),
        ),
        const SizedBox(height: 12),
        _DesignOptionsGrid(
          children: [
            _SegmentControl(
              title: 'Estilo de botones',
              value: theme.buttonStyle,
              options: const ['pill', 'rounded', 'square'],
              labels: const ['Redondeado', 'Suave', 'Cuadrado'],
              onChanged: (value) =>
                  _saveTheme(profile, theme.copyWithButtonStyle(value)),
            ),
            _SegmentControl(
              title: 'Tipografía',
              value: theme.fontFamily,
              options: const ['system', 'poppins', 'montserrat'],
              labels: const ['Inter', 'Poppins', 'Montserrat'],
              onChanged: (value) =>
                  _saveTheme(profile, theme.copyWithFontFamily(value)),
            ),
            _SegmentControl(
              title: 'Fondo',
              value: _backgroundMode(theme),
              options: const ['light', 'dark'],
              labels: const ['Claro', 'Oscuro'],
              onChanged: (value) =>
                  _saveTheme(profile, theme.copyWithBackgroundMode(value)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ColorSwatches(
          title: 'Fondo y portada sin imagen',
          selected: theme.backgroundColorStart,
          colors: const [
            '#FFFFFF',
            '#F8FAFC',
            '#EEF2FF',
            '#ECFDF5',
            '#FFF7ED',
            '#050505',
          ],
          onChanged: (value) =>
              _saveTheme(profile, theme.copyWithBackgroundColor(value)),
        ),
        if (showPreviewButton) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              TaploeButton(
                width: 190,
                label: 'Vista previa completa',
                icon: Icons.visibility_outlined,
                kind: TaploeButtonKind.secondary,
                onPressed: () {
                  final uri = Uri.tryParse(
                    TaploeConfig.profileUrl(profile.publicSlug),
                  );
                  if (uri != null) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DesignSectionTitle extends StatelessWidget {
  final String text;

  const _DesignSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          color: TaploeColors.blue,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.outfit(
            color: context.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LogoLayoutControls extends StatefulWidget {
  final ProfileThemeModel theme;
  final ValueChanged<ProfileThemeModel> onPreviewChanged;
  final Future<void> Function(ProfileThemeModel theme) onSave;

  const _LogoLayoutControls({
    required this.theme,
    required this.onPreviewChanged,
    required this.onSave,
  });

  @override
  State<_LogoLayoutControls> createState() => _LogoLayoutControlsState();
}

class _LogoLayoutControlsState extends State<_LogoLayoutControls> {
  late ProfileThemeModel _theme;
  Timer? _saveDebounce;
  Object? _lastSaveError;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme;
  }

  @override
  void didUpdateWidget(covariant _LogoLayoutControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme && _saveDebounce == null) {
      _theme = widget.theme;
    }
  }

  @override
  void dispose() {
    final pending = _saveDebounce != null;
    _saveDebounce?.cancel();
    if (pending) unawaited(widget.onSave(_theme));
    super.dispose();
  }

  void _update(ProfileThemeModel next) {
    setState(() {
      _theme = next;
      _lastSaveError = null;
    });
    widget.onPreviewChanged(next);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 550), () async {
      _saveDebounce = null;
      try {
        await widget.onSave(next);
      } catch (error) {
        safePrintError(error);
        if (!mounted) return;
        setState(() => _lastSaveError = error);
        taploeToast(
          context,
          'No pudimos guardar el ajuste del logo. Revisa que el SQL de diseño esté aplicado.',
          error: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final logoSize = theme.logoSize.clamp(0.7, 1.8).toDouble();
    final offsetRange = _logoOffsetRangeForSize(logoSize);
    final logoOffset = theme.logoVerticalOffset
        .clamp(offsetRange.$1, offsetRange.$2)
        .toDouble();
    final offsetSpan = (offsetRange.$2 - offsetRange.$1).abs();
    final offsetDivisions = math.max(1, (offsetSpan / 4).round());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: TaploeColors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Ajuste del logo',
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LogoSlider(
            icon: Icons.photo_size_select_large_rounded,
            label: 'Tamaño',
            value: logoSize,
            min: 0.7,
            max: 1.8,
            divisions: 11,
            valueLabel: '${(logoSize * 100).round()}%',
            onChanged: (value) {
              final nextOffset = _clampLogoOffsetForSize(
                value,
                theme.logoVerticalOffset,
              );
              _update(
                theme
                    .copyWithLogoSize(value)
                    .copyWithLogoVerticalOffset(nextOffset),
              );
            },
          ),
          const SizedBox(height: 12),
          _LogoSlider(
            icon: Icons.swap_vert_rounded,
            label: 'Posición',
            value: logoOffset,
            min: offsetRange.$1,
            max: offsetRange.$2,
            divisions: offsetDivisions,
            valueLabel: _logoOffsetLabel(logoOffset),
            onChanged: (value) =>
                _update(theme.copyWithLogoVerticalOffset(value)),
          ),
          if (_lastSaveError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Pendiente de guardar',
              style: GoogleFonts.dmSans(
                color: TaploeColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _LogoSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.muted, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: context.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: TaploeColors.blue,
            inactiveColor: TaploeColors.border,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 92,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

const double _logoEditorBaseTop = 52;
const double _logoEditorAvatarTop = 122;
const double _logoEditorMinTop = 22;
const double _logoEditorAvatarGap = 10;
const double _logoEditorBaseHeight = 44;

(double, double) _logoOffsetRangeForSize(double logoSize) {
  final logoHeight = _logoEditorBaseHeight * logoSize.clamp(0.7, 1.8);
  final minOffset = _logoEditorMinTop - _logoEditorBaseTop;
  final maxTop = _logoEditorAvatarTop - logoHeight - _logoEditorAvatarGap;
  final maxOffset = math.max(minOffset, maxTop - _logoEditorBaseTop);
  return (minOffset, maxOffset);
}

double _clampLogoOffsetForSize(double logoSize, double offset) {
  final range = _logoOffsetRangeForSize(logoSize);
  return offset.clamp(range.$1, range.$2).toDouble();
}

String _logoOffsetLabel(double value) {
  final rounded = value.round();
  if (rounded == 0) return 'Centro';
  if (rounded < 0) return '${rounded.abs()} px arriba';
  return '$rounded px abajo';
}

class _DesignPresetCard extends StatelessWidget {
  final _DesignPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _DesignPresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TaploeColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? TaploeColors.blue : TaploeColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DesignPresetPreview(preset: preset, selected: selected),
            ),
            const SizedBox(height: 8),
            Text(
              preset.label,
              style: GoogleFonts.dmSans(
                color: context.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              preset.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(color: context.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignOptionsGrid extends StatelessWidget {
  final List<Widget> children;

  const _DesignOptionsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        const gap = 12.0;
        final itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _DesignPresetPreview extends StatelessWidget {
  final _DesignPreset preset;
  final bool selected;

  const _DesignPresetPreview({required this.preset, required this.selected});

  @override
  Widget build(BuildContext context) {
    final primary = _colorFromHex(
      preset.primaryColor,
      fallback: TaploeColors.blue,
    );
    final accent = _colorFromHex(preset.accentColor, fallback: primary);
    final start = _colorFromHex(
      preset.backgroundStart,
      fallback: TaploeColors.white,
    );
    final end = _colorFromHex(
      preset.backgroundEnd ?? preset.backgroundStart,
      fallback: start,
    );
    final dark = preset.themeStyle == 'dark' || preset.label == 'Premium';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: preset.backgroundType == 'gradient'
            ? LinearGradient(
                colors: [start, end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: preset.backgroundType == 'gradient' ? null : start,
        border: Border.all(color: TaploeColors.border),
      ),
      child: Stack(
        children: [
          if (preset.label == 'Premium')
            Positioned.fill(
              child: CustomPaint(painter: _PremiumLinesPainter()),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: primary.withValues(alpha: dark ? .22 : .14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 72,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dark
                        ? TaploeColors.white.withValues(alpha: .32)
                        : primary.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dark
                            ? TaploeColors.white.withValues(alpha: .28)
                            : TaploeColors.borderStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (selected)
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.check_circle_rounded,
                color: TaploeColors.blue,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TaploeColors.warning.withValues(alpha: .72)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(4, size.height - 18),
      Offset(size.width - 4, 16),
      paint,
    );
    canvas.drawLine(
      Offset(24, size.height - 4),
      Offset(size.width - 22, 28),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DesignPreset {
  final String label;
  final String subtitle;
  final String themeStyle;
  final String primaryColor;
  final String accentColor;
  final String backgroundType;
  final String backgroundStart;
  final String? backgroundEnd;
  final String buttonStyle;
  final String fontFamily;

  const _DesignPreset({
    required this.label,
    required this.subtitle,
    required this.themeStyle,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundType,
    required this.backgroundStart,
    this.backgroundEnd,
    required this.buttonStyle,
    required this.fontFamily,
  });

  bool matches(ProfileThemeModel theme) {
    return theme.themeStyle == themeStyle &&
        theme.primaryColor.toUpperCase() == primaryColor.toUpperCase() &&
        theme.backgroundType == backgroundType &&
        theme.backgroundColorStart.toUpperCase() ==
            backgroundStart.toUpperCase();
  }

  ProfileThemeModel toTheme(ProfileThemeModel current) => ProfileThemeModel(
    id: current.id,
    profileId: current.profileId,
    themeStyle: themeStyle,
    layoutStyle: current.layoutStyle,
    primaryColor: primaryColor,
    secondaryColor: '#FFFFFF',
    accentColor: accentColor,
    backgroundType: backgroundType,
    backgroundColorStart: backgroundStart,
    backgroundColorEnd: backgroundEnd,
    backgroundImageUrl: current.backgroundImageUrl,
    buttonStyle: buttonStyle,
    fontFamily: fontFamily,
    logoSize: current.logoSize,
    logoVerticalOffset: current.logoVerticalOffset,
  );
}

const _designPresets = [
  _DesignPreset(
    label: 'Clara',
    subtitle: 'Limpia y profesional',
    themeStyle: 'light',
    primaryColor: '#2458FF',
    accentColor: '#2458FF',
    backgroundType: 'solid',
    backgroundStart: '#FFFFFF',
    buttonStyle: 'pill',
    fontFamily: 'system',
  ),
  _DesignPreset(
    label: 'Oscura',
    subtitle: 'Moderna y sofisticada',
    themeStyle: 'dark',
    primaryColor: '#050505',
    accentColor: '#2458FF',
    backgroundType: 'solid',
    backgroundStart: '#050505',
    buttonStyle: 'rounded',
    fontFamily: 'system',
  ),
  _DesignPreset(
    label: 'Azul',
    subtitle: 'Fresca y corporativa',
    themeStyle: 'brand',
    primaryColor: '#2458FF',
    accentColor: '#FFFFFF',
    backgroundType: 'solid',
    backgroundStart: '#2458FF',
    buttonStyle: 'pill',
    fontFamily: 'system',
  ),
  _DesignPreset(
    label: 'Gradient',
    subtitle: 'Llamativa y moderna',
    themeStyle: 'custom',
    primaryColor: '#2458FF',
    accentColor: '#F43F5E',
    backgroundType: 'gradient',
    backgroundStart: '#2458FF',
    backgroundEnd: '#A855F7',
    buttonStyle: 'pill',
    fontFamily: 'poppins',
  ),
  _DesignPreset(
    label: 'Premium',
    subtitle: 'Elegante y exclusiva',
    themeStyle: 'custom',
    primaryColor: '#050505',
    accentColor: '#F59E0B',
    backgroundType: 'solid',
    backgroundStart: '#111111',
    buttonStyle: 'rounded',
    fontFamily: 'montserrat',
  ),
];

String _backgroundMode(ProfileThemeModel theme) {
  if (theme.backgroundType == 'gradient' || theme.backgroundImageUrl != null) {
    return 'custom';
  }
  if (theme.backgroundColorStart.toUpperCase() == '#050505' ||
      theme.backgroundColorStart.toUpperCase() == '#111111') {
    return 'dark';
  }
  return 'light';
}

class _FormSummaryCard extends StatelessWidget {
  final SmartFormModel form;
  final VoidCallback onTap;

  const _FormSummaryCard({required this.form, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ActionCard(
      title: form.name,
      subtitle:
          '${form.description ?? form.formKey} · ${form.notifyEmails.length} notificaciones',
      icon: form.isActive
          ? Icons.check_circle_outline_rounded
          : Icons.pause_circle_outline_rounded,
      onTap: onTap,
    );
  }
}

class _CaptureFormsSection extends StatelessWidget {
  final List<SmartFormModel> forms;
  final VoidCallback onCreate;
  final ValueChanged<SmartFormModel> onEdit;

  const _CaptureFormsSection({
    required this.forms,
    required this.onCreate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = forms.where((form) => form.isActive).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Formularios de captura',
          style: GoogleFonts.outfit(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: context.text,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Crea y gestiona formularios para capturar prospectos desde tu perfil.',
          style: GoogleFonts.dmSans(color: context.muted),
        ),
        const SizedBox(height: 34),
        LayoutBuilder(
          builder: (context, constraints) {
            final metrics = [
              _CaptureFormMetric(
                icon: Icons.dynamic_form_outlined,
                value: '${forms.length}',
                label: 'Formularios',
              ),
              _CaptureFormMetric(
                icon: Icons.check_circle_outline_rounded,
                value: '$activeCount',
                label: 'Activos',
              ),
            ];
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 28, runSpacing: 20, children: metrics),
                  const SizedBox(height: 22),
                  TaploeButton(
                    label: 'Crear formulario',
                    icon: Icons.add_rounded,
                    onPressed: onCreate,
                    expanded: true,
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      Expanded(child: metrics[i]),
                      if (i != metrics.length - 1) const SizedBox(width: 34),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                TaploeButton(
                  label: 'Crear formulario',
                  icon: Icons.add_rounded,
                  onPressed: onCreate,
                  expanded: true,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        Divider(color: TaploeColors.border),
        const SizedBox(height: 36),
        if (forms.isEmpty)
          const _CaptureFormsEmpty()
        else
          ...forms.map(
            (form) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FormSummaryCard(form: form, onTap: () => onEdit(form)),
            ),
          ),
      ],
    );
  }
}

class _AdminCompactFormsSection extends StatelessWidget {
  final List<SmartFormModel> forms;
  final VoidCallback onCreate;
  final ValueChanged<SmartFormModel> onEdit;

  const _AdminCompactFormsSection({
    required this.forms,
    required this.onCreate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = forms.where((form) => form.isActive).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminCompactEditorHeader(
          title: 'Formulario para el equipo',
          subtitle:
              '$activeCount activos de ${forms.length}. Se mostrará en los perfiles administrados.',
          actionLabel: 'Crear formulario',
          actionIcon: Icons.add_rounded,
          onAction: onCreate,
        ),
        const SizedBox(height: 12),
        if (forms.isEmpty)
          const _AdminEmptyLine(
            icon: Icons.dynamic_form_outlined,
            text: 'Aún no hay formulario compartido.',
          )
        else
          ...forms.map(
            (form) => _AdminManagedListRow(
              title: form.name,
              subtitle: form.description ?? form.formKey,
              icon: form.isActive
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              onTap: () => onEdit(form),
            ),
          ),
      ],
    );
  }
}

class _CaptureFormMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CaptureFormMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TaploeColors.blue, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: context.text,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureFormsEmpty extends StatelessWidget {
  const _CaptureFormsEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          const Icon(
            Icons.dynamic_form_outlined,
            color: TaploeColors.blue,
            size: 30,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin formularios',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: context.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea un formulario de contacto, cotización o agenda para capturar leads.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.muted),
          ),
        ],
      ),
    );
  }
}

class _IntegrationsSection extends StatelessWidget {
  final List<ProfileIntegrationModel> integrations;
  final VoidCallback onCreate;
  final ValueChanged<ProfileIntegrationModel> onEdit;

  const _IntegrationsSection({
    required this.integrations,
    required this.onCreate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = integrations
        .where((integration) => integration.isEnabled)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Integraciones',
          style: GoogleFonts.outfit(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: context.text,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Conecta herramientas externas a tu perfil.',
          style: GoogleFonts.dmSans(color: context.muted),
        ),
        const SizedBox(height: 34),
        Row(
          children: [
            Expanded(
              child: _CaptureFormMetric(
                icon: Icons.add_link_rounded,
                value: '${integrations.length}',
                label: 'Integraciones',
              ),
            ),
            const SizedBox(width: 34),
            Expanded(
              child: _CaptureFormMetric(
                icon: Icons.check_circle_outline_rounded,
                value: '$activeCount',
                label: 'Activas',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TaploeButton(
          label: 'Agregar integración',
          icon: Icons.add_link_rounded,
          onPressed: onCreate,
          expanded: true,
        ),
        const SizedBox(height: 32),
        Divider(color: TaploeColors.border),
        const SizedBox(height: 36),
        if (integrations.isEmpty)
          const _IntegrationsEmpty()
        else
          ...integrations.map(
            (integration) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IntegrationRow(
                integration: integration,
                onTap: () => onEdit(integration),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminCompactIntegrationsSection extends StatelessWidget {
  final List<ProfileIntegrationModel> integrations;
  final VoidCallback onCreate;
  final ValueChanged<ProfileIntegrationModel> onEdit;

  const _AdminCompactIntegrationsSection({
    required this.integrations,
    required this.onCreate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = integrations
        .where((integration) => integration.isEnabled)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminCompactEditorHeader(
          title: 'Integraciones para el equipo',
          subtitle:
              '$activeCount activas de ${integrations.length}. Se usarán en los perfiles administrados.',
          actionLabel: 'Agregar integración',
          actionIcon: Icons.add_link_rounded,
          onAction: onCreate,
        ),
        const SizedBox(height: 12),
        if (integrations.isEmpty)
          const _AdminEmptyLine(
            icon: Icons.add_link_rounded,
            text: 'Aún no hay integración compartida.',
          )
        else
          ...integrations.map(
            (integration) => _AdminManagedListRow(
              title:
                  integration.displayLabel ??
                  integration.integration?.provider ??
                  'Integración',
              subtitle:
                  '${integration.integration?.integrationType ?? 'other'} · ${integration.integration?.publicUrl ?? ''}',
              icon: integration.isEnabled
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              onTap: () => onEdit(integration),
            ),
          ),
      ],
    );
  }
}

class _AdminCompactEditorHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _AdminCompactEditorHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 420;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                color: context.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(color: context.muted, height: 1.3),
            ),
          ],
        );
        final button = TaploeButton(
          width: stacked ? null : 220,
          expanded: stacked,
          label: actionLabel,
          icon: actionIcon,
          kind: TaploeButtonKind.secondary,
          onPressed: onAction,
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [text, const SizedBox(height: 12), button],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }
}

class _AdminEmptyLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AdminEmptyLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: context.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminManagedListRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminManagedListRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: TaploeColors.blue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, color: context.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _IntegrationsEmpty extends StatelessWidget {
  const _IntegrationsEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          const Icon(
            Icons.add_link_rounded,
            color: TaploeColors.blue,
            size: 30,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin integraciones',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: context.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega calendario, CRM o servicios externos.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.muted),
          ),
        ],
      ),
    );
  }
}

class _IntegrationRow extends StatelessWidget {
  final ProfileIntegrationModel integration;
  final VoidCallback onTap;

  const _IntegrationRow({required this.integration, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ActionCard(
      title:
          integration.displayLabel ??
          integration.integration?.provider ??
          'Integración',
      subtitle:
          '${integration.integration?.integrationType ?? 'other'} · ${integration.integration?.publicUrl ?? ''}',
      icon: integration.isEnabled
          ? Icons.check_circle_outline_rounded
          : Icons.pause_circle_outline_rounded,
      onTap: onTap,
    );
  }
}

class _SegmentControl extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  const _SegmentControl({
    required this.title,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.text,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(options[i]),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: value == options[i]
                          ? TaploeColors.blue.withValues(alpha: .08)
                          : TaploeColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: value == options[i]
                            ? TaploeColors.blue
                            : TaploeColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (value == options[i]) ...[
                          const Icon(
                            Icons.check_rounded,
                            color: TaploeColors.blue,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          labels[i],
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: value == options[i]
                                ? TaploeColors.blue
                                : context.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  final String title;
  final String selected;
  final List<String> colors;
  final ValueChanged<String> onChanged;

  const _ColorSwatches({
    required this.title,
    required this.selected,
    required this.colors,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => _ColorPickerDialog(title: title, initial: selected),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = _colorFromHex(selected, fallback: TaploeColors.blue);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
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
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openPicker(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TaploeColors.page,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TaploeColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TaploeColors.border),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        color: context.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.tune_rounded,
                    color: TaploeColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in colors)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(color),
                  child: Container(
                    width: 30,
                    height: 30,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected == color
                            ? TaploeColors.blue
                            : TaploeColors.border,
                        width: selected == color ? 2 : 1,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _colorFromHex(
                          color,
                          fallback: TaploeColors.blue,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: selected == color
                          ? const Icon(
                              Icons.check_rounded,
                              color: TaploeColors.white,
                              size: 15,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final String title;
  final String initial;

  const _ColorPickerDialog({required this.title, required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor hsv;
  late TextEditingController hexController;

  Color get color => hsv.toColor();

  @override
  void initState() {
    super.initState();
    final initialColor = _colorFromHex(
      widget.initial,
      fallback: TaploeColors.blue,
    );
    hsv = HSVColor.fromColor(initialColor);
    hexController = TextEditingController(text: _hexFromColor(initialColor));
  }

  @override
  void dispose() {
    hexController.dispose();
    super.dispose();
  }

  void _setColor(Color value) {
    setState(() {
      hsv = HSVColor.fromColor(value);
      hexController.text = _hexFromColor(value);
    });
  }

  void _setHsv(HSVColor value) {
    setState(() {
      hsv = value;
      hexController.text = _hexFromColor(value.toColor());
    });
  }

  void _applyHex() {
    final parsed = _colorFromHex(hexController.text, fallback: color);
    _setColor(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final hex = _hexFromColor(color);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: TaploeColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TaploeColors.border),
            boxShadow: [
              BoxShadow(
                color: TaploeColors.black.withValues(alpha: .16),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SaturationValuePicker(hsv: hsv, onChanged: _setHsv),
              const SizedBox(height: 16),
              _HuePicker(hsv: hsv, onChanged: _setHsv),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hexController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _applyHex(),
                      decoration: InputDecoration(
                        hintText: '#2596BE',
                        filled: true,
                        fillColor: TaploeColors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: TaploeColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: TaploeColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: TaploeColors.blue,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: GoogleFonts.dmSans(
                        color: context.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TaploeColors.border),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Copiar color',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hex));
                    taploeToast(context, 'Color copiado.');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  color: context.text,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  TaploeButton(
                    width: 150,
                    label: 'Aplicar',
                    icon: Icons.check_rounded,
                    onPressed: () {
                      _applyHex();
                      Navigator.pop(context, _hexFromColor(color));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaturationValuePicker extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  const _SaturationValuePicker({required this.hsv, required this.onChanged});

  void _update(Offset localPosition, Size size) {
    final saturation = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - localPosition.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(saturation).withValue(value));
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final left = hsv.saturation * size.width;
          final top = (1 - hsv.value) * size.height;
          return GestureDetector(
            onTapDown: (details) => _update(details.localPosition, size),
            onPanUpdate: (details) => _update(details.localPosition, size),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _SaturationValuePainter(hsv)),
                  ),
                  Positioned(
                    left: left - 14,
                    top: top - 14,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hsv.toColor(),
                        border: Border.all(color: TaploeColors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: TaploeColors.black.withValues(alpha: .26),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HuePicker extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  const _HuePicker({required this.hsv, required this.onChanged});

  void _update(Offset localPosition, double width) {
    final hue = (localPosition.dx / width).clamp(0.0, 1.0) * 360;
    onChanged(hsv.withHue(hue));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final left = (hsv.hue / 360) * width;
          return GestureDetector(
            onTapDown: (details) => _update(details.localPosition, width),
            onPanUpdate: (details) => _update(details.localPosition, width),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: 4,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const CustomPaint(painter: _HuePainter()),
                  ),
                ),
                Positioned(
                  left: left - 14,
                  top: -1,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                      border: Border.all(color: TaploeColors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: TaploeColors.black.withValues(alpha: .20),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  final HSVColor hsv;

  const _SaturationValuePainter(this.hsv);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: const [TaploeColors.white, Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, TaploeColors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) {
    return oldDelegate.hsv.hue != hsv.hue;
  }
}

class _HuePainter extends CustomPainter {
  const _HuePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = [
      for (var hue = 0; hue <= 360; hue += 30)
        HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor(),
    ];
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DigitalProfilePhonePreview extends StatelessWidget {
  final DigitalProfileModel profile;
  final List<SmartFormModel> forms;
  final List<ProfileIntegrationModel> integrations;

  const _DigitalProfilePhonePreview({
    required this.profile,
    this.forms = const [],
    this.integrations = const [],
  });

  @override
  Widget build(BuildContext context) {
    const phoneWidth = 390.0;
    const phoneHeight = 844.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : phoneWidth;
        final previewWidth = availableWidth < phoneWidth
            ? availableWidth
            : phoneWidth;
        final previewScale = previewWidth / phoneWidth;

        return Center(
          child: SizedBox(
            width: previewWidth,
            height: phoneHeight * previewScale,
            child: Transform.scale(
              scale: previewScale,
              alignment: Alignment.topCenter,
              child: TaploePublicProfileCard(
                profile: profile,
                links: profile.links,
                forms: forms,
                integrations: integrations,
                framed: true,
                allowVerifiedBadge:
                    taploeState.capabilities.canShowVerifiedBadge,
                allowCustomDesign: taploeState.capabilities.canUseDesign,
                allowForms: taploeState.capabilities.canUseForms,
                allowIntegrations: taploeState.capabilities.canUseIntegrations,
                showTaploeWatermark:
                    !taploeState.capabilities.canRemoveTaploeWatermark,
              ),
            ),
          ),
        );
      },
    );
  }
}

IconData _linkIcon(String type) {
  switch (type) {
    case 'phone':
      return Icons.phone_outlined;
    case 'email':
      return Icons.mail_outline_rounded;
    case 'whatsapp':
      return Icons.chat_bubble_outline_rounded;
    case 'website':
      return Icons.public_rounded;
    case 'instagram':
    case 'facebook':
    case 'linkedin':
    case 'tiktok':
    case 'youtube':
    case 'x':
      return Icons.alternate_email_rounded;
    case 'maps':
      return Icons.location_on_outlined;
    case 'calendar':
      return Icons.calendar_month_outlined;
    case 'catalog':
    case 'file':
      return Icons.description_outlined;
    case 'payment':
      return Icons.payments_outlined;
    default:
      return Icons.link_rounded;
  }
}

String? _brandGlyph(String type) {
  switch (type) {
    case 'whatsapp':
      return 'WA';
    case 'instagram':
      return 'IG';
    case 'facebook':
      return 'f';
    case 'linkedin':
      return 'in';
    case 'tiktok':
      return '♪';
    case 'youtube':
      return '▶';
    case 'x':
      return 'X';
    default:
      return null;
  }
}

Color _linkBrandColor(String type) {
  switch (type) {
    case 'whatsapp':
      return const Color(0xFF22C55E);
    case 'instagram':
      return const Color(0xFFE1306C);
    case 'facebook':
      return const Color(0xFF1877F2);
    case 'linkedin':
      return const Color(0xFF0A66C2);
    case 'tiktok':
      return TaploeColors.black;
    case 'youtube':
      return const Color(0xFFFF0000);
    case 'x':
      return TaploeColors.black;
    case 'email':
      return TaploeColors.blue;
    case 'phone':
      return const Color(0xFF16A34A);
    case 'maps':
      return TaploeColors.warning;
    default:
      return TaploeColors.blue;
  }
}

class _ProfilePhotoHeroPicker extends StatelessWidget {
  final String value;
  final bool loading;
  final VoidCallback onTap;

  const _ProfilePhotoHeroPicker({
    required this.value,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Column(
      children: [
        Container(
          width: 128,
          height: 128,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: TaploeColors.page,
            shape: BoxShape.circle,
            border: Border.all(color: TaploeColors.border),
          ),
          child: hasValue
              ? Image.network(
                  value,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person_outline_rounded,
                    color: TaploeColors.blue,
                    size: 44,
                  ),
                )
              : const Icon(
                  Icons.person_outline_rounded,
                  color: TaploeColors.blue,
                  size: 44,
                ),
        ),
        const SizedBox(height: 10),
        TaploeButton(
          width: 280,
          label: hasValue ? 'Cambiar foto de perfil' : 'Cargar foto de perfil',
          icon: Icons.photo_camera_outlined,
          kind: TaploeButtonKind.secondary,
          loading: loading,
          onPressed: loading ? null : onTap,
        ),
      ],
    );
  }
}

class _ProfileAssetPicker extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool loading;
  final bool wide;
  final Widget? fallback;
  final VoidCallback onTap;

  const _ProfileAssetPicker({
    required this.label,
    required this.value,
    required this.icon,
    required this.loading,
    required this.onTap,
    this.wide = false,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    final isLogo = label.toLowerCase().contains('logo');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: wide ? 82 : 56,
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: TaploeColors.page,
              borderRadius: BorderRadius.circular(wide ? 14 : 999),
              border: Border.all(color: TaploeColors.border),
            ),
            child: hasValue
                ? Image.network(
                    value,
                    fit: isLogo ? BoxFit.contain : BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) =>
                        Icon(icon, color: TaploeColors.blue),
                  )
                : Center(
                    child: fallback ?? Icon(icon, color: TaploeColors.blue),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? 'Archivo cargado' : 'Sin archivo cargado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(color: context.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TaploeButton(
            width: 170,
            label: loading
                ? 'Cargando...'
                : hasValue
                ? 'Cambiar archivo'
                : 'Cargar archivo',
            icon: Icons.upload_file_rounded,
            kind: TaploeButtonKind.secondary,
            loading: loading,
            onPressed: loading ? null : onTap,
          ),
        ],
      ),
    );
  }
}

class _CompanyManagedLogoCard extends StatelessWidget {
  final String? logoUrl;
  final bool loading;
  final VoidCallback? onPressed;

  const _CompanyManagedLogoCard({
    required this.logoUrl,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cleanLogoUrl = logoUrl?.trim();
    final hasLogo = cleanLogoUrl != null && cleanLogoUrl.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: TaploeColors.page,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TaploeColors.border),
            ),
            child: hasLogo
                ? Image.network(
                    cleanLogoUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.business_rounded,
                      color: TaploeColors.blue,
                    ),
                  )
                : const Icon(Icons.business_rounded, color: TaploeColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logo de empresa',
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLogo
                      ? 'Se usa como logo principal de la empresa.'
                      : 'Carga el logo principal para tus perfiles de empresa.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(color: context.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TaploeButton(
            width: 170,
            label: loading
                ? 'Cargando...'
                : hasLogo
                ? 'Modificar logo'
                : 'Cargar logo',
            icon: Icons.business_center_outlined,
            kind: TaploeButtonKind.secondary,
            loading: loading,
            onPressed: loading ? null : onPressed,
          ),
        ],
      ),
    );
  }
}

Future<Uint8List?> _showProfileAssetEditor(
  BuildContext context, {
  required String kind,
  required Uint8List bytes,
}) {
  return showDialog<Uint8List>(
    context: context,
    builder: (context) => _ProfileAssetEditorDialog(kind: kind, bytes: bytes),
  );
}

const _profileAssetAllowedExtensions = [
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
  'svg',
];

bool _isAllowedProfileAsset(String fileName) {
  final extension = fileName.split('?').first.split('.').last.toLowerCase();
  return _profileAssetAllowedExtensions.contains(extension);
}

bool _isSvgProfileAsset(String fileName) =>
    fileName.split('?').first.split('.').last.toLowerCase() == 'svg';

Future<Uint8List> _rasterizeSvgToPng(
  BuildContext context,
  Uint8List bytes, {
  required String kind,
}) async {
  final pictureInfo = await vg.loadPicture(SvgBytesLoader(bytes), context);
  try {
    final size = pictureInfo.size;
    final aspect = size.width > 0 && size.height > 0
        ? size.width / size.height
        : switch (kind) {
            'logo' => 2.7,
            'profile-photo' => 1.0,
            _ => 16 / 9,
          };
    final width = 1600;
    final height = (width / aspect).round().clamp(1, 1600);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final scale = size.width > 0 ? width / size.width : 1.0;
    canvas.scale(scale);
    canvas.drawPicture(pictureInfo.picture);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('No se pudo convertir el SVG.');
    return data.buffer.asUint8List();
  } finally {
    pictureInfo.picture.dispose();
  }
}

class _ProfileAssetEditorDialog extends StatefulWidget {
  final String kind;
  final Uint8List bytes;

  const _ProfileAssetEditorDialog({required this.kind, required this.bytes});

  @override
  State<_ProfileAssetEditorDialog> createState() =>
      _ProfileAssetEditorDialogState();
}

class _ProfileAssetEditorDialogState extends State<_ProfileAssetEditorDialog> {
  double zoom = 1;
  Alignment alignment = Alignment.center;
  bool processing = false;

  bool get circular => widget.kind == 'profile-photo';
  bool get logo => widget.kind == 'logo';
  double get aspectRatio => circular
      ? 1
      : logo
      ? 2.7
      : 16 / 9;
  int get outputWidth => circular
      ? 900
      : logo
      ? 1200
      : 1600;
  int get outputHeight => circular
      ? 900
      : logo
      ? 444
      : 900;
  String get title => switch (widget.kind) {
    'profile-photo' => 'Ajustar foto de perfil',
    'logo' => 'Ajustar logo',
    _ => 'Ajustar portada',
  };

  Future<void> confirm() async {
    setState(() => processing = true);
    try {
      final cropped = await _cropImageToJpg(
        widget.bytes,
        width: outputWidth,
        height: outputHeight,
        zoom: zoom,
        alignment: alignment,
      );
      if (mounted) Navigator.pop(context, cropped);
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos preparar la imagen. Si es HEIC, intenta desde Safari/iOS o usa JPG.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(circular ? 999 : 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TaploeColors.page,
            border: Border.all(color: TaploeColors.border),
          ),
          child: Transform.scale(
            scale: zoom,
            alignment: alignment,
            child: Image.memory(
              widget.bytes,
              fit: BoxFit.contain,
              alignment: alignment,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );

    return TaploeModalShell(
      maxWidth: 560,
      title: title,
      subtitle:
          'Previsualiza el encuadre antes de guardarlo en tu perfil público.',
      footer: TaploeModalFooter(
        primaryLabel: processing ? 'Guardando...' : 'Usar imagen',
        primaryIcon: Icons.check_rounded,
        onPrimary: processing ? null : confirm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: circular ? 260 : double.infinity,
              child: preview,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Zoom',
            style: GoogleFonts.dmSans(
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            value: zoom,
            min: 1,
            max: 3,
            divisions: 8,
            onChanged: (value) => setState(() => zoom = value),
          ),
          const SizedBox(height: 10),
          Text(
            'Posición',
            style: GoogleFonts.dmSans(
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AlignmentChip(
                label: 'Arriba',
                selected: alignment == Alignment.topCenter,
                onTap: () => setState(() => alignment = Alignment.topCenter),
              ),
              _AlignmentChip(
                label: 'Centro',
                selected: alignment == Alignment.center,
                onTap: () => setState(() => alignment = Alignment.center),
              ),
              _AlignmentChip(
                label: 'Abajo',
                selected: alignment == Alignment.bottomCenter,
                onTap: () => setState(() => alignment = Alignment.bottomCenter),
              ),
              _AlignmentChip(
                label: 'Izquierda',
                selected: alignment == Alignment.centerLeft,
                onTap: () => setState(() => alignment = Alignment.centerLeft),
              ),
              _AlignmentChip(
                label: 'Derecha',
                selected: alignment == Alignment.centerRight,
                onTap: () => setState(() => alignment = Alignment.centerRight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlignmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AlignmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: TaploeColors.blue.withValues(alpha: .12),
      labelStyle: GoogleFonts.dmSans(
        color: selected ? TaploeColors.blue : context.text,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? TaploeColors.blue : context.border),
    );
  }
}

Future<Uint8List> _cropImageToJpg(
  Uint8List bytes, {
  required int width,
  required int height,
  required double zoom,
  required Alignment alignment,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final imageWidth = image.width.toDouble();
  final imageHeight = image.height.toDouble();
  final targetAspect = width / height;
  final imageAspect = imageWidth / imageHeight;
  final baseScale = imageAspect > targetAspect
      ? width / imageWidth
      : height / imageHeight;
  final drawWidth = imageWidth * baseScale * zoom;
  final drawHeight = imageHeight * baseScale * zoom;
  final left = ((alignment.x + 1) / 2) * (width - drawWidth);
  final top = ((alignment.y + 1) / 2) * (height - drawHeight);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..isAntiAlias = true;
  canvas.drawColor(Colors.white, BlendMode.src);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, imageWidth, imageHeight),
    Rect.fromLTWH(left, top, drawWidth, drawHeight),
    paint,
  );
  final picture = recorder.endRecording();
  final output = await picture.toImage(width, height);
  final data = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('No se pudo procesar la imagen.');
  final encoded = img.encodeJpg(
    img.Image.fromBytes(
      width: width,
      height: height,
      bytes: data.buffer,
      order: img.ChannelOrder.rgba,
    ),
    quality: 92,
  );
  return Uint8List.fromList(encoded);
}

class _LinkTypeOption {
  final String type;
  final String label;
  final String inputLabel;
  final String hint;
  final IconData icon;
  final bool customLabel;

  const _LinkTypeOption({
    required this.type,
    required this.label,
    required this.inputLabel,
    required this.hint,
    required this.icon,
    this.customLabel = false,
  });
}

const _linkOptions = [
  _LinkTypeOption(
    type: 'whatsapp',
    label: 'WhatsApp',
    inputLabel: 'Número de WhatsApp',
    hint: '+52 664 123 4567',
    icon: Icons.chat_bubble_outline_rounded,
  ),
  _LinkTypeOption(
    type: 'phone',
    label: 'Teléfono',
    inputLabel: 'Número telefónico',
    hint: '+52 664 123 4567',
    icon: Icons.phone_outlined,
  ),
  _LinkTypeOption(
    type: 'email',
    label: 'Correo',
    inputLabel: 'Correo electrónico',
    hint: 'da@ejemplo.com',
    icon: Icons.mail_outline_rounded,
  ),
  _LinkTypeOption(
    type: 'website',
    label: 'Sitio web',
    inputLabel: 'URL del sitio',
    hint: 'https://taploe.com',
    icon: Icons.public_rounded,
  ),
  _LinkTypeOption(
    type: 'instagram',
    label: 'Instagram',
    inputLabel: 'Usuario o URL',
    hint: '@taploe',
    icon: Icons.alternate_email_rounded,
  ),
  _LinkTypeOption(
    type: 'facebook',
    label: 'Facebook',
    inputLabel: 'Usuario o URL',
    hint: 'https://facebook.com/taploe',
    icon: Icons.alternate_email_rounded,
  ),
  _LinkTypeOption(
    type: 'linkedin',
    label: 'LinkedIn',
    inputLabel: 'URL de LinkedIn',
    hint: 'https://linkedin.com/in/daniel',
    icon: Icons.work_outline_rounded,
  ),
  _LinkTypeOption(
    type: 'tiktok',
    label: 'TikTok',
    inputLabel: 'Usuario o URL',
    hint: '@taploe',
    icon: Icons.music_note_rounded,
  ),
  _LinkTypeOption(
    type: 'youtube',
    label: 'YouTube',
    inputLabel: 'URL de YouTube',
    hint: 'https://youtube.com/@taploe',
    icon: Icons.play_circle_outline_rounded,
  ),
  _LinkTypeOption(
    type: 'x',
    label: 'X',
    inputLabel: 'Usuario o URL',
    hint: '@taploe',
    icon: Icons.alternate_email_rounded,
  ),
  _LinkTypeOption(
    type: 'maps',
    label: 'Google Maps',
    inputLabel: 'URL de ubicación',
    hint: 'https://maps.google.com/?q=Taploe',
    icon: Icons.location_on_outlined,
  ),
  _LinkTypeOption(
    type: 'calendar',
    label: 'Calendario',
    inputLabel: 'URL para agendar',
    hint: 'https://calendly.com/taploe/demo',
    icon: Icons.calendar_month_outlined,
  ),
  _LinkTypeOption(
    type: 'catalog',
    label: 'Catálogo',
    inputLabel: 'URL del catálogo',
    hint: 'https://taploe.com/catalogo.pdf',
    icon: Icons.menu_book_outlined,
  ),
  _LinkTypeOption(
    type: 'file',
    label: 'Archivo',
    inputLabel: 'URL del archivo',
    hint: 'https://taploe.com/brochure.pdf',
    icon: Icons.description_outlined,
  ),
  _LinkTypeOption(
    type: 'payment',
    label: 'Pago',
    inputLabel: 'URL de pago',
    hint: 'https://stripe.com/pay/...',
    icon: Icons.payments_outlined,
  ),
  _LinkTypeOption(
    type: 'custom',
    label: 'Personalizado',
    inputLabel: 'URL o valor',
    hint: 'https://...',
    icon: Icons.link_rounded,
    customLabel: true,
  ),
];

const _modalLinkTypes = {
  'whatsapp',
  'phone',
  'email',
  'website',
  'instagram',
  'facebook',
  'linkedin',
  'tiktok',
  'youtube',
  'x',
  'maps',
  'custom',
};

FaIconData? _fontAwesomeIconForLinkType(String type) {
  switch (type) {
    case 'whatsapp':
      return FontAwesomeIcons.whatsapp;
    case 'email':
      return FontAwesomeIcons.envelope;
    case 'maps':
      return FontAwesomeIcons.locationDot;
    case 'instagram':
      return FontAwesomeIcons.instagram;
    case 'facebook':
      return FontAwesomeIcons.facebook;
    case 'linkedin':
      return FontAwesomeIcons.linkedin;
    case 'tiktok':
      return FontAwesomeIcons.tiktok;
    case 'x':
      return FontAwesomeIcons.xTwitter;
    case 'youtube':
      return FontAwesomeIcons.youtube;
    default:
      return null;
  }
}

Color? _brandColorForLinkType(String type) {
  switch (type) {
    case 'whatsapp':
      return const Color(0xFF25D366);
    case 'email':
      return const Color(0xFFEA4335);
    case 'maps':
      return const Color(0xFF4285F4);
    case 'instagram':
      return const Color(0xFFE1306C);
    case 'facebook':
      return const Color(0xFF1877F2);
    case 'linkedin':
      return const Color(0xFF0A66C2);
    case 'tiktok':
    case 'x':
      return TaploeColors.black;
    case 'youtube':
      return const Color(0xFFFF0000);
    default:
      return null;
  }
}

_LinkTypeOption _optionForType(String type) => _linkOptions.firstWhere(
  (option) => option.type == type,
  orElse: () => _linkOptions.last,
);

String _cleanPhone(String value) => value.replaceAll(RegExp(r'[^0-9+]'), '');

String _ensureUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('mailto:') ||
      trimmed.startsWith('tel:')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

String _linkUrlFor(String type, String value) {
  final trimmed = value.trim();
  switch (type) {
    case 'phone':
      return 'tel:${_cleanPhone(trimmed)}';
    case 'email':
      return 'mailto:$trimmed';
    case 'whatsapp':
      return 'https://wa.me/${_cleanPhone(trimmed).replaceAll('+', '')}';
    case 'instagram':
      return trimmed.startsWith('http')
          ? trimmed
          : 'https://instagram.com/${trimmed.replaceAll('@', '')}';
    case 'facebook':
      return trimmed.startsWith('http')
          ? trimmed
          : 'https://facebook.com/${trimmed.replaceAll('@', '')}';
    case 'tiktok':
      return trimmed.startsWith('http')
          ? trimmed
          : 'https://tiktok.com/@${trimmed.replaceAll('@', '')}';
    case 'x':
      return trimmed.startsWith('http')
          ? trimmed
          : 'https://x.com/${trimmed.replaceAll('@', '')}';
    default:
      return _ensureUrl(trimmed);
  }
}

Color _colorFromHex(String value, {required Color fallback}) {
  final clean = value.replaceAll('#', '').trim();
  if (clean.length != 6) return fallback;
  final parsed = int.tryParse('FF$clean', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

String _hexFromColor(Color color) {
  final red = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final green = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final blue = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${red.toUpperCase()}${green.toUpperCase()}${blue.toUpperCase()}';
}

ProfileLinkModel _copyLink(
  ProfileLinkModel link, {
  bool? isVisible,
  bool? isFeatured,
  int? sortOrder,
}) {
  return ProfileLinkModel(
    id: link.id,
    profileId: link.profileId,
    linkType: link.linkType,
    label: link.label,
    value: link.value,
    url: link.url,
    iconKey: link.iconKey,
    isVisible: isVisible ?? link.isVisible,
    isFeatured: isFeatured ?? link.isFeatured,
    sortOrder: sortOrder ?? link.sortOrder,
    openMode: link.openMode,
    metadata: link.metadata,
  );
}

ProfileLinkModel? _contactLink(DigitalProfileModel profile, String type) {
  for (final link in profile.links) {
    if (link.linkType == type) return link;
  }
  return null;
}

bool _contactLinkVisible(DigitalProfileModel profile, String type) =>
    _contactLink(profile, type)?.isVisible ?? false;

Future<void> _toggleContactLink(
  BuildContext context, {
  required DigitalProfileModel profile,
  required String type,
  required String label,
  required String value,
  required bool visible,
}) async {
  final cleanValue = value.trim();
  if (cleanValue.isEmpty && visible) {
    taploeToast(context, 'Agrega un valor antes de mostrarlo.', error: true);
    return;
  }

  final existing = _contactLink(profile, type);
  if (existing == null) {
    final created = await ProfileRepository.addLink(
      profileId: profile.id,
      linkType: type,
      label: label,
      value: cleanValue,
      url: _linkUrlFor(type, cleanValue),
      iconKey: type,
      isVisible: visible,
      sortOrder: profile.links.length + 1,
    );
    taploeState.updateActiveProfile(
      profile.copyWith(links: [...profile.links, created]),
    );
  } else {
    final updated = ProfileLinkModel(
      id: existing.id,
      profileId: existing.profileId,
      linkType: existing.linkType,
      label: label,
      value: cleanValue.isEmpty ? existing.value : cleanValue,
      url: cleanValue.isEmpty ? existing.url : _linkUrlFor(type, cleanValue),
      iconKey: existing.iconKey ?? type,
      isVisible: visible,
      isFeatured: existing.isFeatured,
      sortOrder: existing.sortOrder,
      openMode: existing.openMode,
      metadata: existing.metadata,
    );
    taploeState.updateActiveProfile(
      profile.copyWith(
        links: profile.links
            .map((link) => link.id == existing.id ? updated : link)
            .toList(),
      ),
    );
    await ProfileRepository.updateLink(updated);
  }
  await taploeState.refreshProfiles();
}

Future<void> _saveThemeQuick(
  DigitalProfileModel profile,
  ProfileThemeModel theme,
) async {
  final updated = profile.copyWith(theme: theme);
  taploeState.updateActiveProfile(updated);
  final saved = await ProfileRepository.updateProfile(updated);
  taploeState.updateActiveProfile(saved);
}

extension _ProfileThemeQuickCopy on ProfileThemeModel {
  ProfileThemeModel copyWithButtonStyle(String value) => ProfileThemeModel(
    id: id,
    profileId: profileId,
    themeStyle: themeStyle,
    layoutStyle: layoutStyle,
    primaryColor: primaryColor,
    secondaryColor: secondaryColor,
    accentColor: accentColor,
    backgroundType: backgroundType,
    backgroundColorStart: backgroundColorStart,
    backgroundColorEnd: backgroundColorEnd,
    backgroundImageUrl: backgroundImageUrl,
    buttonStyle: value,
    fontFamily: fontFamily,
    logoSize: logoSize,
    logoVerticalOffset: logoVerticalOffset,
  );

  ProfileThemeModel copyWithPrimary(String value) => ProfileThemeModel(
    id: id,
    profileId: profileId,
    themeStyle: themeStyle,
    layoutStyle: layoutStyle,
    primaryColor: value,
    secondaryColor: secondaryColor,
    accentColor: value,
    backgroundType: backgroundType,
    backgroundColorStart: backgroundColorStart,
    backgroundColorEnd: backgroundColorEnd,
    backgroundImageUrl: backgroundImageUrl,
    buttonStyle: buttonStyle,
    fontFamily: fontFamily,
    logoSize: logoSize,
    logoVerticalOffset: logoVerticalOffset,
  );

  ProfileThemeModel copyWithAccent(String value) => ProfileThemeModel(
    id: id,
    profileId: profileId,
    themeStyle: themeStyle,
    layoutStyle: layoutStyle,
    primaryColor: primaryColor,
    secondaryColor: secondaryColor,
    accentColor: value,
    backgroundType: backgroundType,
    backgroundColorStart: backgroundColorStart,
    backgroundColorEnd: backgroundColorEnd,
    backgroundImageUrl: backgroundImageUrl,
    buttonStyle: buttonStyle,
    fontFamily: fontFamily,
    logoSize: logoSize,
    logoVerticalOffset: logoVerticalOffset,
  );

  ProfileThemeModel copyWithBackgroundMode(String value) {
    if (value == 'dark') {
      return ProfileThemeModel(
        id: id,
        profileId: profileId,
        themeStyle: 'dark',
        layoutStyle: layoutStyle,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        accentColor: accentColor,
        backgroundType: 'solid',
        backgroundColorStart: '#050505',
        backgroundColorEnd: null,
        backgroundImageUrl: null,
        buttonStyle: buttonStyle,
        fontFamily: fontFamily,
        logoSize: logoSize,
        logoVerticalOffset: logoVerticalOffset,
      );
    }
    if (value == 'custom') {
      return ProfileThemeModel(
        id: id,
        profileId: profileId,
        themeStyle: 'custom',
        layoutStyle: layoutStyle,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        accentColor: accentColor,
        backgroundType: 'gradient',
        backgroundColorStart: primaryColor,
        backgroundColorEnd: accentColor,
        backgroundImageUrl: backgroundImageUrl,
        buttonStyle: buttonStyle,
        fontFamily: fontFamily,
        logoSize: logoSize,
        logoVerticalOffset: logoVerticalOffset,
      );
    }
    return ProfileThemeModel(
      id: id,
      profileId: profileId,
      themeStyle: 'light',
      layoutStyle: layoutStyle,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      accentColor: accentColor,
      backgroundType: 'solid',
      backgroundColorStart: '#FFFFFF',
      backgroundColorEnd: null,
      backgroundImageUrl: null,
      buttonStyle: buttonStyle,
      fontFamily: fontFamily,
      logoSize: logoSize,
      logoVerticalOffset: logoVerticalOffset,
    );
  }

  ProfileThemeModel copyWithBackgroundColor(String value) {
    final upper = value.toUpperCase();
    final style = switch (upper) {
      '#050505' || '#111111' => 'dark',
      '#FFFFFF' || '#F8FAFC' => 'light',
      _ => 'custom',
    };
    return ProfileThemeModel(
      id: id,
      profileId: profileId,
      themeStyle: style,
      layoutStyle: layoutStyle,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      accentColor: accentColor,
      backgroundType: 'solid',
      backgroundColorStart: value,
      backgroundColorEnd: null,
      backgroundImageUrl: null,
      buttonStyle: buttonStyle,
      fontFamily: fontFamily,
      logoSize: logoSize,
      logoVerticalOffset: logoVerticalOffset,
    );
  }

  ProfileThemeModel copyWithFontFamily(String value) => ProfileThemeModel(
    id: id,
    profileId: profileId,
    themeStyle: themeStyle,
    layoutStyle: layoutStyle,
    primaryColor: primaryColor,
    secondaryColor: secondaryColor,
    accentColor: accentColor,
    backgroundType: backgroundType,
    backgroundColorStart: backgroundColorStart,
    backgroundColorEnd: backgroundColorEnd,
    backgroundImageUrl: backgroundImageUrl,
    buttonStyle: buttonStyle,
    fontFamily: value,
    logoSize: logoSize,
    logoVerticalOffset: logoVerticalOffset,
  );

  ProfileThemeModel copyWithLogoSize(double value) => ProfileThemeModel(
    id: id,
    profileId: profileId,
    themeStyle: themeStyle,
    layoutStyle: layoutStyle,
    primaryColor: primaryColor,
    secondaryColor: secondaryColor,
    accentColor: accentColor,
    backgroundType: backgroundType,
    backgroundColorStart: backgroundColorStart,
    backgroundColorEnd: backgroundColorEnd,
    backgroundImageUrl: backgroundImageUrl,
    buttonStyle: buttonStyle,
    fontFamily: fontFamily,
    logoSize: value,
    logoVerticalOffset: logoVerticalOffset,
  );

  ProfileThemeModel copyWithLogoVerticalOffset(double value) =>
      ProfileThemeModel(
        id: id,
        profileId: profileId,
        themeStyle: themeStyle,
        layoutStyle: layoutStyle,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        accentColor: accentColor,
        backgroundType: backgroundType,
        backgroundColorStart: backgroundColorStart,
        backgroundColorEnd: backgroundColorEnd,
        backgroundImageUrl: backgroundImageUrl,
        buttonStyle: buttonStyle,
        fontFamily: fontFamily,
        logoSize: logoSize,
        logoVerticalOffset: value,
      );
}

Future<void> _showVcardDialog(
  BuildContext context,
  DigitalProfileModel profile,
) async {
  final vcf =
      profile.vcard?.toVcf(
        displayName: profile.displayName,
        profilePhotoUrl: profile.profilePhotoUrl,
      ) ??
      '';
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Descargar vCard'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Así se genera el contacto que verá el usuario al guardar tu perfil.',
                style: GoogleFonts.dmSans(color: context.muted),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TaploeColors.page,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TaploeColors.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    vcf,
                    style: GoogleFonts.dmSans(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: vcf));
              taploeToast(context, 'vCard copiada.');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copiar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.dataFromString(
                vcf,
                mimeType: 'text/vcard',
                encoding: utf8,
              );
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Abrir/descargar'),
          ),
        ],
      );
    },
  );
}

Future<void> _showLinkEditorDialog(
  BuildContext context, {
  required DigitalProfileModel profile,
  ProfileLinkModel? link,
}) async {
  if (link == null && profile.links.length >= taploeMaxProfileLinks) {
    taploeToast(
      context,
      'Puedes agregar hasta $taploeMaxProfileLinks enlaces por perfil.',
      error: true,
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => _LinkEditorModal(profile: profile, link: link),
  );
}

class _LinkEditorModal extends StatefulWidget {
  final DigitalProfileModel profile;
  final ProfileLinkModel? link;

  const _LinkEditorModal({required this.profile, this.link});

  @override
  State<_LinkEditorModal> createState() => _LinkEditorModalState();
}

class _LinkEditorModalState extends State<_LinkEditorModal> {
  late String selectedType;
  late bool isVisible;
  late bool isFeatured;
  late final TextEditingController label;
  late final TextEditingController value;
  late final FocusNode labelFocus;
  late final FocusNode valueFocus;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selectedType = _modalLinkTypes.contains(widget.link?.linkType)
        ? widget.link!.linkType
        : 'whatsapp';
    final option = _optionForType(selectedType);
    isVisible = widget.link?.isVisible ?? true;
    isFeatured = widget.link?.isFeatured ?? false;
    label = TextEditingController(text: widget.link?.label ?? option.label);
    value = TextEditingController(
      text: widget.link?.value ?? widget.link?.url ?? '',
    );
    labelFocus = FocusNode();
    valueFocus = FocusNode();
  }

  @override
  void dispose() {
    labelFocus.dispose();
    valueFocus.dispose();
    label.dispose();
    value.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final option = _optionForType(selectedType);
    final cleanLabel = option.customLabel
        ? label.text.trim()
        : label.text.trim();
    final cleanValue = value.text.trim();
    if (cleanLabel.isEmpty || cleanValue.isEmpty) {
      taploeToast(context, 'Completa los campos del enlace.', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      final url = _linkUrlFor(selectedType, cleanValue);
      ProfileLinkModel saved;
      if (widget.link == null) {
        final currentLinkCount =
            taploeState.activeProfile?.id == widget.profile.id
            ? taploeState.activeProfile!.links.length
            : widget.profile.links.length;
        if (currentLinkCount >= taploeMaxProfileLinks) {
          taploeToast(
            context,
            'Puedes agregar hasta $taploeMaxProfileLinks enlaces por perfil.',
            error: true,
          );
          return;
        }

        saved = await ProfileRepository.addLink(
          profileId: widget.profile.id,
          linkType: selectedType,
          label: cleanLabel,
          value: cleanValue,
          url: url,
          iconKey: selectedType,
          isVisible: isVisible,
          isFeatured: isFeatured,
          sortOrder: widget.profile.links.length + 1,
        );
      } else {
        final link = widget.link!;
        saved = await ProfileRepository.updateLink(
          ProfileLinkModel(
            id: link.id,
            profileId: link.profileId,
            linkType: selectedType,
            label: cleanLabel,
            value: cleanValue,
            url: url,
            iconKey: selectedType,
            isVisible: isVisible,
            isFeatured: isFeatured,
            sortOrder: link.sortOrder,
            openMode: link.openMode,
            metadata: link.metadata,
          ),
        );
      }
      final current = taploeState.activeProfile;
      if (current?.id == widget.profile.id) {
        final withoutSaved = current!.links
            .where((link) => link.id != saved.id)
            .toList();
        taploeState.updateActiveProfile(
          current.copyWith(
            links: [...withoutSaved, saved]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
          ),
        );
      }
      await taploeState.refreshProfiles();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        final message = error.toString().contains('profile_link_limit_reached')
            ? 'Puedes agregar hasta $taploeMaxProfileLinks enlaces por perfil.'
            : 'No pudimos guardar el enlace. Intenta de nuevo.';
        taploeToast(context, message, error: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final option = _optionForType(selectedType);
    final options = _linkOptions
        .where((option) => _modalLinkTypes.contains(option.type))
        .toList();
    return TaploeModalShell(
      maxWidth: 900,
      title: widget.link == null ? 'Agregar enlace' : 'Editar enlace',
      subtitle:
          'Conecta tus canales y herramientas para que otros puedan contactarte fácilmente.',
      footer: TaploeModalFooter(
        primaryLabel: saving
            ? 'Guardando...'
            : widget.link == null
            ? 'Agregar enlace'
            : 'Guardar cambios',
        primaryIcon: widget.link == null
            ? Icons.add_rounded
            : Icons.save_outlined,
        onPrimary: saving ? null : save,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 720;
          final selector = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tipo de enlace',
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: stacked ? 3 : 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 86,
                ),
                itemBuilder: (context, index) {
                  final item = options[index];
                  return _LinkTypeGridButton(
                    option: item,
                    selected: selectedType == item.type,
                    onTap: () {
                      setState(() {
                        selectedType = item.type;
                        label.text = item.label;
                      });
                    },
                  );
                },
              ),
            ],
          );
          final form = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaploeTextField(
                label: 'Etiqueta visible',
                controller: label,
                focusNode: labelFocus,
                hint: option.customLabel ? 'Mi enlace' : option.label,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  valueFocus.requestFocus();
                },
              ),
              const SizedBox(height: 14),
              TaploeTextField(
                label: option.inputLabel,
                controller: value,
                focusNode: valueFocus,
                hint: option.hint,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                keyboardType: selectedType == 'email'
                    ? TextInputType.emailAddress
                    : selectedType == 'phone' || selectedType == 'whatsapp'
                    ? TextInputType.phone
                    : TextInputType.url,
                onSubmitted: (_) {
                  if (!saving) save();
                },
              ),
              const SizedBox(height: 14),
              TaploeToggleRow(
                title: 'Visible en perfil público',
                subtitle: 'Los visitantes podrán ver este enlace.',
                icon: Icons.visibility_outlined,
                value: isVisible,
                onChanged: (v) => setState(() => isVisible = v),
              ),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [selector, const SizedBox(height: 20), form],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 330, child: selector),
              Container(
                width: 1,
                height: 398,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: TaploeColors.border,
              ),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showFormEditorDialog(
  BuildContext context, {
  required DigitalProfileModel profile,
  SmartFormModel? form,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _SmartFormModal(profile: profile, form: form),
  );
}

class _SmartFormModal extends StatefulWidget {
  final DigitalProfileModel profile;
  final SmartFormModel? form;

  const _SmartFormModal({required this.profile, this.form});

  @override
  State<_SmartFormModal> createState() => _SmartFormModalState();
}

class _SmartFormModalState extends State<_SmartFormModal> {
  late final TextEditingController name;
  late final TextEditingController formKey;
  late final TextEditingController description;
  late final TextEditingController success;
  late final TextEditingController notify;
  late final FocusNode nameFocus;
  late final FocusNode descriptionFocus;
  late final FocusNode successFocus;
  bool isActive = true;
  bool saving = false;
  bool loadingFields = false;
  final Set<String> selectedFields = {'name', 'email', 'phone', 'message'};
  final Map<String, SmartFormFieldModel> existingFields = {};

  @override
  void initState() {
    super.initState();
    final form = widget.form;
    isActive = form?.isActive ?? true;
    name = TextEditingController(text: form?.name ?? '');
    formKey = TextEditingController(text: form?.formKey ?? '');
    description = TextEditingController(text: form?.description ?? '');
    success = TextEditingController(
      text: form?.successMessage ?? 'Gracias, recibimos tu información.',
    );
    notify = TextEditingController(text: form?.notifyEmails.join(', ') ?? '');
    nameFocus = FocusNode();
    descriptionFocus = FocusNode();
    successFocus = FocusNode();
    if (form != null) _loadFields(form.id);
  }

  @override
  void dispose() {
    nameFocus.dispose();
    descriptionFocus.dispose();
    successFocus.dispose();
    name.dispose();
    formKey.dispose();
    description.dispose();
    success.dispose();
    notify.dispose();
    super.dispose();
  }

  Future<void> _loadFields(String formId) async {
    setState(() => loadingFields = true);
    final fields = await SmartFormRepository.fetchFields(formId);
    if (!mounted) return;
    existingFields
      ..clear()
      ..addEntries(fields.map((field) => MapEntry(field.fieldKey, field)));
    selectedFields
      ..clear()
      ..addAll(fields.map((field) => field.fieldKey));
    if (selectedFields.isEmpty) {
      selectedFields.addAll({'name', 'email', 'phone', 'message'});
    }
    setState(() => loadingFields = false);
  }

  Future<void> save() async {
    final cleanName = name.text.trim();
    if (cleanName.isEmpty) {
      taploeToast(context, 'Agrega nombre del formulario.', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      final saved = await SmartFormRepository.upsertForm(
        id: widget.form?.id,
        profileId: widget.profile.id,
        formKey: formKey.text.trim().isEmpty
            ? slugify(cleanName)
            : slugify(formKey.text),
        name: cleanName,
        description: description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        isActive: isActive,
        successMessage: success.text.trim(),
        notifyEmails: notify.text
            .split(',')
            .map((email) => email.trim())
            .where((email) => email.isNotEmpty)
            .toList(),
      );

      final ordered = _formFieldPresets
          .where((field) => selectedFields.contains(field.key))
          .toList();
      for (var i = 0; i < ordered.length; i++) {
        final preset = ordered[i];
        final existing = existingFields[preset.key];
        await SmartFormRepository.upsertField(
          id: existing?.id,
          formId: saved.id,
          fieldKey: preset.key,
          fieldType: preset.type,
          label: preset.label,
          placeholder: preset.placeholder,
          isRequired: preset.required,
          sortOrder: i + 1,
        );
      }
      for (final field in existingFields.values) {
        if (!selectedFields.contains(field.fieldKey)) {
          await SmartFormRepository.deleteField(field.id);
        }
      }
      await taploeState.refreshProfiles();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TaploeModalShell(
      maxWidth: 760,
      title: widget.form == null ? 'Crear formulario' : 'Editar formulario',
      subtitle:
          'Crea un formulario para captar contactos, cotizaciones o solicitudes.',
      footer: TaploeModalFooter(
        primaryLabel: saving ? 'Guardando...' : 'Guardar',
        primaryIcon: Icons.save_outlined,
        onPrimary: saving ? null : save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 680;
              final mainFields = Column(
                children: [
                  TaploeTextField(
                    label: 'Nombre del formulario',
                    controller: name,
                    focusNode: nameFocus,
                    hint: 'Ej. Contacto, Cotización, Agenda demo',
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      descriptionFocus.requestFocus();
                    },
                  ),
                  const SizedBox(height: 12),
                  TaploeTextField(
                    label: 'Descripción',
                    controller: description,
                    focusNode: descriptionFocus,
                    hint: 'Describe el propósito de este formulario',
                    textInputAction: TextInputAction.next,
                    maxLines: 3,
                    onSubmitted: (_) {
                      successFocus.requestFocus();
                    },
                  ),
                ],
              );
              final suggestions = _SuggestedUsePanel(
                onUse: (preset) {
                  setState(() {
                    name.text = preset.name;
                    formKey.text = preset.key;
                    description.text = preset.description;
                    selectedFields
                      ..clear()
                      ..addAll(preset.fields);
                  });
                },
              );
              if (!wide) {
                return Column(
                  children: [
                    mainFields,
                    const SizedBox(height: 14),
                    suggestions,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: mainFields),
                  const SizedBox(width: 18),
                  SizedBox(width: 210, child: suggestions),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TaploeTextField(
            label: 'Mensaje de éxito',
            controller: success,
            focusNode: successFocus,
            hint: 'Ej. Gracias, recibimos tu información.',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!saving) save();
            },
          ),
          const SizedBox(height: 18),
          _FormFieldsSelector(
            selected: selectedFields,
            loading: loadingFields,
            onChanged: (key, selected) {
              setState(() {
                if (selected) {
                  selectedFields.add(key);
                } else {
                  selectedFields.remove(key);
                }
              });
            },
          ),
          const SizedBox(height: 14),
          TaploeToggleRow(
            title: 'Formulario activo',
            subtitle: 'Activa o desactiva la recepción de respuestas.',
            icon: Icons.check_circle_outline_rounded,
            value: isActive,
            onChanged: (v) => setState(() => isActive = v),
          ),
        ],
      ),
    );
  }
}

class _FormFieldPreset {
  final String key;
  final String type;
  final String label;
  final String placeholder;
  final IconData icon;
  final bool required;

  const _FormFieldPreset({
    required this.key,
    required this.type,
    required this.label,
    required this.placeholder,
    required this.icon,
    this.required = false,
  });
}

const _formFieldPresets = [
  _FormFieldPreset(
    key: 'name',
    type: 'text',
    label: 'Nombre',
    placeholder: 'Tu nombre',
    icon: Icons.person_outline_rounded,
    required: true,
  ),
  _FormFieldPreset(
    key: 'email',
    type: 'email',
    label: 'Email',
    placeholder: 'da@ejemplo.com',
    icon: Icons.mail_outline_rounded,
    required: true,
  ),
  _FormFieldPreset(
    key: 'phone',
    type: 'phone',
    label: 'Teléfono',
    placeholder: '+52 664 123 4567',
    icon: Icons.phone_outlined,
  ),
  _FormFieldPreset(
    key: 'company',
    type: 'text',
    label: 'Empresa',
    placeholder: 'Nombre de tu empresa',
    icon: Icons.business_outlined,
  ),
  _FormFieldPreset(
    key: 'message',
    type: 'textarea',
    label: 'Mensaje',
    placeholder: 'Cuéntanos en qué podemos ayudarte',
    icon: Icons.chat_bubble_outline_rounded,
  ),
  _FormFieldPreset(
    key: 'budget',
    type: 'text',
    label: 'Presupuesto',
    placeholder: 'Ej. \$10,000 MXN',
    icon: Icons.payments_outlined,
  ),
  _FormFieldPreset(
    key: 'date',
    type: 'date',
    label: 'Fecha',
    placeholder: 'Selecciona una fecha',
    icon: Icons.calendar_month_outlined,
  ),
];

class _SuggestedFormUse {
  final String name;
  final String key;
  final String description;
  final Set<String> fields;
  final IconData icon;

  const _SuggestedFormUse({
    required this.name,
    required this.key,
    required this.description,
    required this.fields,
    required this.icon,
  });
}

const _suggestedFormUses = [
  _SuggestedFormUse(
    name: 'Contacto',
    key: 'contacto',
    description: 'Formulario breve para primer contacto.',
    fields: {'name', 'email', 'phone', 'message'},
    icon: Icons.person_outline_rounded,
  ),
  _SuggestedFormUse(
    name: 'Cotización',
    key: 'cotizacion',
    description: 'Solicita datos comerciales para preparar una propuesta.',
    fields: {'name', 'email', 'phone', 'company', 'budget', 'message'},
    icon: Icons.request_quote_outlined,
  ),
  _SuggestedFormUse(
    name: 'Agenda demo',
    key: 'agenda-demo',
    description: 'Captura interesados que quieren agendar una llamada.',
    fields: {'name', 'email', 'phone', 'company', 'date'},
    icon: Icons.event_available_outlined,
  ),
];

class _SuggestedUsePanel extends StatelessWidget {
  final ValueChanged<_SuggestedFormUse> onUse;

  const _SuggestedUsePanel({required this.onUse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Usos sugeridos',
            style: GoogleFonts.dmSans(
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ..._suggestedFormUses.map(
            (preset) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ExcludeFocus(
                child: TaploeOutlineButton(
                  label: preset.name,
                  icon: preset.icon,
                  onPressed: () => onUse(preset),
                  height: 44,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFieldsSelector extends StatelessWidget {
  final Set<String> selected;
  final bool loading;
  final void Function(String key, bool selected) onChanged;

  const _FormFieldsSelector({
    required this.selected,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campos incluidos',
            style: GoogleFonts.dmSans(
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Selecciona los datos que tendrá tu formulario.',
            style: GoogleFonts.dmSans(color: context.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _formFieldPresets.map((field) {
              final isSelected = selected.contains(field.key);
              return FilterChip(
                selected: isSelected,
                showCheckmark: false,
                avatar: Icon(
                  field.icon,
                  size: 18,
                  color: isSelected ? TaploeColors.blue : context.muted,
                ),
                label: Text(field.label),
                onSelected: (value) => onChanged(field.key, value),
                backgroundColor: TaploeColors.white,
                selectedColor: TaploeColors.white,
                checkmarkColor: TaploeColors.blue,
                labelStyle: GoogleFonts.dmSans(
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected ? TaploeColors.blue : TaploeColors.border,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
Future<void> _showFieldEditorDialog(
  BuildContext context, {
  required SmartFormModel form,
  int currentCount = 0,
}) async {
  var fieldType = 'text';
  var isRequired = false;
  final label = TextEditingController();
  final key = TextEditingController();
  final placeholder = TextEditingController();
  final help = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submitField() async {
            final cleanLabel = label.text.trim();
            if (cleanLabel.isEmpty) {
              taploeToast(context, 'Agrega etiqueta del campo.', error: true);
              return;
            }
            await SmartFormRepository.upsertField(
              formId: form.id,
              fieldKey: key.text.trim().isEmpty
                  ? slugify(cleanLabel).replaceAll('-', '_')
                  : slugify(key.text).replaceAll('-', '_'),
              fieldType: fieldType,
              label: cleanLabel,
              placeholder: placeholder.text.trim().isEmpty
                  ? null
                  : placeholder.text.trim(),
              helpText: help.text.trim().isEmpty ? null : help.text.trim(),
              isRequired: isRequired,
              sortOrder: currentCount + 1,
            );
            if (context.mounted) Navigator.pop(context);
          }

          return AlertDialog(
            backgroundColor: TaploeColors.page,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: const Text('Agregar campo'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.sizeOf(context).height * .72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: fieldType,
                      decoration: InputDecoration(
                        labelText: taploeLocalizeText(context, 'Tipo de campo'),
                      ),
                      items:
                          const [
                                'text',
                                'textarea',
                                'email',
                                'phone',
                                'number',
                                'select',
                                'multi_select',
                                'checkbox',
                                'date',
                                'file',
                              ]
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                      onChanged: (type) {
                        if (type != null) {
                          setDialogState(() => fieldType = type);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TaploeTextField(
                      label: 'Etiqueta',
                      controller: label,
                      hint: 'Correo electrónico',
                      onSubmitted: (_) => submitField(),
                    ),
                    const SizedBox(height: 12),
                    TaploeTextField(
                      label: 'Clave',
                      controller: key,
                      hint: 'email',
                      onSubmitted: (_) => submitField(),
                    ),
                    const SizedBox(height: 12),
                    TaploeTextField(
                      label: 'Placeholder',
                      controller: placeholder,
                      hint: 'da@ejemplo.com',
                      onSubmitted: (_) => submitField(),
                    ),
                    const SizedBox(height: 12),
                    TaploeTextField(
                      label: 'Texto de ayuda',
                      controller: help,
                      hint: 'Usaremos este correo para contactarte.',
                      onSubmitted: (_) => submitField(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isRequired,
                      title: const Text('Campo requerido'),
                      onChanged: (v) => setDialogState(() => isRequired = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: submitField,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showIntegrationEditorDialog(
  BuildContext context, {
  required DigitalProfileModel profile,
  ProfileIntegrationModel? integration,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) =>
        _IntegrationEditorModal(profile: profile, integration: integration),
  );
}

class _IntegrationEditorModal extends StatefulWidget {
  final DigitalProfileModel profile;
  final ProfileIntegrationModel? integration;

  const _IntegrationEditorModal({required this.profile, this.integration});

  @override
  State<_IntegrationEditorModal> createState() =>
      _IntegrationEditorModalState();
}

class _IntegrationEditorModalState extends State<_IntegrationEditorModal> {
  late String type;
  late final TextEditingController provider;
  late final TextEditingController url;
  late final TextEditingController label;
  late bool enabled;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final integration = widget.integration?.integration;
    type = integration?.integrationType ?? 'calendar';
    enabled = widget.integration?.isEnabled ?? true;
    provider = TextEditingController(text: integration?.provider ?? 'Calendly');
    url = TextEditingController(text: integration?.publicUrl ?? '');
    label = TextEditingController(
      text: widget.integration?.displayLabel ?? 'Agenda una reunión',
    );
  }

  @override
  void dispose() {
    provider.dispose();
    url.dispose();
    label.dispose();
    super.dispose();
  }

  void selectCategory(_IntegrationCategory category) {
    setState(() {
      type = category.type;
      provider.text = category.defaultProvider;
      label.text = category.defaultLabel;
      if (url.text.trim().isEmpty) url.text = category.hint;
    });
  }

  Future<void> save() async {
    final user = taploeState.currentUser;
    if (user == null) return;
    if (provider.text.trim().isEmpty || url.text.trim().isEmpty) {
      taploeToast(context, 'Completa proveedor y URL.', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      await IntegrationRepository.upsertProfileIntegration(
        profileIntegrationId: widget.integration?.id,
        integrationId: widget.integration?.integrationId,
        userId: user.id,
        profileId: widget.profile.id,
        integrationType: type,
        provider: provider.text.trim(),
        publicUrl: _ensureUrl(url.text),
        displayLabel: label.text.trim().isEmpty
            ? provider.text.trim()
            : label.text.trim(),
        isEnabled: enabled,
        sortOrder: widget.integration?.sortOrder ?? 0,
      );
      await taploeState.refreshProfiles();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _integrationCategories.firstWhere(
      (category) => category.type == type,
      orElse: () => _integrationCategories.first,
    );
    return TaploeModalShell(
      maxWidth: 760,
      title: widget.integration == null
          ? 'Agregar integración'
          : 'Editar integración',
      subtitle:
          'Conecta herramientas para mostrar agenda, capturar leads o enlazar servicios externos.',
      footer: TaploeModalFooter(
        primaryLabel: saving ? 'Guardando...' : 'Guardar',
        primaryIcon: Icons.save_outlined,
        onPrimary: saving ? null : save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 680;
              final categoryCards = _integrationCategories.map((category) {
                return TaploeSelectCard(
                  title: category.label,
                  subtitle: category.subtitle,
                  icon: category.icon,
                  selected: selected.type == category.type,
                  onTap: () => selectCategory(category),
                );
              }).toList();
              final categories = wide
                  ? Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final category in _integrationCategories)
                          SizedBox(
                            width: 190,
                            child: TaploeSelectCard(
                              title: category.label,
                              subtitle: category.subtitle,
                              icon: category.icon,
                              selected: selected.type == category.type,
                              onTap: () => selectCategory(category),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < categoryCards.length; i++) ...[
                          categoryCards[i],
                          if (i != categoryCards.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );
              final form = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaploeTextField(
                    label: 'Proveedor',
                    controller: provider,
                    hint: selected.defaultProvider,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (!saving) save();
                    },
                  ),
                  const SizedBox(height: 14),
                  TaploeTextField(
                    label: 'URL pública',
                    controller: url,
                    hint: selected.hint,
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) {
                      if (!saving) save();
                    },
                  ),
                  const SizedBox(height: 14),
                  TaploeTextField(
                    label: 'Etiqueta visible',
                    controller: label,
                    hint: selected.defaultLabel,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (!saving) save();
                    },
                  ),
                  const SizedBox(height: 14),
                  TaploeToggleRow(
                    title: 'Mostrar en perfil',
                    subtitle:
                        'Activa para que esta integración aparezca en tu tarjeta.',
                    icon: Icons.visibility_outlined,
                    value: enabled,
                    onChanged: (value) => setState(() => enabled = value),
                  ),
                ],
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [categories, const SizedBox(height: 18), form],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [categories, const SizedBox(height: 22), form],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IntegrationCategory {
  final String type;
  final String label;
  final String subtitle;
  final String defaultProvider;
  final String defaultLabel;
  final String hint;
  final IconData icon;

  const _IntegrationCategory({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.defaultProvider,
    required this.defaultLabel,
    required this.hint,
    required this.icon,
  });
}

const _integrationCategories = [
  _IntegrationCategory(
    type: 'calendar',
    label: 'Calendario',
    subtitle: 'Agenda reuniones',
    defaultProvider: 'Calendly',
    defaultLabel: 'Agenda una reunión',
    hint: 'https://calendly.com/taploe/demo',
    icon: Icons.calendar_month_outlined,
  ),
  _IntegrationCategory(
    type: 'crm',
    label: 'CRM',
    subtitle: 'Gestiona contactos',
    defaultProvider: 'HubSpot',
    defaultLabel: 'Enviar a CRM',
    hint: 'https://app.hubspot.com/contacts',
    icon: Icons.hub_outlined,
  ),
  _IntegrationCategory(
    type: 'webhook',
    label: 'Webhooks',
    subtitle: 'Automatiza eventos',
    defaultProvider: 'Webhook',
    defaultLabel: 'Enviar información',
    hint: 'https://hooks.zapier.com/hooks/catch/...',
    icon: Icons.webhook_outlined,
  ),
  _IntegrationCategory(
    type: 'other',
    label: 'Herramientas externas',
    subtitle: 'Servicios externos',
    defaultProvider: 'Herramienta externa',
    defaultLabel: 'Abrir herramienta',
    hint: 'https://',
    icon: Icons.extension_outlined,
  ),
];

class _CardsEmptyActivation extends StatelessWidget {
  const _CardsEmptyActivation();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          const Icon(
            Icons.credit_card_rounded,
            size: 34,
            color: TaploeColors.blue,
          ),
          const SizedBox(height: 14),
          Text(
            'Sin tarjetas',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: context.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega una tarjeta Taploe para vincular QR, NFC y perfil.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: TaploeButton(
              label: 'Vincular tarjeta',
              icon: Icons.qr_code_scanner_rounded,
              expanded: true,
              onPressed: () => _showCardLinkingDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkCardPromptPanel extends StatelessWidget {
  final bool compact;
  final bool embedded;

  const _LinkCardPromptPanel({this.compact = false, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final stacked = compact || MediaQuery.sizeOf(context).width < 980;
    final shopCard = const _TaploeShopPurchaseCard();
    final image = Image.asset(
      'assets/images/tarjeta-nfc.png',
      height: compact ? 108 : 132,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Icon(
        Icons.credit_card_rounded,
        color: TaploeColors.blue,
        size: compact ? 68 : 82,
      ),
    );
    final copy = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'Vincula tu tarjeta Taploe',
          textAlign: stacked ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.outfit(
            color: context.text,
            fontSize: compact ? 20 : 23,
            fontWeight: FontWeight.w600,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Conecta una tarjeta NFC o QR físico a tu perfil digital.',
          textAlign: stacked ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.dmSans(
            color: context.muted,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        TaploeButton(
          width: stacked ? double.infinity : 220,
          label: 'Vincular tarjeta',
          icon: Icons.qr_code_scanner_rounded,
          onPressed: () => _showCardLinkingDialog(context),
        ),
      ],
    );

    final content = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              image,
              SizedBox(height: compact ? 14 : 18),
              copy,
              if (!compact) ...[const SizedBox(height: 18), shopCard],
            ],
          )
        : Row(
            children: [
              SizedBox(width: 190, child: image),
              const SizedBox(width: 22),
              Expanded(child: copy),
              const SizedBox(width: 28),
              SizedBox(width: 470, child: shopCard),
            ],
          );

    if (embedded) {
      return Container(
        padding: EdgeInsets.all(compact ? 16 : 20),
        decoration: BoxDecoration(
          color: TaploeColors.page,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TaploeColors.border),
        ),
        child: content,
      );
    }

    return TaploePanel(
      radius: 22,
      padding: EdgeInsets.all(compact ? 18 : 22),
      child: content,
    );
  }
}

Future<void> _openTaploeShop() async {
  final uri = Uri.parse('https://taploe.com');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _TaploeShopPurchaseCard extends StatelessWidget {
  const _TaploeShopPurchaseCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openTaploeShop,
      child: Container(
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.fromLTRB(24, 20, 12, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE6FF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Aún no tienes tu tarjeta?',
                    style: GoogleFonts.outfit(
                      color: context.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Compra tu tarjeta NFC en taploe.com',
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Comprar ahora',
                        style: GoogleFonts.dmSans(
                          color: TaploeColors.blue,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: TaploeColors.blue,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Image.asset(
              'assets/images/taploe-shop.png',
              width: 172,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const Icon(
                Icons.shopping_cart_rounded,
                color: TaploeColors.blue,
                size: 64,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardManagerView extends StatefulWidget {
  const CardManagerView({super.key});

  @override
  State<CardManagerView> createState() => _CardManagerViewState();
}

class _CardManagerViewState extends State<CardManagerView> {
  bool loading = false;

  Future<void> changeProfile(PhysicalCardModel card, String profileId) async {
    final profile = taploeState.profiles.firstWhere((p) => p.id == profileId);
    final user = taploeState.currentUser;
    if (user == null) return;
    setState(() => loading = true);
    try {
      await CardRepository.changeActiveProfile(
        card: card,
        profile: profile,
        userId: user.id,
      );
      await taploeState.refreshCards();
      PhysicalCardModel? refreshedCard;
      for (final item in taploeState.cards) {
        if (item.id == card.id) {
          refreshedCard = item;
          break;
        }
      }
      if (refreshedCard?.activeProfileId != profile.id) {
        throw StateError(
          'No pudimos confirmar el cambio de perfil de la tarjeta.',
        );
      }
      if (!mounted) return;
      taploeToast(context, 'Tarjeta actualizada.');
    } catch (e) {
      safePrintError(e);
      if (!mounted) return;
      taploeToast(
        context,
        'No pudimos actualizar la tarjeta. ${_cardUpdateErrorHint(e)}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = taploeState.cards;
    final profiles = taploeState.profiles;
    final claimedCards = cards.where((card) => card.status == 'claimed').length;
    final connectedProfiles = cards
        .map((card) => card.activeProfileId)
        .whereType<String>()
        .toSet()
        .length;
    return PageShell(
      title: 'Tarjetas',
      subtitle: 'Administra tarjetas físicas, QR, NFC y perfil vinculado.',
      actions: [
        TaploeButton(
          width: 165,
          label: 'Nuevo perfil',
          icon: Icons.person_add_alt_1_rounded,
          iconColor: TaploeColors.blue,
          kind: TaploeButtonKind.secondary,
          onPressed: () => _showCreateProfileDialog(context),
        ),
        TaploeButton(
          width: 190,
          label: 'Vincular tarjeta',
          icon: Icons.add_rounded,
          onPressed: () => _showCardLinkingDialog(context),
        ),
      ],
      child: _CardsSection(
        cards: cards,
        profiles: profiles,
        claimedCards: claimedCards,
        connectedProfiles: connectedProfiles,
        loading: loading,
        onChangeProfile: changeProfile,
      ),
    );
  }
}

class RedirectManagerView extends StatefulWidget {
  const RedirectManagerView({super.key});

  @override
  State<RedirectManagerView> createState() => _RedirectManagerViewState();
}

enum _RedirectSortMode { nameAsc, genericUrlAsc, createdNewest, createdOldest }

class _RedirectManagerViewState extends State<RedirectManagerView> {
  bool loading = false;
  _RedirectSortMode sortMode = _RedirectSortMode.createdNewest;

  Future<void> _create({String? label, String? destinationUrl}) async {
    final user = taploeState.currentUser;
    if (user == null) return;
    setState(() => loading = true);
    try {
      await CardRedirectRepository.create(
        ownerUserId: user.id,
        label: label,
        destinationUrl: destinationUrl,
      );
      await taploeState.refreshCardRedirects();
      if (!mounted) return;
      taploeToast(context, 'URL generada.');
    } catch (error) {
      safePrintError(error);
      if (!mounted) return;
      taploeToast(context, 'No pudimos generar la URL.', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _claim(String value) async {
    setState(() => loading = true);
    try {
      final redirect = await CardRedirectRepository.claim(value);
      await taploeState.refreshCardRedirects();
      if (!mounted) return;
      if (redirect == null) {
        taploeToast(
          context,
          'No encontramos una URL disponible para vincular.',
          error: true,
        );
        return;
      }
      taploeToast(context, 'URL vinculada.');
    } catch (error) {
      safePrintError(error);
      if (!mounted) return;
      taploeToast(context, 'No pudimos vincular la URL.', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save(CardRedirectModel redirect) async {
    setState(() => loading = true);
    try {
      await CardRedirectRepository.save(redirect);
      await taploeState.refreshCardRedirects();
      if (!mounted) return;
      taploeToast(context, 'Redirección actualizada.');
    } catch (error) {
      safePrintError(error);
      if (!mounted) return;
      taploeToast(
        context,
        'No pudimos actualizar la redirección.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final redirects = taploeState.cardRedirects;
    final sortedRedirects = [...redirects]
      ..sort((a, b) => _compareRedirects(a, b, sortMode));
    final activeRedirects = redirects.where((item) => item.isActive).length;
    final totalClicks = redirects.fold<int>(
      0,
      (total, item) => total + item.clickCount,
    );

    return PageShell(
      title: 'Redirección',
      subtitle: 'Genera URLs programables y cambia su destino cuando quieras.',
      actions: [
        TaploeButton(
          width: 170,
          label: 'Vincular URL',
          icon: Icons.link_rounded,
          kind: TaploeButtonKind.secondary,
          onPressed: loading
              ? null
              : () => _showClaimRedirectSheet(context, onClaim: _claim),
        ),
        TaploeButton(
          width: 170,
          label: 'Generar URL',
          icon: Icons.add_link_rounded,
          loading: loading,
          onPressed: () => _showCreateRedirectSheet(context, onCreate: _create),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _CaptureFormMetric(
                  icon: Icons.alt_route_rounded,
                  value: '${redirects.length}',
                  label: 'URLs creadas',
                ),
                _CaptureFormMetric(
                  icon: Icons.radio_button_checked_rounded,
                  value: '$activeRedirects',
                  label: 'Activas',
                ),
                _CaptureFormMetric(
                  icon: Icons.ads_click_rounded,
                  value: '$totalClicks',
                  label: 'Redirecciones',
                ),
              ];
              if (constraints.maxWidth < 680) {
                return Wrap(spacing: 28, runSpacing: 22, children: metrics);
              }
              return Row(
                children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    Expanded(child: metrics[i]),
                    if (i != metrics.length - 1)
                      Container(
                        width: 1,
                        height: 54,
                        margin: const EdgeInsets.symmetric(horizontal: 22),
                        color: TaploeColors.border,
                      ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Divider(color: TaploeColors.border),
          const SizedBox(height: 18),
          if (redirects.isEmpty)
            const _RedirectsEmptyState()
          else ...[
            Align(
              alignment: Alignment.centerRight,
              child: _RedirectSortMenu(
                value: sortMode,
                onChanged: (value) => setState(() => sortMode = value),
              ),
            ),
            const SizedBox(height: 18),
            ...sortedRedirects.map(
              (redirect) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _RedirectRow(
                  redirect: redirect,
                  loading: loading,
                  onSave: _save,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

int _compareRedirects(
  CardRedirectModel a,
  CardRedirectModel b,
  _RedirectSortMode mode,
) {
  switch (mode) {
    case _RedirectSortMode.nameAsc:
      return _compareText(a.label, b.label);
    case _RedirectSortMode.genericUrlAsc:
      return _compareText(a.publicUrl, b.publicUrl);
    case _RedirectSortMode.createdOldest:
      return _compareDates(a.createdAt, b.createdAt);
    case _RedirectSortMode.createdNewest:
      return _compareDates(b.createdAt, a.createdAt);
  }
}

int _compareText(String a, String b) =>
    a.trim().toLowerCase().compareTo(b.trim().toLowerCase());

int _compareDates(DateTime? a, DateTime? b) {
  final left = a ?? DateTime.fromMillisecondsSinceEpoch(0);
  final right = b ?? DateTime.fromMillisecondsSinceEpoch(0);
  return left.compareTo(right);
}

String _redirectSortLabel(_RedirectSortMode mode) {
  switch (mode) {
    case _RedirectSortMode.nameAsc:
      return 'Nombre A-Z';
    case _RedirectSortMode.genericUrlAsc:
      return 'Generic URL A-Z';
    case _RedirectSortMode.createdNewest:
      return 'Más recientes';
    case _RedirectSortMode.createdOldest:
      return 'Más antiguos';
  }
}

String _redirectSortEnglishLabel(_RedirectSortMode mode) {
  switch (mode) {
    case _RedirectSortMode.nameAsc:
      return 'Name A-Z';
    case _RedirectSortMode.genericUrlAsc:
      return 'Generic URL A-Z';
    case _RedirectSortMode.createdNewest:
      return 'Newest';
    case _RedirectSortMode.createdOldest:
      return 'Oldest';
  }
}

class _RedirectSortMenu extends StatelessWidget {
  final _RedirectSortMode value;
  final ValueChanged<_RedirectSortMode> onChanged;

  const _RedirectSortMenu({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = TaploeTextScope.of(context);
    return PopupMenuButton<_RedirectSortMode>(
      tooltip: 'Ordenar',
      offset: const Offset(0, 10),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final mode in _RedirectSortMode.values)
          PopupMenuItem(
            value: mode,
            child: Row(
              children: [
                Icon(
                  value == mode
                      ? Icons.check_rounded
                      : Icons.sort_by_alpha_rounded,
                  size: 18,
                  color: value == mode ? TaploeColors.blue : context.muted,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_redirectSortLabel(mode))),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TaploeColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: TaploeColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18),
            const SizedBox(width: 8),
            Text(
              t.text(
                'Ordenar: ${_redirectSortLabel(value)}',
                'Sort: ${_redirectSortEnglishLabel(value)}',
              ),
              style: GoogleFonts.dmSans(
                color: context.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RedirectsEmptyState extends StatelessWidget {
  const _RedirectsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.alt_route_rounded,
            color: TaploeColors.blue,
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            'Genera tu primera URL programable.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Puedes grabarla en una tarjeta NFC o imprimirla en QR y cambiar el destino después.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _RedirectRow extends StatelessWidget {
  final CardRedirectModel redirect;
  final bool loading;
  final Future<void> Function(CardRedirectModel redirect) onSave;

  const _RedirectRow({
    required this.redirect,
    required this.loading,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TaploeColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          final header = Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                color: TaploeColors.blue,
                size: 28,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      redirect.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: context.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _RedirectStatusPill(redirect: redirect),
                  ],
                ),
              ),
            ],
          );
          final details = _RedirectDetailsPanel(
            redirect: redirect,
            loading: loading,
            onSave: onSave,
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const SizedBox(height: 18), details],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: header),
              const SizedBox(width: 26),
              Expanded(flex: 5, child: details),
            ],
          );
        },
      ),
    );
  }
}

class _RedirectStatusPill extends StatelessWidget {
  final CardRedirectModel redirect;

  const _RedirectStatusPill({required this.redirect});

  @override
  Widget build(BuildContext context) {
    final active = redirect.isActive;
    final label = redirect.status == 'draft'
        ? 'Sin destino'
        : active
        ? 'Activa'
        : 'Inactiva';
    final color = active
        ? TaploeColors.success
        : redirect.status == 'draft'
        ? TaploeColors.blue
        : context.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RedirectDetailsPanel extends StatelessWidget {
  final CardRedirectModel redirect;
  final bool loading;
  final Future<void> Function(CardRedirectModel redirect) onSave;

  const _RedirectDetailsPanel({
    required this.redirect,
    required this.loading,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final destination = redirect.destinationUrl?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _CardAccessLine(
                icon: Icons.link_rounded,
                title: 'URL genérica',
                value: redirect.publicUrl,
                onOpen: () => _openUrl(context, redirect.publicUrl),
              ),
            ),
            IconButton(
              tooltip: 'Copiar URL',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: redirect.publicUrl));
                taploeToast(context, 'URL copiada.');
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.near_me_rounded,
              color: redirect.isActive ? TaploeColors.success : context.muted,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Destino',
                    style: GoogleFonts.dmSans(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    destination?.isNotEmpty == true
                        ? destination!
                        : 'Configura un destino para activar esta URL.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${redirect.clickCount} redirecciones',
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Switch.adaptive(
              value: redirect.isActive,
              onChanged: loading || !redirect.hasDestination
                  ? null
                  : (value) => onSave(_copyRedirect(redirect, active: value)),
            ),
            IconButton(
              tooltip: 'Editar destino',
              onPressed: loading
                  ? null
                  : () => _showRedirectEditor(context, redirect, onSave),
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _CreateRedirectSheet extends StatefulWidget {
  final Future<void> Function({String? label, String? destinationUrl}) onCreate;

  const _CreateRedirectSheet({required this.onCreate});

  @override
  State<_CreateRedirectSheet> createState() => _CreateRedirectSheetState();
}

class _CreateRedirectSheetState extends State<_CreateRedirectSheet> {
  late final TextEditingController label;
  late final TextEditingController destination;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    label = TextEditingController(text: 'Taploe redirect card');
    destination = TextEditingController();
  }

  @override
  void dispose() {
    label.dispose();
    destination.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final normalizedDestination = normalizeRedirectDestinationOrNull(
      destination.text,
    );
    if (normalizedDestination != null &&
        !_isValidRedirectDestination(normalizedDestination)) {
      taploeToast(context, 'Ingresa una URL válida.', error: true);
      return;
    }
    if (normalizedDestination != null &&
        _isTaploeRedirectLoop(normalizedDestination)) {
      taploeToast(
        context,
        'No puedes redirigir una URL genérica a otra URL genérica.',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    await widget.onCreate(
      label: label.text,
      destinationUrl: normalizedDestination,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _RedirectBottomSheet(
      title: 'Generar URL',
      actionLabel: 'Generar URL',
      loading: saving,
      onSubmit: _create,
      children: [
        TaploeTextField(
          label: 'Nombre interno',
          controller: label,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        TaploeTextField(
          label: 'Destino',
          hint: 'https://example.com',
          helperText: 'Puedes dejarlo vacío y configurarlo después.',
          controller: destination,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _create(),
        ),
      ],
    );
  }
}

class _ClaimRedirectSheet extends StatefulWidget {
  final Future<void> Function(String value) onClaim;

  const _ClaimRedirectSheet({required this.onClaim});

  @override
  State<_ClaimRedirectSheet> createState() => _ClaimRedirectSheetState();
}

class _ClaimRedirectSheetState extends State<_ClaimRedirectSheet> {
  late final TextEditingController url;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    url = TextEditingController();
  }

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (redirectSlugFromInput(url.text).length < 3) {
      taploeToast(context, 'Ingresa una URL válida.', error: true);
      return;
    }
    setState(() => saving = true);
    await widget.onClaim(url.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _RedirectBottomSheet(
      title: 'Vincular URL',
      actionLabel: 'Vincular URL',
      loading: saving,
      onSubmit: _claim,
      children: [
        TaploeTextField(
          label: 'URL o código',
          hint: 'https://app.taploe.com/r/card-xxxxxx',
          controller: url,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _claim(),
        ),
      ],
    );
  }
}

Future<void> _showRedirectEditor(
  BuildContext context,
  CardRedirectModel redirect,
  Future<void> Function(CardRedirectModel redirect) onSave,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _RedirectEditorSheet(redirect: redirect, onSave: onSave),
  );
}

Future<void> _showCreateRedirectSheet(
  BuildContext context, {
  required Future<void> Function({String? label, String? destinationUrl})
  onCreate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CreateRedirectSheet(onCreate: onCreate),
  );
}

Future<void> _showClaimRedirectSheet(
  BuildContext context, {
  required Future<void> Function(String value) onClaim,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ClaimRedirectSheet(onClaim: onClaim),
  );
}

class _RedirectEditorSheet extends StatefulWidget {
  final CardRedirectModel redirect;
  final Future<void> Function(CardRedirectModel redirect) onSave;

  const _RedirectEditorSheet({required this.redirect, required this.onSave});

  @override
  State<_RedirectEditorSheet> createState() => _RedirectEditorSheetState();
}

class _RedirectEditorSheetState extends State<_RedirectEditorSheet> {
  late final TextEditingController label;
  late final TextEditingController destination;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    label = TextEditingController(text: widget.redirect.label);
    destination = TextEditingController(
      text: widget.redirect.destinationUrl ?? '',
    );
  }

  @override
  void dispose() {
    label.dispose();
    destination.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalizedDestination = normalizeRedirectDestinationOrNull(
      destination.text,
    );
    if (normalizedDestination == null ||
        !_isValidRedirectDestination(normalizedDestination)) {
      taploeToast(context, 'Ingresa una URL válida.', error: true);
      return;
    }
    if (_isTaploeRedirectLoop(normalizedDestination)) {
      taploeToast(
        context,
        'No puedes redirigir una URL genérica a otra URL genérica.',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    await widget.onSave(
      CardRedirectModel(
        id: widget.redirect.id,
        ownerUserId: widget.redirect.ownerUserId,
        slug: widget.redirect.slug,
        label: label.text.trim().isEmpty
            ? 'Taploe redirect card'
            : label.text.trim(),
        destinationUrl: normalizedDestination,
        status: widget.redirect.status == 'inactive' ? 'inactive' : 'active',
        clickCount: widget.redirect.clickCount,
        lastClickedAt: widget.redirect.lastClickedAt,
        claimedAt: widget.redirect.claimedAt,
        metadata: widget.redirect.metadata,
        createdAt: widget.redirect.createdAt,
        updatedAt: widget.redirect.updatedAt,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _RedirectBottomSheet(
      title: 'Editar redirección',
      actionLabel: 'Guardar cambios',
      loading: saving,
      onSubmit: _save,
      children: [
        TaploeTextField(
          label: 'Nombre interno',
          controller: label,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        TaploeTextField(
          label: 'Destino',
          hint: 'https://example.com',
          controller: destination,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}

class _RedirectBottomSheet extends StatelessWidget {
  final String title;
  final String actionLabel;
  final List<Widget> children;
  final bool loading;
  final VoidCallback onSubmit;

  const _RedirectBottomSheet({
    required this.title,
    required this.actionLabel,
    required this.children,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        decoration: const BoxDecoration(
          color: TaploeColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: context.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 18),
              TaploeButton(
                label: actionLabel,
                icon: Icons.save_rounded,
                loading: loading,
                onPressed: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

CardRedirectModel _copyRedirect(
  CardRedirectModel redirect, {
  bool? active,
  String? label,
  String? destinationUrl,
}) {
  final cleanDestination = destinationUrl ?? redirect.destinationUrl?.trim();
  final hasDestination = cleanDestination?.isNotEmpty == true;
  final shouldBeActive = active ?? redirect.status != 'inactive';
  final nextStatus = hasDestination
      ? (shouldBeActive ? 'active' : 'inactive')
      : 'draft';
  return CardRedirectModel(
    id: redirect.id,
    ownerUserId: redirect.ownerUserId,
    slug: redirect.slug,
    label: label ?? redirect.label,
    destinationUrl: cleanDestination,
    status: nextStatus,
    clickCount: redirect.clickCount,
    lastClickedAt: redirect.lastClickedAt,
    claimedAt: redirect.claimedAt,
    metadata: redirect.metadata,
    createdAt: redirect.createdAt,
    updatedAt: redirect.updatedAt,
  );
}

bool _isValidRedirectDestination(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.trim().isNotEmpty;
}

bool _isTaploeRedirectLoop(String value) {
  final uri = Uri.tryParse(value);
  final base = Uri.tryParse(TaploeConfig.publicBaseUrl);
  if (uri == null || base == null) return false;
  return uri.host == base.host && uri.path.startsWith('/r/');
}

Future<void> _openUrl(BuildContext context, String url) async {
  if (!await redirectToDestination(url)) {
    if (context.mounted) {
      taploeToast(context, 'No se pudo abrir el enlace.', error: true);
    }
  }
}

class _CardsSection extends StatelessWidget {
  final List<PhysicalCardModel> cards;
  final List<DigitalProfileModel> profiles;
  final int claimedCards;
  final int connectedProfiles;
  final bool loading;
  final Future<void> Function(PhysicalCardModel card, String profileId)
  onChangeProfile;

  const _CardsSection({
    required this.cards,
    required this.profiles,
    required this.claimedCards,
    required this.connectedProfiles,
    required this.loading,
    required this.onChangeProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final metrics = [
              _CaptureFormMetric(
                icon: Icons.credit_card_rounded,
                value: '${cards.length}',
                label: 'Tarjetas',
              ),
              _CaptureFormMetric(
                icon: Icons.verified_user_outlined,
                value: '$claimedCards',
                label: 'Activadas',
              ),
              _CaptureFormMetric(
                icon: Icons.group_outlined,
                value: '$connectedProfiles',
                label: 'Perfiles conectados',
              ),
            ];
            if (constraints.maxWidth < 680) {
              return Wrap(spacing: 28, runSpacing: 22, children: metrics);
            }
            return Row(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  Expanded(child: metrics[i]),
                  if (i != metrics.length - 1)
                    Container(
                      width: 1,
                      height: 54,
                      margin: const EdgeInsets.symmetric(horizontal: 22),
                      color: TaploeColors.border,
                    ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _CardsShopPurchasePanel(),
        const SizedBox(height: 24),
        Divider(color: TaploeColors.border),
        const SizedBox(height: 18),
        if (cards.isEmpty)
          const _CardsEmptyActivation()
        else
          ...cards.map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _PhysicalCardRow(
                card: card,
                profiles: profiles,
                loading: loading,
                onChangeProfile: onChangeProfile,
              ),
            ),
          ),
      ],
    );
  }
}

class _CardsShopPurchasePanel extends StatelessWidget {
  const _CardsShopPurchasePanel();

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.sizeOf(context).width < 760;

    final copy = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          '¿Aún no tienes tu tarjeta?',
          textAlign: stacked ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.outfit(
            color: context.text,
            fontSize: stacked ? 24 : 28,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Compra tu tarjeta NFC en taploe.com y vincúlala a tu perfil digital.',
          textAlign: stacked ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.dmSans(
            color: context.muted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        TaploeButton(
          label: 'Comprar ahora',
          icon: Icons.open_in_new_rounded,
          width: stacked ? double.infinity : 190,
          kind: TaploeButtonKind.secondary,
          onPressed: _openTaploeShop,
        ),
      ],
    );

    final image = Image.asset(
      'assets/images/taploe-shop.png',
      width: stacked ? 190 : 240,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Icon(
        Icons.shopping_cart_rounded,
        color: TaploeColors.blue,
        size: stacked ? 78 : 96,
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        stacked ? 20 : 28,
        stacked ? 20 : 18,
        stacked ? 20 : 24,
        stacked ? 22 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [image, const SizedBox(height: 16), copy],
            )
          : Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 28),
                image,
              ],
            ),
    );
  }
}

String _cardUpdateErrorHint(Object error) {
  final message = error.toString();
  if (message.contains('change_card_active_profile rpc failed')) {
    return 'Revisa la función change_card_active_profile.';
  }
  if (message.contains('physical_cards update failed')) {
    return 'Revisa la policy UPDATE de physical_cards.';
  }
  if (message.contains('profile_access_points update failed')) {
    return 'Revisa la policy UPDATE de profile_access_points.';
  }
  if (message.contains('physical_card_assignments insert failed')) {
    return 'Revisa la policy INSERT de physical_card_assignments.';
  }
  if (message.contains('confirmar el cambio')) {
    return 'El cambio no se reflejó al refrescar.';
  }
  return 'Intenta de nuevo.';
}

class _PhysicalCardRow extends StatelessWidget {
  static const _newProfileValue = '__new_profile__';
  static const _dividerValue = '__profile_divider__';

  final PhysicalCardModel card;
  final List<DigitalProfileModel> profiles;
  final bool loading;
  final Future<void> Function(PhysicalCardModel card, String profileId)
  onChangeProfile;

  const _PhysicalCardRow({
    required this.card,
    required this.profiles,
    required this.loading,
    required this.onChangeProfile,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownValue = profiles.any((p) => p.id == card.activeProfileId)
        ? card.activeProfileId
        : null;
    DigitalProfileModel? activeProfile;
    for (final profile in profiles) {
      if (profile.id == card.activeProfileId) {
        activeProfile = profile;
        break;
      }
    }
    final shareUrl = activeProfile == null
        ? null
        : TaploeConfig.profileUrl(activeProfile.publicSlug);
    final stacked = MediaQuery.sizeOf(context).width < 820;
    final canCreateProfile = taploeState.capabilities.canCreateProfile(
      profiles.length,
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.productLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: context.text,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _CardStatusPill(status: card.status),
        const SizedBox(height: 28),
        Text(
          'Perfil vinculado',
          style: GoogleFonts.dmSans(
            color: context.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.person_outline_rounded,
              color: TaploeColors.black,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: dropdownValue,
                  isExpanded: true,
                  hint: Text(
                    activeProfile?.displayName ?? 'Sin perfil',
                    overflow: TextOverflow.ellipsis,
                  ),
                  items: profiles
                      .map<DropdownMenuItem<String>>(
                        (profile) => DropdownMenuItem<String>(
                          value: profile.id,
                          child: Text(
                            profile.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .followedBy([
                        const DropdownMenuItem<String>(
                          value: _dividerValue,
                          enabled: false,
                          child: Divider(height: 1),
                        ),
                        DropdownMenuItem<String>(
                          value: _newProfileValue,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: TaploeColors.blue,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Crear nuevo perfil')),
                              if (!canCreateProfile)
                                const FaIcon(
                                  FontAwesomeIcons.crown,
                                  color: Color(0xFF9CA3AF),
                                  size: 13,
                                ),
                            ],
                          ),
                        ),
                      ])
                      .toList(),
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value == null || value == _dividerValue) return;
                          if (value == _newProfileValue) {
                            _showCreateProfileDialog(
                              context,
                              assignToCard: card,
                            );
                            return;
                          }
                          onChangeProfile(card, value);
                        },
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final access = Column(
      children: [
        _CardAccessLine(
          icon: Icons.ios_share_rounded,
          title: 'URL para compartir contacto',
          value: shareUrl ?? 'Sin perfil vinculado',
          onOpen: shareUrl == null
              ? null
              : () => _openShareUrl(context, shareUrl),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: stacked ? 0 : 16,
        vertical: stacked ? 18 : 20,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TaploeColors.border)),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardProductImage(card: card),
                const SizedBox(height: 18),
                details,
                const SizedBox(height: 22),
                access,
              ],
            )
          : Row(
              children: [
                SizedBox(width: 250, child: _CardProductImage(card: card)),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: details),
                Container(
                  width: 1,
                  height: 156,
                  margin: const EdgeInsets.symmetric(horizontal: 34),
                  color: TaploeColors.border,
                ),
                Expanded(flex: 5, child: access),
                IconButton(
                  tooltip: 'Más opciones',
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
    );
  }

  Future<void> _openShareUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        taploeToast(context, 'No se pudo abrir el enlace.', error: true);
      }
    }
  }
}

class _CardProductImage extends StatelessWidget {
  final PhysicalCardModel card;

  const _CardProductImage({required this.card});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _cardImageAsset(card),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const Icon(
        Icons.credit_card_rounded,
        color: TaploeColors.blue,
        size: 90,
      ),
    );
  }
}

class _CardStatusPill extends StatelessWidget {
  final String status;

  const _CardStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status == 'claimed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? TaploeColors.success.withValues(alpha: .12)
            : TaploeColors.page,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.circle : Icons.schedule_rounded,
            size: active ? 9 : 13,
            color: active ? TaploeColors.success : TaploeColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Activada' : status,
            style: GoogleFonts.dmSans(
              color: active ? TaploeColors.success : context.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAccessLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onOpen;

  const _CardAccessLine({
    required this.icon,
    required this.title,
    required this.value,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: TaploeColors.blue, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded, size: 15),
          label: const Text('Ver'),
          style: OutlinedButton.styleFrom(
            foregroundColor: TaploeColors.black,
            side: const BorderSide(color: TaploeColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

String _cardImageAsset(PhysicalCardModel card) {
  return _isMetalCard(card)
      ? 'assets/images/tarjeta-nfc-metalica.png'
      : 'assets/images/tarjeta-nfc.png';
}

bool _isMetalCard(PhysicalCardModel card) {
  final source =
      [
            card.productTypeName,
            card.productTypeCode,
            card.metadata['product_name'],
            card.metadata['product_type'],
            card.metadata['material'],
          ]
          .whereType<Object>()
          .map((value) => value.toString().toLowerCase())
          .join(' ');
  return source.contains('metal') || source.contains('metálica');
}

class ShareCenterView extends StatefulWidget {
  const ShareCenterView({super.key});

  @override
  State<ShareCenterView> createState() => _ShareCenterViewState();
}

class _ShareCenterViewState extends State<ShareCenterView> {
  AnalyticsSummaryModel? summary;
  bool loading = true;
  String? _profileId;

  @override
  void initState() {
    super.initState();
    load();
    taploeState.addListener(_handleTaploeStateChanged);
  }

  @override
  void dispose() {
    taploeState.removeListener(_handleTaploeStateChanged);
    super.dispose();
  }

  void _handleTaploeStateChanged() {
    final nextProfileId = taploeState.activeProfile?.id;
    if (nextProfileId != _profileId) load();
  }

  Future<void> load() async {
    final profile = taploeState.activeProfile;
    _profileId = profile?.id;
    if (profile == null) {
      if (mounted) {
        setState(() {
          summary = null;
          loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => loading = true);
    final result = await Future.wait<Object>([
      AnalyticsRepository.fetchSummary(profile.id),
    ]);
    if (taploeState.activeProfile?.id != profile.id) return;
    if (!mounted) return;
    setState(() {
      summary = result[0] as AnalyticsSummaryModel;
      loading = false;
    });
  }

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        taploeToast(context, 'No se pudo abrir el enlace.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = taploeState.activeProfile;
    final publicUrl = profile == null
        ? ''
        : TaploeConfig.profileUrl(profile.publicSlug);
    final data = summary;
    return PageShell(
      title: 'Compartir',
      subtitle:
          'Distribuye tu perfil digital, QR y contacto desde un centro único.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
          ? const TaploeEmpty(
              title: 'Sin perfil para compartir',
              message:
                  'Crea o activa un perfil digital para generar tu enlace.',
              icon: Icons.ios_share_rounded,
            )
          : _ResponsivePair(
              breakpoint: 980,
              leftFlex: 5,
              rightFlex: 4,
              left: Column(
                children: [
                  TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Centro de distribución',
                          icon: Icons.hub_outlined,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Presenta tu perfil y compártelo desde un solo lugar.',
                          style: GoogleFonts.dmSans(color: context.muted),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: context.isWide ? 3 : 1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: context.isWide ? 1.6 : 3.2,
                          children: [
                            _MiniStat(
                              label: 'Taps NFC',
                              value: '${data?.nfcViews ?? 0}',
                              icon: Icons.nfc_rounded,
                            ),
                            _MiniStat(
                              label: 'QR scans',
                              value: '${data?.qrViews ?? 0}',
                              icon: Icons.qr_code_rounded,
                            ),
                            _MiniStat(
                              label: 'Esta semana',
                              value:
                                  '+${data?.viewsByDay.fold<int>(0, (a, b) => a + b) ?? 0}',
                              icon: Icons.calendar_today_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              color: TaploeColors.success,
                              size: 10,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                publicUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  color: context.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Compartir contacto',
                          icon: Icons.share_outlined,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Administra el enlace principal y distribúyelo desde aquí.',
                          style: GoogleFonts.dmSans(color: context.muted),
                        ),
                        const SizedBox(height: 16),
                        _CopyRow(
                          label: 'Enlace público',
                          value: publicUrl,
                          onCopied: () =>
                              taploeToast(context, 'Enlace copiado.'),
                        ),
                        const SizedBox(height: 16),
                        _PanelHeader(
                          title: 'Canales de envío',
                          icon: Icons.send_outlined,
                        ),
                        const SizedBox(height: 10),
                        _ActionCard(
                          title: 'WhatsApp',
                          subtitle: 'Enviar enlace por WhatsApp.',
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: () => _open(
                            Uri.parse(
                              'https://wa.me/?text=${Uri.encodeComponent(publicUrl)}',
                            ),
                          ),
                        ),
                        _ActionCard(
                          title: 'Email',
                          subtitle: 'Preparar correo con tu enlace.',
                          icon: Icons.mail_outline_rounded,
                          onTap: () => _open(
                            Uri(
                              scheme: 'mailto',
                              query:
                                  'subject=${Uri.encodeComponent('Mi perfil Taploe')}&body=${Uri.encodeComponent(publicUrl)}',
                            ),
                          ),
                        ),
                        _ActionCard(
                          title: 'Copiar vCard',
                          subtitle: 'Copiar contacto en formato VCF.',
                          icon: Icons.contact_page_outlined,
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(
                                text:
                                    profile.vcard?.toVcf(
                                      displayName: profile.displayName,
                                      profilePhotoUrl: profile.profilePhotoUrl,
                                    ) ??
                                    '',
                              ),
                            );
                            taploeToast(context, 'vCard copiada.');
                          },
                        ),
                        const SizedBox(height: 14),
                        if (!taploeState.hasLinkedCard) ...[
                          const _LinkCardPromptPanel(
                            compact: true,
                            embedded: true,
                          ),
                          const SizedBox(height: 14),
                        ],
                        PwaInstallPanel(profile: profile, compact: true),
                      ],
                    ),
                  ),
                ],
              ),
              right: Column(
                children: [
                  TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Código QR ejecutivo',
                          icon: Icons.qr_code_2_rounded,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'QR generado con tu enlace público.',
                          style: GoogleFonts.dmSans(color: context.muted),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: TaploeColors.border),
                            ),
                            child: QrImageView(
                              data: publicUrl,
                              version: QrVersions.auto,
                              size: 210,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: TaploeColors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: TaploeColors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            publicUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(color: context.muted),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TaploeButton(
                          label: 'Copiar enlace público',
                          icon: Icons.copy_rounded,
                          kind: TaploeButtonKind.secondary,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: publicUrl));
                            taploeToast(context, 'Enlace público copiado.');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class AnalyticsDashboardView extends StatefulWidget {
  const AnalyticsDashboardView({super.key});

  @override
  State<AnalyticsDashboardView> createState() => _AnalyticsDashboardViewState();
}

class _AnalyticsDashboardViewState extends State<AnalyticsDashboardView> {
  AnalyticsSummaryModel? data;
  List<AnalyticsEventModel> events = const [];
  List<TeamMemberModel> members = const [];
  bool loading = true;
  String? _profileId;
  String _memberFilter = 'all';

  @override
  void initState() {
    super.initState();
    load();
    taploeState.addListener(_handleTaploeStateChanged);
  }

  @override
  void dispose() {
    taploeState.removeListener(_handleTaploeStateChanged);
    super.dispose();
  }

  void _handleTaploeStateChanged() {
    final nextProfileId = taploeState.activeProfile?.id;
    if (nextProfileId != _profileId) load();
  }

  Future<void> load() async {
    final p = taploeState.activeProfile;
    final org = taploeState.organization;
    final currentUser = taploeState.currentUser;
    _profileId = p?.id;
    if (org == null && p == null) {
      if (mounted) {
        setState(() {
          data = null;
          events = const [];
          members = const [];
          loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => loading = true);
    late final List<Object> result;
    if (org != null) {
      final team = await TeamRepository.fetchTeam(org.id);
      final currentMember = _currentActiveTeamMember(team, currentUser?.id);
      final canViewMemberData = _canViewTeamMemberData(currentMember?.role);
      final selectedOwner = canViewMemberData
          ? (_memberFilter == 'all' ? null : _memberFilter)
          : currentUser?.id;
      final profileIds = selectedOwner == null && !canViewMemberData
          ? <String>[]
          : await TeamRepository.fetchProfileIdsForOrg(
              org.id,
              ownerUserId: selectedOwner,
            );
      result = await Future.wait<Object>([
        Future.value(team),
        AnalyticsRepository.fetchSummaryForProfiles(profileIds),
        AnalyticsRepository.fetchRecentEventsForProfiles(profileIds, limit: 8),
      ]);
    } else {
      result = await Future.wait<Object>([
        Future.value(<TeamMemberModel>[]),
        AnalyticsRepository.fetchSummary(p!.id),
        AnalyticsRepository.fetchRecentEvents(p.id, limit: 8),
      ]);
    }
    if (org == null && taploeState.activeProfile?.id != p?.id) return;
    if (mounted) {
      final nextMembers = result[0] as List<TeamMemberModel>;
      final currentMember = _currentActiveTeamMember(
        nextMembers,
        currentUser?.id,
      );
      final canViewMemberData = _canViewTeamMemberData(currentMember?.role);
      final selectedStillExists =
          _memberFilter == 'all' ||
          nextMembers.any(
            (member) => !member.isPending && member.id == _memberFilter,
          );
      setState(() {
        members = nextMembers;
        if (!canViewMemberData || !selectedStillExists) _memberFilter = 'all';
        data = result[1] as AnalyticsSummaryModel;
        events = result[2] as List<AnalyticsEventModel>;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final canViewMemberData = _canViewTeamMemberData(
      _currentActiveTeamMember(members, taploeState.currentUser?.id)?.role,
    );
    final activeMembers = members.where((member) => !member.isPending).toList();
    final interactions = d == null
        ? 0
        : d.profileViews + d.linkClicks + d.contactsSaved + d.formSubmits;
    return PageShell(
      title: 'Analítica',
      subtitle: taploeState.organization == null
          ? 'Mide visitas por NFC, QR, link directo, clicks y formularios.'
          : 'Mide el rendimiento general o filtrado por miembro del equipo.',
      actions: taploeState.organization == null || !canViewMemberData
          ? const []
          : [
              _TeamMemberFilter(
                members: activeMembers,
                value: _memberFilter,
                onChanged: (value) {
                  setState(() => _memberFilter = value);
                  load();
                },
              ),
            ],
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TaploeEmpty(
                  title: 'Sin perfil seleccionado',
                  message: 'Selecciona o crea un perfil para ver analítica.',
                ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1040;
                final main = Column(
                  children: [
                    _AnalyticsHeroCard(total: interactions),
                    const SizedBox(height: 16),
                    _AnalyticsMetricStrip(
                      items: [
                        _AnalyticsMetricData(
                          label: 'Visitas',
                          value: d.profileViews,
                          icon: Icons.visibility_outlined,
                        ),
                        _AnalyticsMetricData(
                          label: 'Taps NFC',
                          value: d.nfcViews,
                          icon: Icons.nfc_rounded,
                        ),
                        _AnalyticsMetricData(
                          label: 'Clicks',
                          value: d.linkClicks,
                          icon: Icons.ads_click_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TaploePanel(
                      radius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Visitas por día',
                                  style: GoogleFonts.outfit(
                                    color: context.text,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${d.viewsByDay.fold<int>(0, (a, b) => a + b)} en el rango',
                                style: GoogleFonts.dmSans(
                                  color: context.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const _AnalyticsDeltaPill(label: '+0.0%'),
                            ],
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 300,
                            child: _ViewsBarChart(values: d.viewsByDay),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TaploePanel(
                      radius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Links más clickeados',
                                  style: GoogleFonts.outfit(
                                    color: context.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${d.linkClicks} clicks totales',
                                style: GoogleFonts.dmSans(
                                  color: context.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (d.clicksByLabel.isEmpty)
                            const _MutedText('Sin clicks todavía.')
                          else
                            ...d.clicksByLabel.entries.map(
                              (e) => _ClickedLinkRow(
                                label: e.key,
                                value: e.value,
                                max: d.clicksByLabel.values.fold<int>(
                                  1,
                                  (a, b) => b > a ? b : a,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
                final recent = _AnalyticsRecentPanel(events: events);
                if (!wide) {
                  return Column(
                    children: [main, const SizedBox(height: 16), recent],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: main),
                    const SizedBox(width: 18),
                    Expanded(flex: 3, child: recent),
                  ],
                );
              },
            ),
    );
  }
}

class _AnalyticsHeroCard extends StatelessWidget {
  final int total;

  const _AnalyticsHeroCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 24,
      child: SizedBox(
        height: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interacciones totales',
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$total',
              style: GoogleFonts.outfit(
                color: context.text,
                fontSize: 54,
                fontWeight: FontWeight.w600,
                height: .9,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const _AnalyticsDeltaPill(label: '+0.0%'),
                const SizedBox(width: 14),
                Text(
                  'vs período anterior',
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsDeltaPill extends StatelessWidget {
  final String label;

  const _AnalyticsDeltaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: TaploeColors.blue.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.trending_up_rounded,
            color: TaploeColors.blue,
            size: 17,
          ),
          const SizedBox(width: 6),
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

class _AnalyticsMetricData {
  final String label;
  final int value;
  final IconData icon;

  const _AnalyticsMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _AnalyticsMetricStrip extends StatelessWidget {
  final List<_AnalyticsMetricData> items;

  const _AnalyticsMetricStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / items.length;
          return Wrap(
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: itemWidth < 220 ? constraints.maxWidth : itemWidth,
                  child: Container(
                    padding: EdgeInsets.only(
                      right: i == items.length - 1 ? 0 : 24,
                      left: i == 0 ? 0 : 24,
                    ),
                    decoration: BoxDecoration(
                      border: i == items.length - 1 || itemWidth < 220
                          ? null
                          : const Border(
                              right: BorderSide(color: TaploeColors.border),
                            ),
                    ),
                    child: _AnalyticsMetricItem(item: items[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsMetricItem extends StatelessWidget {
  final _AnalyticsMetricData item;

  const _AnalyticsMetricItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, color: context.muted, size: 18),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${item.value}',
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 34,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '+0.0%',
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

class _AnalyticsRecentPanel extends StatelessWidget {
  final List<AnalyticsEventModel> events;

  const _AnalyticsRecentPanel({required this.events});

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events
        .where((event) => !_isLegacyProfileInstallEvent(event.eventType))
        .toList();
    return TaploePanel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividad reciente',
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Últimas interacciones con tu perfil',
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          if (visibleEvents.isEmpty)
            const _MutedText('Sin actividad reciente.')
          else
            ...visibleEvents.map((event) => _AnalyticsRecentTile(event: event)),
        ],
      ),
    );
  }
}

class _AnalyticsRecentTile extends StatelessWidget {
  final AnalyticsEventModel event;

  const _AnalyticsRecentTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final label = _analyticsRecentTitle(event);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TaploeColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsEventIcon(event: event),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: context.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: context.muted,
                      size: 15,
                    ),
                    Text(
                      _analyticsLocation(event),
                      style: GoogleFonts.dmSans(
                        color: context.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _AnalyticsChannelBadge(event: event),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _fullDateTime12(event.occurredAt),
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsChannelBadge extends StatelessWidget {
  final AnalyticsEventModel event;

  const _AnalyticsChannelBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    final label = event.accessChannel.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: TaploeColors.blue.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: TaploeColors.blue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AnalyticsEventIcon extends StatelessWidget {
  final AnalyticsEventModel event;

  const _AnalyticsEventIcon({required this.event});

  @override
  Widget build(BuildContext context) {
    if (event.eventType == 'link_click' ||
        event.eventType == 'calendar_click') {
      return _SocialLinkIcon(label: _eventSocialSource(event), size: 25);
    }
    return Icon(
      _analyticsRecentIcon(event),
      color: TaploeColors.blue,
      size: 25,
    );
  }
}

class _ClickedLinkRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;

  const _ClickedLinkRow({
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final progress = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _SocialLinkIcon(label: label, size: 24),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: _ProgressBar(value: progress)),
          const SizedBox(width: 12),
          Text(
            '$value',
            style: GoogleFonts.outfit(
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLinkIcon extends StatelessWidget {
  final String? label;
  final double size;

  const _SocialLinkIcon({required this.label, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final data = _socialIconData(label);
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Center(
        child: FaIcon(data.icon, color: data.color, size: size),
      ),
    );
  }
}

class _SocialIconData {
  final FaIconData icon;
  final Color color;

  const _SocialIconData(this.icon, this.color);
}

_SocialIconData _socialIconData(String? label) {
  final normalized = (label ?? '').toLowerCase();
  if (normalized.contains('whatsapp')) {
    return const _SocialIconData(FontAwesomeIcons.whatsapp, Color(0xFF25D366));
  }
  if (normalized.contains('facebook')) {
    return const _SocialIconData(FontAwesomeIcons.facebookF, Color(0xFF1877F2));
  }
  if (normalized.contains('instagram')) {
    return const _SocialIconData(FontAwesomeIcons.instagram, Color(0xFFE1306C));
  }
  if (normalized.contains('linkedin')) {
    return const _SocialIconData(
      FontAwesomeIcons.linkedinIn,
      Color(0xFF0A66C2),
    );
  }
  if (normalized.contains('tiktok')) {
    return const _SocialIconData(FontAwesomeIcons.tiktok, TaploeColors.black);
  }
  if (normalized.contains('youtube')) {
    return const _SocialIconData(FontAwesomeIcons.youtube, Color(0xFFFF0000));
  }
  if (normalized == 'x' ||
      normalized.contains('twitter') ||
      normalized.contains('x.com')) {
    return const _SocialIconData(FontAwesomeIcons.xTwitter, TaploeColors.black);
  }
  if (normalized.contains('mail') || normalized.contains('correo')) {
    return const _SocialIconData(FontAwesomeIcons.envelope, TaploeColors.blue);
  }
  if (normalized.contains('phone') ||
      normalized.contains('tel') ||
      normalized.contains('llamar')) {
    return const _SocialIconData(FontAwesomeIcons.phone, TaploeColors.blue);
  }
  if (normalized.contains('calendar') || normalized.contains('agenda')) {
    return const _SocialIconData(
      FontAwesomeIcons.calendarDays,
      TaploeColors.blue,
    );
  }
  if (normalized.contains('map') || normalized.contains('ubic')) {
    return const _SocialIconData(
      FontAwesomeIcons.locationDot,
      TaploeColors.blue,
    );
  }
  return const _SocialIconData(FontAwesomeIcons.globe, TaploeColors.blue);
}

String? _eventSocialSource(AnalyticsEventModel event) {
  final metadataLabel = event.metadata['label']?.toString().trim();
  final type = event.metadata['type']?.toString().trim();
  final linkLabel = event.linkLabel?.trim();
  if (metadataLabel?.isNotEmpty == true) return metadataLabel;
  if (linkLabel?.isNotEmpty == true) return linkLabel;
  return type;
}

String _analyticsRecentTitle(AnalyticsEventModel event) {
  return switch (event.eventType) {
    'profile_view' =>
      event.accessChannel == 'nfc'
          ? 'Escaneo NFC'
          : event.accessChannel == 'qr'
          ? 'Escaneo QR'
          : 'Visita al perfil',
    'link_click' => _activityEventLabel(event),
    'calendar_click' => _activityEventLabel(event),
    'form_submit' => 'Formulario enviado',
    'contact_save' => 'Contacto guardado',
    _ => _eventLabel(event.eventType),
  };
}

IconData _analyticsRecentIcon(AnalyticsEventModel event) {
  return switch (event.accessChannel) {
    'nfc' => Icons.wifi_rounded,
    'qr' => Icons.qr_code_rounded,
    _ => _eventIcon(event.eventType),
  };
}

String _analyticsLocation(AnalyticsEventModel event) {
  final deviceLocation = event.metadata['device_location'];
  final locationMap = deviceLocation is Map
      ? Map<String, dynamic>.from(deviceLocation)
      : const <String, dynamic>{};
  final city = event.city?.trim().isNotEmpty == true
      ? event.city!.trim()
      : event.metadata['city']?.toString().trim() ??
            locationMap['city']?.toString().trim();
  final country = event.country?.trim().isNotEmpty == true
      ? event.country!.trim()
      : event.metadata['country']?.toString().trim() ??
            locationMap['country']?.toString().trim();
  final parts = [
    city,
    country,
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
  if (parts.isNotEmpty) return parts.join(', ');
  return 'Ubicación no disponible';
}

class _ViewsBarChart extends StatelessWidget {
  final List<int> values;

  const _ViewsBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final data = values.isEmpty ? List<int>.filled(7, 0) : values;
    final maxY = data.fold<int>(1, (max, value) => value > max ? value : max);
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: (maxY + 1).toDouble(),
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: TaploeColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: maxY <= 2 ? 1 : 2,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxY + 1) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  labels[index],
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => TaploeColors.white,
            tooltipBorder: const BorderSide(color: TaploeColors.borderStrong),
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toInt().toString(),
                GoogleFonts.outfit(
                  color: TaploeColors.blue,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].toDouble(),
                  width: 24,
                  color: TaploeColors.blue,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: (maxY + 1).toDouble(),
                    color: Colors.transparent,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class LeadsView extends StatefulWidget {
  const LeadsView({super.key});

  @override
  State<LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends State<LeadsView> {
  List<LeadModel> leads = [];
  List<TeamMemberModel> members = const [];
  bool loading = true;
  String? _profileId;
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  String _sourceFilter = 'all';
  String _memberFilter = 'all';
  String _sortMode = 'recent';
  DateTimeRange? _dateRange;
  bool _listView = true;

  @override
  void initState() {
    super.initState();
    load();
    taploeState.addListener(_handleTaploeStateChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    taploeState.removeListener(_handleTaploeStateChanged);
    super.dispose();
  }

  void _handleTaploeStateChanged() {
    final nextProfileId = taploeState.activeProfile?.id;
    if (nextProfileId != _profileId) load();
  }

  Future<void> load() async {
    final p = taploeState.activeProfile;
    final org = taploeState.organization;
    final currentUser = taploeState.currentUser;
    _profileId = p?.id;
    if (org == null && p == null) {
      if (mounted) {
        setState(() {
          leads = [];
          members = const [];
          loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => loading = true);
    late final List<Object> result;
    if (org != null) {
      final team = await TeamRepository.fetchTeam(org.id);
      final currentMember = _currentActiveTeamMember(team, currentUser?.id);
      final canViewMemberData = _canViewTeamMemberData(currentMember?.role);
      final selectedOwner = canViewMemberData
          ? (_memberFilter == 'all' ? null : _memberFilter)
          : currentUser?.id;
      final profileIds = selectedOwner == null && !canViewMemberData
          ? <String>[]
          : await TeamRepository.fetchProfileIdsForOrg(
              org.id,
              ownerUserId: selectedOwner,
            );
      result = await Future.wait<Object>([
        Future.value(team),
        LeadRepository.fetchForProfiles(profileIds),
      ]);
    } else {
      result = await Future.wait<Object>([
        Future.value(<TeamMemberModel>[]),
        LeadRepository.fetchForProfile(p!.id),
      ]);
    }
    if (org == null && taploeState.activeProfile?.id != p?.id) return;
    if (mounted) {
      final nextMembers = result[0] as List<TeamMemberModel>;
      final currentMember = _currentActiveTeamMember(
        nextMembers,
        currentUser?.id,
      );
      final canViewMemberData = _canViewTeamMemberData(currentMember?.role);
      final selectedStillExists =
          _memberFilter == 'all' ||
          nextMembers.any(
            (member) => !member.isPending && member.id == _memberFilter,
          );
      setState(() {
        members = nextMembers;
        if (!canViewMemberData || !selectedStillExists) _memberFilter = 'all';
        leads = result[1] as List<LeadModel>;
        loading = false;
      });
    }
  }

  Future<void> status(LeadModel lead, String value) async {
    await LeadRepository.updateStatus(lead.id, value);
    await load();
  }

  Future<void> deleteLead(LeadModel lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lead'),
        content: Text(
          '¿Quieres eliminar a ${lead.displayName}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await LeadRepository.deleteLead(lead.id);
      await load();
      if (mounted) taploeToast(context, 'Lead eliminado.');
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos eliminar el lead.', error: true);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          _dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: TaploeColors.blue,
              onPrimary: TaploeColors.white,
              primaryContainer: const Color(0xFFE5E7EB),
              onPrimaryContainer: TaploeColors.textSecondary,
              secondary: TaploeColors.blue,
            ),
            datePickerTheme: const DatePickerThemeData(
              rangeSelectionBackgroundColor: Color(0xFFE5E7EB),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final canViewMemberData = _canViewTeamMemberData(
      _currentActiveTeamMember(members, taploeState.currentUser?.id)?.role,
    );
    final activeMembers = members.where((member) => !member.isPending).toList();
    final byStatus = <String, int>{
      for (final status in ['new', 'contacted'])
        status: leads.where((lead) => lead.status == status).length,
    };
    final sources =
        leads
            .map((lead) => lead.sourceChannel?.trim() ?? '')
            .where((source) => source.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final query = _searchController.text.trim().toLowerCase();
    final filteredLeads = leads.where((lead) {
      final matchesStatus =
          _statusFilter == 'all' || lead.status == _statusFilter;
      final matchesSource =
          _sourceFilter == 'all' || lead.sourceChannel == _sourceFilter;
      final matchesDate = _leadMatchesDateRange(lead, _dateRange);
      final haystack = [
        lead.displayName,
        lead.company,
        lead.email,
        lead.phone,
        _leadSourceLabel(lead.sourceChannel),
      ].where((value) => value?.isNotEmpty == true).join(' ').toLowerCase();
      return matchesStatus &&
          matchesSource &&
          matchesDate &&
          haystack.contains(query);
    }).toList();
    filteredLeads.sort((a, b) {
      final aDate = a.lastSeenAt ?? a.firstSeenAt ?? DateTime(0);
      final bDate = b.lastSeenAt ?? b.firstSeenAt ?? DateTime(0);
      return _sortMode == 'oldest'
          ? aDate.compareTo(bDate)
          : bDate.compareTo(aDate);
    });
    return PageShell(
      title: 'Bandeja de leads',
      subtitle: canViewMemberData
          ? 'Administra y filtra leads de los miembros de tu empresa.'
          : 'Administra y da seguimiento a tus propios leads.',
      actions: taploeState.organization == null || !canViewMemberData
          ? const []
          : [
              _TeamMemberFilter(
                members: activeMembers,
                value: _memberFilter,
                onChanged: (value) {
                  setState(() => _memberFilter = value);
                  load();
                },
              ),
            ],
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : leads.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TaploeEmpty(
                  title: 'Sin leads',
                  message: 'Cuando alguien llene un formulario aparecerá aquí.',
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (context.isWide) ...[
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        _LeadsSummaryPanel(
                          total: leads.length,
                          newCount: byStatus['new'] ?? 0,
                          contactedCount: byStatus['contacted'] ?? 0,
                        ),
                        const SizedBox(height: 16),
                        _LeadsFiltersPanel(
                          statusFilter: _statusFilter,
                          sourceFilter: _sourceFilter,
                          sources: sources,
                          onStatusChanged: (value) =>
                              setState(() => _statusFilter = value),
                          onSourceChanged: (value) =>
                              setState(() => _sourceFilter = value),
                          onClear: () => setState(() {
                            _statusFilter = 'all';
                            _sourceFilter = 'all';
                            _dateRange = null;
                            _searchController.clear();
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LeadsToolbar(
                          controller: _searchController,
                          total: filteredLeads.length,
                          statusFilter: _statusFilter,
                          sortMode: _sortMode,
                          listView: _listView,
                          onSearchChanged: (_) => setState(() {}),
                          onStatusChanged: (value) =>
                              setState(() => _statusFilter = value),
                          onSortChanged: (value) =>
                              setState(() => _sortMode = value),
                          onViewChanged: (value) =>
                              setState(() => _listView = value),
                          dateLabel: _dateRangeLabel(_dateRange),
                          dateActive: _dateRange != null,
                          onDateTap: _pickDateRange,
                        ),
                        if (!context.isWide) ...[
                          const SizedBox(height: 14),
                          _LeadsFiltersPanel(
                            statusFilter: _statusFilter,
                            sourceFilter: _sourceFilter,
                            sources: sources,
                            compact: true,
                            onStatusChanged: (value) =>
                                setState(() => _statusFilter = value),
                            onSourceChanged: (value) =>
                                setState(() => _sourceFilter = value),
                            onClear: () => setState(() {
                              _statusFilter = 'all';
                              _sourceFilter = 'all';
                              _dateRange = null;
                              _searchController.clear();
                            }),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (filteredLeads.isEmpty)
                          const TaploeEmpty(
                            title: 'Sin resultados',
                            message:
                                'Ajusta la búsqueda o los filtros para ver leads.',
                          )
                        else
                          ...filteredLeads.map(
                            (lead) => _LeadTimelineTile(
                              lead: lead,
                              onStatusChanged: (value) => status(lead, value),
                              onDelete: () => deleteLead(lead),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LeadsSummaryPanel extends StatelessWidget {
  final int total;
  final int newCount;
  final int contactedCount;

  const _LeadsSummaryPanel({
    required this.total,
    required this.newCount,
    required this.contactedCount,
  });

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen',
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$total',
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 36,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Leads totales',
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: TaploeColors.border),
          const SizedBox(height: 8),
          _LeadSummaryRow(
            label: 'Nuevos',
            value: newCount,
            color: TaploeColors.blue,
          ),
          _LeadSummaryRow(
            label: 'Contactados',
            value: contactedCount,
            color: TaploeColors.success,
          ),
        ],
      ),
    );
  }
}

class _LeadSummaryRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _LeadSummaryRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: context.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$value',
            style: GoogleFonts.dmSans(
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadsFiltersPanel extends StatelessWidget {
  final String statusFilter;
  final String sourceFilter;
  final List<String> sources;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSourceChanged;
  final VoidCallback onClear;
  final bool compact;

  const _LeadsFiltersPanel({
    required this.statusFilter,
    required this.sourceFilter,
    required this.sources,
    required this.onStatusChanged,
    required this.onSourceChanged,
    required this.onClear,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtros',
          style: GoogleFonts.outfit(
            color: context.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        _LeadFilterDropdown(
          label: taploeState.t.text('Estado', 'Status'),
          value: statusFilter,
          items: const {
            'all': 'Todos los estados',
            'new': 'Nuevos',
            'contacted': 'Contactados',
          },
          onChanged: onStatusChanged,
        ),
        const SizedBox(height: 16),
        _LeadFilterDropdown(
          label: 'Fuente',
          value: sourceFilter,
          items: {
            'all': 'Todas las fuentes',
            for (final source in sources) source: _leadSourceLabel(source),
          },
          onChanged: onSourceChanged,
        ),
        const SizedBox(height: 18),
        const Divider(color: TaploeColors.border),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: TaploeColors.black,
              side: const BorderSide(color: TaploeColors.borderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Limpiar filtros',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
    if (compact) return content;
    return TaploePanel(child: content);
  }
}

class _LeadFilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _LeadFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedValue = items.containsKey(value) ? value : 'all';
    final selectedLabel = items[selectedValue] ?? '';
    final icon = label == 'Fuente'
        ? Icons.hub_outlined
        : Icons.filter_alt_outlined;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: context.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: TaploeColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TaploeColors.blue),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              isExpanded: true,
              menuWidth: compactDropdownWidth(context),
              borderRadius: BorderRadius.circular(18),
              dropdownColor: TaploeColors.white,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: TaploeColors.textSecondary,
              ),
              selectedItemBuilder: (context) => items.entries
                  .map(
                    (_) => _LeadFilterSelectedFace(
                      icon: icon,
                      label: selectedLabel,
                    ),
                  )
                  .toList(),
              items: items.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: _LeadFilterMenuItem(
                        icon: icon,
                        label: entry.value,
                        active: entry.key == selectedValue,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}

double compactDropdownWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width < 520 ? width - 48 : 260;
}

class _LeadFilterSelectedFace extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LeadFilterSelectedFace({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: TaploeColors.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: TaploeColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeadFilterMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _LeadFilterMenuItem({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? TaploeColors.blue : TaploeColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: TaploeColors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (active) ...[
            const SizedBox(width: 10),
            const Icon(Icons.check_rounded, size: 18, color: TaploeColors.blue),
          ],
        ],
      ),
    );
  }
}

class _LeadsToolbar extends StatelessWidget {
  final TextEditingController controller;
  final int total;
  final String statusFilter;
  final String sortMode;
  final bool listView;
  final String dateLabel;
  final bool dateActive;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onViewChanged;
  final VoidCallback onDateTap;

  const _LeadsToolbar({
    required this.controller,
    required this.total,
    required this.statusFilter,
    required this.sortMode,
    required this.listView,
    required this.dateLabel,
    required this.dateActive,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onViewChanged,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: taploeLocalizeText(context, 'Buscar leads...'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            _LeadToolbarPill(
              icon: Icons.calendar_today_rounded,
              label: dateLabel,
              active: dateActive,
              onTap: onDateTap,
            ),
            _LeadIconToggle(
              icon: Icons.tune_rounded,
              selected: false,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _LeadStatusTabs(
                value: statusFilter,
                onChanged: onStatusChanged,
              ),
            ),
            if (context.isWide) ...[
              Text(
                'Ordenar por:',
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: sortMode,
                  borderRadius: BorderRadius.circular(14),
                  items: const [
                    DropdownMenuItem(
                      value: 'recent',
                      child: Text('Más recientes'),
                    ),
                    DropdownMenuItem(
                      value: 'oldest',
                      child: Text('Más antiguos'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              _LeadIconToggle(
                icon: Icons.view_list_rounded,
                selected: listView,
                onTap: () => onViewChanged(true),
              ),
              const SizedBox(width: 8),
              _LeadIconToggle(
                icon: Icons.grid_view_rounded,
                selected: !listView,
                onTap: () => onViewChanged(false),
              ),
            ],
            const SizedBox(width: 8),
            Text(
              '$total total',
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LeadToolbarPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LeadToolbarPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaploeColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active ? TaploeColors.blue : TaploeColors.border,
          width: active ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                color: active ? TaploeColors.blue : context.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _leadMatchesDateRange(LeadModel lead, DateTimeRange? range) {
  if (range == null) return true;
  final date = lead.lastSeenAt ?? lead.firstSeenAt;
  if (date == null) return false;
  final local = DateTime(date.year, date.month, date.day);
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  return !local.isBefore(start) && !local.isAfter(end);
}

String _dateRangeLabel(DateTimeRange? range) {
  if (range == null) return 'Todas las fechas';
  return '${_numericDate(range.start)} - ${_numericDate(range.end)}';
}

class _LeadIconToggle extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LeadIconToggle({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: selected ? TaploeColors.blue : context.muted,
        backgroundColor: TaploeColors.white,
        side: BorderSide(
          color: selected ? TaploeColors.blueBorder : TaploeColors.border,
          width: selected ? 1.6 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        fixedSize: const Size(46, 46),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}

class _LeadStatusTabs extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LeadStatusTabs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tabs = const {
      'all': 'Todos',
      'new': 'Nuevos',
      'contacted': 'Contactados',
    };
    return Wrap(
      spacing: 28,
      runSpacing: 10,
      children: tabs.entries.map((entry) {
        final active = entry.key == value;
        return InkWell(
          onTap: () => onChanged(entry.key),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.value,
                  style: GoogleFonts.dmSans(
                    color: active ? TaploeColors.blue : context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 58 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: TaploeColors.blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LeadTimelineTile extends StatefulWidget {
  final LeadModel lead;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete;

  const _LeadTimelineTile({
    required this.lead,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  State<_LeadTimelineTile> createState() => _LeadTimelineTileState();
}

class _LeadTimelineTileState extends State<_LeadTimelineTile> {
  bool showAll = false;
  bool loading = false;
  List<AnalyticsEventModel> events = const [];

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  @override
  void didUpdateWidget(covariant _LeadTimelineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lead.id != widget.lead.id) {
      events = const [];
      showAll = false;
      _loadTimeline();
    }
  }

  Future<void> _loadTimeline() async {
    if (events.isNotEmpty || loading) return;
    setState(() => loading = true);
    final rows = await AnalyticsRepository.fetchTimelineForLead(widget.lead.id);
    if (mounted) {
      setState(() {
        events = rows;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final visibleEvents = showAll ? events : events.take(4).toList();
    AnalyticsEventModel? formEvent;
    for (final event in events) {
      if (event.eventType == 'form_submit' && event.formSubmissionId != null) {
        formEvent = event;
        break;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: TaploeColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final leadInfo = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _leadStatusColor(lead.status),
                child: Text(
                  lead.displayName.isNotEmpty
                      ? lead.displayName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          lead.displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: context.text,
                          ),
                        ),
                        if (formEvent != null)
                          TextButton.icon(
                            onPressed: () =>
                                _showSubmissionInfo(context, formEvent!),
                            style: TextButton.styleFrom(
                              foregroundColor: TaploeColors.blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                            ),
                            label: Text(
                              'Ver info',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (lead.company?.isNotEmpty == true)
                      Text(
                        lead.company!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: context.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        if (lead.email?.isNotEmpty == true)
                          _LeadContactLine(
                            icon: Icons.mail_outline_rounded,
                            value: lead.email!,
                          ),
                        if (lead.phone?.isNotEmpty == true)
                          _LeadContactLine(
                            icon: Icons.phone_rounded,
                            value: lead.phone!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _LeadStatusBadge(status: lead.status),
                        _SmallPill(
                          label: _leadSourceLabel(lead.sourceChannel),
                          icon: Icons.hub_outlined,
                        ),
                        _SmallPill(
                          label: _relativeTime(lead.lastSeenAt),
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
          final timeline = loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                )
              : events.isEmpty
              ? const _MutedText('Aún no hay interacciones asociadas.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LeadTimeline(events: visibleEvents),
                    if (events.length > 4)
                      TextButton(
                        onPressed: () => setState(() => showAll = !showAll),
                        child: Text(
                          showAll
                              ? 'Ver menos'
                              : 'Ver todos los eventos (${events.length})',
                        ),
                      ),
                  ],
                );
          final actions = Column(
            crossAxisAlignment: wide
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.stretch,
            children: [
              Text(
                lead.lastSeenAt == null ? '-' : _numericDate(lead.lastSeenAt!),
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _leadSourceIcon(lead.sourceChannel),
                    color: context.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _shortLeadSourceLabel(lead.sourceChannel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: context.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => widget.onStatusChanged('contacted'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TaploeColors.blue,
                      side: const BorderSide(
                        color: TaploeColors.blueBorder,
                        width: 1.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                    ),
                    icon: const Icon(Icons.mail_rounded, size: 18),
                    label: Text(
                      lead.status == 'contacted' ? 'Contactado' : 'Contactar',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Eliminar lead',
                    onSelected: (value) {
                      if (value == 'delete') widget.onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar lead'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ],
              ),
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leadInfo,
                const SizedBox(height: 18),
                timeline,
                const SizedBox(height: 18),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: leadInfo),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: timeline),
              const SizedBox(width: 24),
              SizedBox(width: 220, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _LeadStatusBadge extends StatelessWidget {
  final String status;

  const _LeadStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _leadStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _leadStatusLabel(status),
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LeadContactLine extends StatelessWidget {
  final IconData icon;
  final String value;

  const _LeadContactLine({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.muted, size: 16),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeadTimeline extends StatelessWidget {
  final List<AnalyticsEventModel> events;

  const _LeadTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _LeadTimelineRow(event: events[i], isLast: i == events.length - 1),
      ],
    );
  }
}

class _LeadTimelineRow extends StatelessWidget {
  final AnalyticsEventModel event;
  final bool isLast;

  const _LeadTimelineRow({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: TaploeColors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.only(top: 4),
                  color: TaploeColors.borderStrong,
                ),
            ],
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            _timeOnly(event.occurredAt),
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _timelineEventLabel(event),
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (event.eventType == 'form_submit' &&
                  event.formSubmissionId != null)
                TextButton.icon(
                  onPressed: () => _showSubmissionInfo(context, event),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Ver info'),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _timelineDate(event.occurredAt),
          style: GoogleFonts.dmSans(
            color: context.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Icon(_timelineIcon(event), color: TaploeColors.blue, size: 15),
      ],
    );
  }
}

class _TeamPlanRequestPanel extends StatelessWidget {
  const _TeamPlanRequestPanel();

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.groups_2_outlined,
            color: TaploeColors.blue,
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            'Crea un espacio para tu equipo',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Administra miembros, perfiles, tarjetas y resultados desde Taploe Business. Para activar esta experiencia necesitas solicitar una cotización con el equipo de Taploe.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 22),
          TaploeButton(
            label: 'Solicitar plan para equipo',
            icon: Icons.workspace_premium_outlined,
            width: 260,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => const _TeamPlanRequestDialog(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPlanRequestDialog extends StatefulWidget {
  const _TeamPlanRequestDialog();

  @override
  State<_TeamPlanRequestDialog> createState() => _TeamPlanRequestDialogState();
}

class _TeamPlanRequestDialogState extends State<_TeamPlanRequestDialog> {
  final fullName = TextEditingController();
  final company = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final message = TextEditingController();
  String solutionType = 'nfc_card';
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final user = taploeState.currentUser;
    fullName.text = user?.username ?? '';
    email.text = user?.email ?? '';
    phone.text = user?.phone ?? '';
    company.text = taploeState.organization?.name ?? '';
  }

  @override
  void dispose() {
    fullName.dispose();
    company.dispose();
    phone.dispose();
    email.dispose();
    quantity.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final qty = int.tryParse(quantity.text.trim()) ?? 0;
    if (fullName.text.trim().isEmpty || email.text.trim().isEmpty || qty <= 0) {
      setState(() {
        error = 'Completa nombre, correo electrónico y cantidad aproximada.';
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await QuoteRequestRepository.createTeamPlanRequest(
        solutionType: solutionType,
        approximateQuantity: qty,
        fullName: fullName.text,
        company: company.text,
        phone: phone.text,
        email: email.text,
        message: message.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      taploeToast(context, 'Solicitud enviada. Te contactaremos pronto.');
    } catch (e) {
      safePrintError(e);
      if (mounted) {
        setState(() {
          error =
              'No pudimos enviar la solicitud. Revisa permisos de quote_requests.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      color: TaploeColors.blue,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Solicitar plan para equipo',
                        style: GoogleFonts.outfit(
                          color: context.text,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuéntanos qué necesita tu equipo y Taploe te ayuda con una cotización.',
                  style: GoogleFonts.dmSans(color: context.muted),
                ),
                const SizedBox(height: 22),
                if (error != null) ...[
                  Text(
                    error!,
                    style: GoogleFonts.dmSans(
                      color: TaploeColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _ResponsivePair(
                  breakpoint: 720,
                  left: _TeamSolutionDropdown(
                    value: solutionType,
                    onChanged: (value) => setState(() => solutionType = value),
                  ),
                  right: TaploeTextField(
                    label: 'Cantidad aproximada *',
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(height: 14),
                _ResponsivePair(
                  breakpoint: 720,
                  left: TaploeTextField(
                    label: 'Nombre completo *',
                    controller: fullName,
                  ),
                  right: TaploeTextField(
                    label: 'Empresa opcional',
                    controller: company,
                  ),
                ),
                const SizedBox(height: 14),
                _ResponsivePair(
                  breakpoint: 720,
                  left: TaploeTextField(
                    label: 'Teléfono opcional',
                    controller: phone,
                    keyboardType: TextInputType.phone,
                  ),
                  right: TaploeTextField(
                    label: 'Correo electrónico *',
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 14),
                TaploeTextField(
                  label: 'Cuéntanos brevemente qué tienes en mente opcional',
                  hint:
                      'Ejemplo: Necesitamos 15 tarjetas para el equipo comercial, personalizadas con el logo y los datos de cada asesor.',
                  controller: message,
                  maxLines: 4,
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TaploeButton(
                      label: 'Cancelar',
                      kind: TaploeButtonKind.secondary,
                      width: 120,
                      onPressed: saving ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    TaploeButton(
                      label: 'Enviar solicitud',
                      icon: Icons.send_rounded,
                      width: 230,
                      loading: saving,
                      onPressed: submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamSolutionDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TeamSolutionDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = {
      'nfc_card': 'Tarjeta NFC + perfil digital',
      'digital_profile': 'Solo perfil digital',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de solución *',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: TaploeColors.white,
            borderRadius: BorderRadius.circular(TaploeRadius.input),
            border: Border.all(color: TaploeColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: items.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class TeamView extends StatefulWidget {
  const TeamView({super.key});

  @override
  State<TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends State<TeamView> {
  List<TeamMemberModel> members = [];
  List<TeamActivityModel> activities = [];
  String selectedMemberId = 'all';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
    taploeState.addListener(load);
  }

  @override
  void dispose() {
    taploeState.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    final org = taploeState.organization;
    if (org == null) {
      if (mounted) {
        setState(() {
          members = const [];
          activities = const [];
          loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => loading = true);
    final ownerUserId = selectedMemberId == 'all' ? null : selectedMemberId;
    final result = await Future.wait<Object>([
      TeamRepository.fetchTeam(org.id),
      TeamRepository.fetchRecentActivity(
        org.id,
        ownerUserId: ownerUserId,
        limit: 8,
      ),
    ]);
    if (mounted) {
      final nextMembers = result[0] as List<TeamMemberModel>;
      final selectedStillExists =
          selectedMemberId == 'all' ||
          nextMembers.any(
            (member) => !member.isPending && member.id == selectedMemberId,
          );
      setState(() {
        members = nextMembers;
        activities = result[1] as List<TeamActivityModel>;
        if (!selectedStillExists) selectedMemberId = 'all';
        loading = false;
      });
    }
  }

  Future<void> _openInviteDialog() async {
    if (!_canInviteMembers) {
      await showDialog<void>(
        context: context,
        builder: (context) => const _MemberInviteBlockedDialog(),
      );
      return;
    }
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => const _InviteTeamMemberDialog(),
    );
    if (sent == true) await load();
  }

  Future<void> _openCreateCompanyDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _CreateCompanyDialog(),
    );
    if (created == true) await load();
  }

  Future<void> _cancelInvitation(TeamMemberModel member) async {
    final invitationId = member.invitationId;
    if (invitationId == null || invitationId.isEmpty) return;
    try {
      await TeamRepository.cancelInvitation(invitationId);
      if (!mounted) return;
      taploeToast(context, 'Invitación cancelada.');
      await load();
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos cancelar la invitación.', error: true);
      }
    }
  }

  Future<void> _removeMember(TeamMemberModel member) async {
    final org = taploeState.organization;
    if (org == null || member.isPending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _RemoveTeamMemberDialog(memberName: member.name, orgName: org.name),
    );
    if (confirmed != true) return;
    try {
      await TeamRepository.removeMember(orgId: org.id, userId: member.id);
      if (!mounted) return;
      taploeToast(context, '${member.name} fue desvinculado de ${org.name}.');
      await load();
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos desvincular este miembro.',
          error: true,
        );
      }
    }
  }

  bool get _canInviteMembers {
    final currentUserId = taploeState.currentUser?.id;
    if (currentUserId == null) return false;
    for (final member in members) {
      if (!member.isPending && member.id == currentUserId) {
        return member.role == 'owner' || member.role == 'admin';
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers = members.where((member) => !member.isPending).toList();
    final pendingMembers = members.where((member) => member.isPending).length;
    final totalViews = activeMembers.fold<int>(
      0,
      (sum, member) => sum + member.views,
    );
    final totalLeads = activeMembers.fold<int>(
      0,
      (sum, member) => sum + member.leads,
    );
    final totalNfc = activeMembers.fold<int>(
      0,
      (sum, member) => sum + member.nfc,
    );
    final totalQr = activeMembers.fold<int>(
      0,
      (sum, member) => sum + member.qr,
    );
    final totalClicks = activeMembers.fold<int>(
      0,
      (sum, member) => sum + member.clicks,
    );
    TeamMemberModel? selectedMember;
    for (final member in members) {
      if (member.id == selectedMemberId) {
        selectedMember = member;
        break;
      }
    }
    return PageShell(
      title: 'Equipo',
      subtitle: 'Gestiona tu equipo y visualiza el rendimiento en conjunto.',
      actions: [
        TaploeButton(
          label: taploeState.organization == null
              ? 'Crear empresa'
              : 'Invitar miembro',
          icon: taploeState.organization == null
              ? Icons.apartment_rounded
              : Icons.group_add_rounded,
          width: 190,
          onPressed: taploeState.organization == null
              ? _openCreateCompanyDialog
              : _openInviteDialog,
        ),
      ],
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : taploeState.organization == null
          ? _NoCompanyTeamPanel(onCreateCompany: _openCreateCompanyDialog)
          : Column(
              children: [
                GridView.count(
                  crossAxisCount: context.isWide ? 5 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: context.isWide ? 1.55 : 1.18,
                  children: [
                    _MetricPanel(
                      label: 'Visitas totales',
                      value: '$totalViews',
                      icon: Icons.visibility_outlined,
                    ),
                    _MetricPanel(
                      label: 'Taps NFC',
                      value: '$totalNfc',
                      icon: Icons.nfc_rounded,
                    ),
                    _MetricPanel(
                      label: 'Escaneos QR',
                      value: '$totalQr',
                      icon: Icons.qr_code_rounded,
                    ),
                    _MetricPanel(
                      label: 'Clicks totales',
                      value: '$totalClicks',
                      icon: Icons.share_rounded,
                    ),
                    _MetricPanel(
                      label: 'Leads generados',
                      value: '$totalLeads',
                      icon: Icons.handshake_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ResponsivePair(
                  breakpoint: 980,
                  leftFlex: 6,
                  rightFlex: 4,
                  left: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Directorio del equipo',
                          icon: Icons.manage_accounts_outlined,
                          trailing: pendingMembers == 0
                              ? '${activeMembers.length} activos'
                              : '${activeMembers.length} activos · $pendingMembers pendientes',
                        ),
                        const SizedBox(height: 26),
                        if (members.isEmpty)
                          const _MutedText(
                            'Aún no hay miembros activos en esta empresa.',
                          )
                        else
                          _TeamMembersTable(
                            members: members,
                            onCancelInvitation: _cancelInvitation,
                            onRemoveMember: _removeMember,
                          ),
                      ],
                    ),
                  ),
                  right: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PanelHeader(
                                title: 'Actividad del equipo',
                                icon: Icons.receipt_long_outlined,
                              ),
                            ),
                            _TeamMemberFilter(
                              members: activeMembers,
                              value: selectedMemberId,
                              onChanged: (value) {
                                setState(() => selectedMemberId = value);
                                load();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedMember == null
                              ? 'Últimas interacciones registradas.'
                              : 'Actividad de ${selectedMember.name}.',
                          style: GoogleFonts.dmSans(
                            color: context.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (activities.isEmpty)
                          const _MutedText('Sin actividad reciente.')
                        else
                          ...activities.map(
                            (activity) => _TeamActivityTile(activity: activity),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NoCompanyTeamPanel extends StatelessWidget {
  final VoidCallback onCreateCompany;

  const _NoCompanyTeamPanel({required this.onCreateCompany});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.apartment_rounded,
              color: TaploeColors.blue,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              'Sin empresa activa',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: context.text,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu empresa para invitar miembros y ver analítica de equipo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            TaploeButton(
              label: 'Crear empresa',
              icon: Icons.add_business_rounded,
              width: 190,
              onPressed: onCreateCompany,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCompanyDialog extends StatefulWidget {
  const _CreateCompanyDialog();

  @override
  State<_CreateCompanyDialog> createState() => _CreateCompanyDialogState();
}

class _CreateCompanyDialogState extends State<_CreateCompanyDialog> {
  final name = TextEditingController();
  Uint8List? logoBytes;
  String? logoFileName;
  CompanyLogoDropSubscription? logoDrop;
  bool saving = false;
  bool draggingLogo = false;
  String? error;

  @override
  void initState() {
    super.initState();
    logoDrop = CompanyLogoDropSubscription(
      onDropped: (file) {
        if (!mounted || saving) return;
        setState(() {
          logoBytes = file.bytes;
          logoFileName = file.name;
          draggingLogo = false;
          error = null;
        });
      },
      onDragActive: (active) {
        if (!mounted) return;
        setState(() => draggingLogo = active);
      },
    );
  }

  @override
  void dispose() {
    logoDrop?.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() {
      logoBytes = bytes;
      logoFileName = file.name;
      error = null;
    });
  }

  Future<void> submit() async {
    final user = taploeState.currentUser;
    if (user == null) return;
    if (name.text.trim().length < 2) {
      setState(() => error = 'Escribe el nombre de la empresa.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final authUserId = taploeState.client.auth.currentUser?.id;
      String? logoUrl;
      if (logoBytes != null) {
        if (authUserId == null) throw Exception('No hay sesión activa.');
        logoUrl = await OrganizationAssetRepository.uploadCompanyLogo(
          authUserId: authUserId,
          bytes: logoBytes!,
          fileName: logoFileName ?? 'company-logo.jpg',
        );
      }
      await OrganizationRepository.createCompanyForOwner(
        owner: user,
        name: name.text,
        logoUrl: logoUrl,
      );
      await taploeState.bootstrap();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      taploeToast(context, 'Empresa creada.');
    } on ArgumentError {
      if (mounted) {
        setState(() => error = 'Escribe el nombre de la empresa.');
      }
    } on PostgrestException catch (e) {
      safePrintError(e);
      if (mounted) {
        setState(() {
          error = e.code == '42501'
              ? 'Falta aplicar las políticas RLS para crear empresas.'
              : 'No pudimos crear la empresa.';
        });
      }
    } catch (e) {
      safePrintError(e);
      if (mounted) {
        setState(() => error = 'No pudimos crear la empresa.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.add_business_rounded,
                      color: TaploeColors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Crear empresa',
                        style: GoogleFonts.outfit(
                          color: context.text,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu usuario quedará como administrador principal de esta empresa.',
                  style: GoogleFonts.dmSans(color: context.muted),
                ),
                const SizedBox(height: 20),
                if (error != null) ...[
                  Text(
                    error!,
                    style: GoogleFonts.dmSans(
                      color: TaploeColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _CompanyLogoPicker(
                  bytes: logoBytes,
                  fileName: logoFileName,
                  dragging: draggingLogo,
                  onPick: saving ? null : pickLogo,
                  onRemove: saving
                      ? null
                      : () {
                          setState(() {
                            logoBytes = null;
                            logoFileName = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
                TaploeTextField(label: 'Nombre de empresa *', controller: name),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TaploeButton(
                      label: 'Cancelar',
                      kind: TaploeButtonKind.secondary,
                      width: 120,
                      onPressed: saving ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    TaploeButton(
                      label: 'Crear empresa',
                      icon: Icons.check_rounded,
                      width: 220,
                      loading: saving,
                      onPressed: submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyLogoPicker extends StatefulWidget {
  final Uint8List? bytes;
  final String? fileName;
  final bool dragging;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  const _CompanyLogoPicker({
    required this.bytes,
    required this.fileName,
    required this.dragging,
    required this.onPick,
    required this.onRemove,
  });

  @override
  State<_CompanyLogoPicker> createState() => _CompanyLogoPickerState();
}

class _CompanyLogoPickerState extends State<_CompanyLogoPicker> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final hasLogo = widget.bytes != null;
    final active = hovering || widget.dragging;
    final borderColor = active
        ? TaploeColors.blue
        : TaploeColors.blue.withValues(alpha: .32);
    return MouseRegion(
      cursor: widget.onPick == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPick,
        child: CustomPaint(
          painter: _DashedRoundRectPainter(
            color: borderColor,
            strokeWidth: active ? 2.2 : 1.8,
            radius: 18,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 168),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: active
                  ? TaploeColors.blue.withValues(alpha: .065)
                  : TaploeColors.blue.withValues(alpha: .025),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_rounded,
                  color: TaploeColors.blue,
                  size: active ? 48 : 44,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.dragging
                      ? 'Suelta tu logo aquí'
                      : 'Arrastra tu logo o selecciónalo',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'PNG, JPG o WebP · máximo 5 MB',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasLogo) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: TaploeColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TaploeColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: TaploeColors.border),
                          ),
                          child: Image.memory(widget.bytes!, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 9),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            widget.fileName ?? 'Logo seleccionado',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: context.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            tooltip: 'Quitar logo',
                            padding: EdgeInsets.zero,
                            onPressed: widget.onRemove,
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                        ),
                      ],
                    ),
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

class _DashedRoundRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  const _DashedRoundRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(strokeWidth / 2),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const dash = 7.0;
    const gap = 7.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        radius != oldDelegate.radius;
  }
}

class _InviteTeamMemberDialog extends StatefulWidget {
  const _InviteTeamMemberDialog();

  @override
  State<_InviteTeamMemberDialog> createState() =>
      _InviteTeamMemberDialogState();
}

class _InviteTeamMemberDialogState extends State<_InviteTeamMemberDialog> {
  final destination = TextEditingController();
  String role = 'member';
  bool saving = false;
  String? error;

  @override
  void dispose() {
    destination.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final org = taploeState.organization;
    final user = taploeState.currentUser;
    if (org == null || user == null) return;
    if (destination.text.trim().isEmpty) {
      setState(() => error = 'Escribe un correo o nombre de usuario.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await TeamRepository.inviteMember(
        org: org,
        invitedBy: user,
        emailOrUsername: destination.text,
        role: role,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      taploeToast(context, 'Invitación enviada.');
    } on TeamInviteException catch (e) {
      if (!mounted) return;
      setState(() {
        error = switch (e.code) {
          'user_not_found' =>
            'No existe un usuario con ese correo o nombre de usuario.',
          'cannot_invite_self' => 'No puedes invitarte a ti mismo.',
          'already_member' => 'Este usuario ya pertenece a la empresa.',
          'already_invited' =>
            'Este usuario ya tiene una invitación pendiente.',
          'not_allowed' => 'Tu rol no permite invitar miembros.',
          _ => 'No pudimos enviar la invitación.',
        };
      });
    } catch (e) {
      safePrintError(e);
      if (mounted) {
        setState(() => error = 'No pudimos enviar la invitación.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_add_rounded, color: TaploeColors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Invitar miembro',
                      style: GoogleFonts.outfit(
                        color: context.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Envía una invitación a un usuario existente por correo o username.',
                style: GoogleFonts.dmSans(color: context.muted),
              ),
              const SizedBox(height: 20),
              if (error != null) ...[
                Text(
                  error!,
                  style: GoogleFonts.dmSans(
                    color: TaploeColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TaploeTextField(
                label: 'Correo o nombre de usuario',
                hint: 'ana@empresa.com o ana-lopez',
                controller: destination,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _RoleDropdown(
                value: role,
                onChanged: (value) => setState(() => role = value),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TaploeButton(
                    label: 'Cancelar',
                    kind: TaploeButtonKind.secondary,
                    width: 120,
                    onPressed: saving ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  TaploeButton(
                    label: 'Enviar invitación',
                    icon: Icons.send_rounded,
                    width: 210,
                    loading: saving,
                    onPressed: submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _RoleDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const roles = {
      'member': 'Miembro',
      'admin': 'Administrador',
      'viewer': 'Solo lectura',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rol',
          style: GoogleFonts.dmSans(
            color: context.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            menuWidth: 520,
            borderRadius: BorderRadius.circular(16),
            icon: const SizedBox.shrink(),
            selectedItemBuilder: (context) => roles.entries
                .map((_) => _RoleDropdownFace(label: roles[value] ?? 'Miembro'))
                .toList(),
            items: roles.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: _RoleDropdownMenuItem(
                      label: entry.value,
                      active: entry.key == value,
                    ),
                  ),
                )
                .toList(),
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ],
    );
  }
}

class _RoleDropdownFace extends StatelessWidget {
  final String label;

  const _RoleDropdownFace({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(TaploeRadius.pill),
        border: Border.all(color: TaploeColors.blue),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: TaploeColors.blue,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rol seleccionado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: TaploeColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _RoleDropdownMenuItem extends StatelessWidget {
  final String label;
  final bool active;

  const _RoleDropdownMenuItem({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.admin_panel_settings_outlined,
          size: 18,
          color: active ? TaploeColors.blue : context.muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: context.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (active) ...[
          const SizedBox(width: 10),
          const Icon(Icons.check_rounded, size: 18, color: TaploeColors.blue),
        ],
      ],
    );
  }
}

class _TeamMemberFilter extends StatelessWidget {
  final List<TeamMemberModel> members;
  final String value;
  final ValueChanged<String> onChanged;

  const _TeamMemberFilter({
    required this.members,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        borderRadius: BorderRadius.circular(14),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('Todos')),
          ...members.map(
            (member) => DropdownMenuItem(
              value: member.id,
              child: Text(member.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _TeamMembersTable extends StatelessWidget {
  final List<TeamMemberModel> members;
  final ValueChanged<TeamMemberModel> onCancelInvitation;
  final ValueChanged<TeamMemberModel> onRemoveMember;

  const _TeamMembersTable({
    required this.members,
    required this.onCancelInvitation,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(TaploeColors.page),
        headingRowHeight: 58,
        dataRowMinHeight: 68,
        dataRowMaxHeight: 76,
        horizontalMargin: 12,
        columnSpacing: 22,
        columns: [
          const DataColumn(label: Text('Miembro')),
          const DataColumn(label: Text('Rol')),
          const DataColumn(label: Text('Perfiles')),
          const DataColumn(label: Text('Tarjetas')),
          const DataColumn(label: Text('Última actividad')),
          DataColumn(label: Text(taploeState.t.text('Estado', 'Status'))),
        ],
        rows: members
            .map(
              (member) => DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        _UserAvatar(
                          radius: 18,
                          fontSize: 12,
                          label: member.name,
                          imageUrl: member.avatarUrl,
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 180,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: context.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                member.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: context.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(_teamRoleLabel(member.role))),
                  DataCell(Text(member.isPending ? '-' : '${member.profiles}')),
                  DataCell(Text(member.isPending ? '-' : '${member.cards}')),
                  DataCell(
                    Text(
                      member.isPending
                          ? 'Pendiente'
                          : member.views + member.clicks == 0
                          ? '-'
                          : 'Hoy',
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusPill(
                          label: member.isPending ? 'Pendiente' : 'Activo',
                          color: member.isPending
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: member.isPending
                              ? IconButton(
                                  tooltip: 'Cancelar invitación',
                                  padding: EdgeInsets.zero,
                                  onPressed: () => onCancelInvitation(member),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: TaploeColors.error,
                                  ),
                                )
                              : _TeamMemberActionsMenu(
                                  member: member,
                                  onRemove: () => onRemoveMember(member),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RemoveTeamMemberDialog extends StatelessWidget {
  final String memberName;
  final String orgName;

  const _RemoveTeamMemberDialog({
    required this.memberName,
    required this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(
            Icons.person_remove_alt_1_rounded,
            color: TaploeColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Desvincular miembro',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        'Vas a desvincular de la empresa $orgName a $memberName. Su cuenta ya no pertenecerá a la empresa.',
        style: GoogleFonts.dmSans(color: context.muted, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TaploeButton(
          label: 'Desvincular',
          icon: Icons.person_remove_alt_1_rounded,
          kind: TaploeButtonKind.danger,
          width: 178,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _MemberInviteBlockedDialog extends StatelessWidget {
  const _MemberInviteBlockedDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: TaploeColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Invitación no disponible',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        'Tienes rol de miembro. No puedes invitar a nuevos miembros.',
        style: GoogleFonts.dmSans(color: context.muted, height: 1.35),
      ),
      actions: [
        TaploeButton(
          label: 'Entendido',
          icon: Icons.check_rounded,
          width: 150,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _TeamMemberActionsMenu extends StatelessWidget {
  final TeamMemberModel member;
  final VoidCallback onRemove;

  const _TeamMemberActionsMenu({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final canRemove =
        member.role != 'owner' && member.id != taploeState.currentUser?.id;
    return PopupMenuButton<String>(
      tooltip: 'Acciones de miembro',
      offset: const Offset(0, 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: TaploeColors.white,
      surfaceTintColor: TaploeColors.white,
      elevation: 10,
      shadowColor: TaploeColors.black.withValues(alpha: .12),
      onSelected: (value) {
        if (value == 'remove') onRemove();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'remove',
          enabled: canRemove,
          child: Row(
            children: [
              Icon(
                Icons.person_remove_alt_1_rounded,
                size: 20,
                color: canRemove ? TaploeColors.error : context.muted,
              ),
              const SizedBox(width: 10),
              Text(
                'Desvincular de empresa',
                style: GoogleFonts.dmSans(
                  color: canRemove ? TaploeColors.error : context.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert_rounded),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TeamActivityTile extends StatelessWidget {
  final TeamActivityModel activity;

  const _TeamActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final event = activity.event;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsEventIcon(event: event),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activity.memberName} · ${_analyticsRecentTitle(event)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.profileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fullDateTime12(event.occurredAt),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _teamRoleLabel(String role) {
  return switch (role) {
    'owner' => 'Owner',
    'admin' => 'Administrador',
    'viewer' => 'Solo lectura',
    _ => 'Miembro',
  };
}

TeamMemberModel? _currentActiveTeamMember(
  List<TeamMemberModel> members,
  String? currentUserId,
) {
  if (currentUserId == null) return null;
  for (final member in members) {
    if (!member.isPending && member.id == currentUserId) return member;
  }
  return null;
}

bool _canViewTeamMemberData(String? role) {
  return role == 'owner' || role == 'admin';
}

bool _canManageTeamDesign(String? role) {
  return role == 'owner' || role == 'admin';
}

String _teamPolicyFingerprint(OrganizationModel org) {
  return [
    org.enforceTeamProfileTheme,
    org.enforceTeamProfileForms,
    org.enforceTeamProfileIntegrations,
  ].join('|');
}

class AdminView extends StatefulWidget {
  final ValueChanged<DigitalProfileModel> onEditProfile;
  final VoidCallback onManageTeam;

  const AdminView({
    super.key,
    required this.onEditProfile,
    required this.onManageTeam,
  });

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  final _teamLogo = TextEditingController();
  final _teamCover = TextEditingController();
  List<TeamMemberModel> members = [];
  List<DigitalProfileModel> teamProfiles = [];
  List<SmartFormModel> forms = [];
  List<ProfileIntegrationModel> integrations = [];
  bool loading = true;
  bool savingTeamDesign = false;
  bool savingCompanyLogo = false;
  bool savingTeamControls = false;
  String? updatingProfileId;

  @override
  void initState() {
    super.initState();
    load();
    taploeState.addListener(load);
  }

  @override
  void dispose() {
    _teamLogo.dispose();
    _teamCover.dispose();
    taploeState.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    final org = taploeState.organization;
    final profile = taploeState.activeProfile;
    if (org == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final result = await Future.wait<Object>([
      TeamRepository.fetchTeam(org.id),
      ProfileRepository.fetchProfilesForOrg(org.id),
      if (profile != null)
        SmartFormRepository.fetchForms(profile.id)
      else
        Future.value(<SmartFormModel>[]),
      if (profile != null)
        IntegrationRepository.fetchForProfile(profileId: profile.id)
      else
        Future.value(<ProfileIntegrationModel>[]),
    ]);

    if (!mounted) return;
    setState(() {
      members = result[0] as List<TeamMemberModel>;
      teamProfiles = result[1] as List<DigitalProfileModel>;
      forms = result[2] as List<SmartFormModel>;
      integrations = result[3] as List<ProfileIntegrationModel>;
      _teamLogo.text = org.logoUrl ?? '';
      _teamCover.text = org.teamProfileCoverPhotoUrl ?? '';
      loading = false;
    });
  }

  TeamMemberModel? get _currentMember =>
      _currentActiveTeamMember(members, taploeState.currentUser?.id);

  bool get _canManageDesign => _canManageTeamDesign(_currentMember?.role);

  ProfileThemeModel _teamTheme(OrganizationModel org) {
    final activeTheme = taploeState.activeProfile?.theme;
    return org.teamProfileTheme ??
        activeTheme ??
        ProfileThemeModel(profileId: org.id);
  }

  DigitalProfileModel _teamDesignPreviewProfile(OrganizationModel org) {
    final profile = taploeState.activeProfile;
    final theme = _teamTheme(org);
    if (profile != null) {
      return profile.copyWith(
        logoUrl: org.logoUrl,
        clearLogoUrl: org.logoUrl?.trim().isNotEmpty != true,
        coverPhotoUrl: _teamCover.text.trim().isEmpty
            ? profile.coverPhotoUrl
            : _teamCover.text.trim(),
        theme: theme,
      );
    }
    return DigitalProfileModel(
      id: org.id,
      ownerUserId: taploeState.currentUser?.id ?? '',
      displayName: org.name,
      companyName: org.name,
      publicSlug: org.slug ?? 'empresa',
      logoUrl: org.logoUrl,
      coverPhotoUrl: org.teamProfileCoverPhotoUrl,
      theme: theme,
    );
  }

  Future<void> _saveTeamTheme({
    required bool enforce,
    required ProfileThemeModel theme,
    bool showToast = true,
  }) async {
    final org = taploeState.organization;
    if (org == null || !_canManageDesign) return;
    setState(() => savingTeamDesign = true);
    try {
      await OrganizationRepository.saveTeamProfileTheme(
        org: org,
        enforce: enforce,
        theme: theme,
        logoUrl: null,
        coverPhotoUrl: _teamCover.text,
      );
      await taploeState.refreshAll();
      await load();
      if (mounted && showToast) {
        taploeToast(
          context,
          enforce
              ? 'Diseño compartido aplicado al equipo.'
              : 'Los miembros pueden diseñar sus perfiles.',
        );
      }
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos guardar el diseño del equipo.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => savingTeamDesign = false);
    }
  }

  Future<void> _saveTeamControls({
    required bool enforceForms,
    required bool enforceIntegrations,
  }) async {
    final org = taploeState.organization;
    if (org == null || !_canManageDesign) return;
    setState(() => savingTeamControls = true);
    try {
      await OrganizationRepository.saveTeamProfileControls(
        org: org,
        enforceForms: enforceForms,
        enforceIntegrations: enforceIntegrations,
      );
      await taploeState.refreshAll();
      await load();
      if (mounted) taploeToast(context, 'Permisos del equipo actualizados.');
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos guardar los permisos.', error: true);
      }
    } finally {
      if (mounted) setState(() => savingTeamControls = false);
    }
  }

  Future<void> _uploadTeamProfileAsset(
    String kind,
    TextEditingController controller,
  ) async {
    final org = taploeState.organization;
    final profile = taploeState.activeProfile;
    final authUserId = taploeState.client.auth.currentUser?.id;
    if (org == null || profile == null || authUserId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _profileAssetAllowedExtensions,
      withData: true,
      allowMultiple: false,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (!_isAllowedProfileAsset(file.name)) {
      if (mounted) {
        taploeToast(
          context,
          'Solo puedes cargar imágenes JPG, PNG, WEBP, HEIC, HEIF o SVG.',
          error: true,
        );
      }
      return;
    }

    if (!mounted) return;
    final editorBytes = _isSvgProfileAsset(file.name)
        ? await _rasterizeSvgToPng(context, bytes, kind: kind)
        : bytes;
    if (!mounted) return;
    final editedBytes = await _showProfileAssetEditor(
      context,
      kind: kind,
      bytes: editorBytes,
    );
    if (editedBytes == null) return;

    setState(() => savingTeamDesign = true);
    try {
      final url = await ProfileAssetRepository.uploadProfileAsset(
        authUserId: authUserId,
        profileId: profile.id,
        kind: 'team-$kind',
        bytes: editedBytes,
        fileName: '$kind.jpg',
      );
      controller.text = url;
      await _saveTeamTheme(
        enforce: org.enforceTeamProfileTheme,
        theme: _teamTheme(org),
        showToast: false,
      );
      if (mounted) taploeToast(context, 'Imagen compartida cargada.');
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos cargar la imagen.', error: true);
      }
    } finally {
      if (mounted) setState(() => savingTeamDesign = false);
    }
  }

  Future<void> _uploadCompanyLogo() async {
    final org = taploeState.organization;
    final authUserId = taploeState.client.auth.currentUser?.id;
    if (org == null || authUserId == null || !_canManageDesign) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _profileAssetAllowedExtensions,
      withData: true,
      allowMultiple: false,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (!_isAllowedProfileAsset(file.name)) {
      if (mounted) {
        taploeToast(
          context,
          'Solo puedes cargar imágenes JPG, PNG, WEBP, HEIC, HEIF o SVG.',
          error: true,
        );
      }
      return;
    }

    if (!mounted) return;
    final editorBytes = _isSvgProfileAsset(file.name)
        ? await _rasterizeSvgToPng(context, bytes, kind: 'logo')
        : bytes;
    if (!mounted) return;
    final editedBytes = await _showProfileAssetEditor(
      context,
      kind: 'logo',
      bytes: editorBytes,
    );
    if (editedBytes == null) return;

    setState(() => savingCompanyLogo = true);
    try {
      final url = await OrganizationAssetRepository.uploadCompanyLogo(
        authUserId: authUserId,
        bytes: editedBytes,
        fileName: 'company-logo.jpg',
      );
      await OrganizationRepository.updateCompanyLogo(org: org, logoUrl: url);
      await taploeState.refreshAll();
      await load();
      if (mounted) taploeToast(context, 'Logo de empresa actualizado.');
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos actualizar el logo.', error: true);
      }
    } finally {
      if (mounted) setState(() => savingCompanyLogo = false);
    }
  }

  Future<void> _removeCompanyLogo() async {
    final org = taploeState.organization;
    if (org == null || !_canManageDesign) return;
    setState(() => savingCompanyLogo = true);
    try {
      await OrganizationRepository.updateCompanyLogo(org: org, logoUrl: null);
      await taploeState.refreshAll();
      await load();
      if (mounted) taploeToast(context, 'Logo de empresa removido.');
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos quitar el logo.', error: true);
      }
    } finally {
      if (mounted) setState(() => savingCompanyLogo = false);
    }
  }

  String _memberNameForProfile(DigitalProfileModel profile) {
    for (final member in members) {
      if (member.id == profile.ownerUserId) return member.name;
    }
    return profile.companyName ?? 'Miembro del equipo';
  }

  String _memberEmailForProfile(DigitalProfileModel profile) {
    for (final member in members) {
      if (member.id == profile.ownerUserId) return member.email;
    }
    return '';
  }

  Future<void> _setProfileActive(
    DigitalProfileModel profile, {
    required bool active,
  }) async {
    if (!_canManageDesign) return;
    setState(() => updatingProfileId = profile.id);
    try {
      final updated = profile.copyWith(status: active ? 'active' : 'inactive');
      await ProfileRepository.updateProfile(updated);
      if (taploeState.activeProfile?.id == profile.id) {
        taploeState.updateActiveProfile(updated);
      }
      await load();
      if (mounted) {
        taploeToast(
          context,
          active ? 'Perfil activado.' : 'Perfil desactivado.',
        );
      }
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(context, 'No pudimos actualizar el perfil.', error: true);
      }
    } finally {
      if (mounted) setState(() => updatingProfileId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = taploeState.organization;
    final activeProfile = taploeState.activeProfile;
    return PageShell(
      title: 'Administración',
      subtitle:
          'Centraliza la gestión de tu equipo, su identidad y su operación desde un solo lugar.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : org == null
          ? const _TeamPlanRequestPanel()
          : Column(
              children: [
                _CompanyAdministrationHeader(
                  org: org,
                  canManage: _canManageDesign,
                  loadingLogo: savingCompanyLogo,
                  onUploadLogo: _uploadCompanyLogo,
                  onRemoveLogo: _removeCompanyLogo,
                  onManageTeam: widget.onManageTeam,
                ),
                const SizedBox(height: 16),
                if (_canManageDesign) ...[
                  _TeamDesignAdministrationPanel(
                    org: org,
                    profile: _teamDesignPreviewProfile(org),
                    logo: _teamLogo,
                    cover: _teamCover,
                    saving: savingTeamDesign,
                    onModeChanged: (enforce) => _saveTeamTheme(
                      enforce: enforce,
                      theme: _teamTheme(org),
                    ),
                    onThemeChanged: (theme) => _saveTeamTheme(
                      enforce: org.enforceTeamProfileTheme,
                      theme: theme,
                      showToast: false,
                    ),
                    onUploadLogo: _uploadCompanyLogo,
                    onUploadCover: () =>
                        _uploadTeamProfileAsset('cover', _teamCover),
                    onFormsModeChanged: (enforce) => _saveTeamControls(
                      enforceForms: enforce,
                      enforceIntegrations: org.enforceTeamProfileIntegrations,
                    ),
                    onIntegrationsModeChanged: (enforce) => _saveTeamControls(
                      enforceForms: org.enforceTeamProfileForms,
                      enforceIntegrations: enforce,
                    ),
                    formsContent: activeProfile == null
                        ? const TaploeEmpty(
                            title: 'Sin perfil activo',
                            message:
                                'Selecciona o crea un perfil para administrar formularios.',
                          )
                        : _AdminCompactFormsSection(
                            forms: forms,
                            onCreate: () async {
                              await _showFormEditorDialog(
                                context,
                                profile: activeProfile,
                              );
                              await load();
                            },
                            onEdit: (form) async {
                              await _showFormEditorDialog(
                                context,
                                profile: activeProfile,
                                form: form,
                              );
                              await load();
                            },
                          ),
                    integrationsContent: activeProfile == null
                        ? const TaploeEmpty(
                            title: 'Sin perfil activo',
                            message:
                                'Selecciona o crea un perfil para administrar integraciones.',
                          )
                        : _AdminCompactIntegrationsSection(
                            integrations: integrations,
                            onCreate: () async {
                              await _showIntegrationEditorDialog(
                                context,
                                profile: activeProfile,
                              );
                              await load();
                            },
                            onEdit: (integration) async {
                              await _showIntegrationEditorDialog(
                                context,
                                profile: activeProfile,
                                integration: integration,
                              );
                              await load();
                            },
                          ),
                    savingControls: savingTeamControls,
                  ),
                  const SizedBox(height: 16),
                  _TeamProfilesAdministrationPanel(
                    profiles: teamProfiles,
                    memberNameForProfile: _memberNameForProfile,
                    memberEmailForProfile: _memberEmailForProfile,
                    updatingProfileId: updatingProfileId,
                    onEditProfile: widget.onEditProfile,
                    onInviteMember: widget.onManageTeam,
                    onActiveChanged: (profile, active) =>
                        _setProfileActive(profile, active: active),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

class _CompanyAdministrationHeader extends StatelessWidget {
  final OrganizationModel org;
  final bool canManage;
  final bool loadingLogo;
  final VoidCallback onUploadLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onManageTeam;

  const _CompanyAdministrationHeader({
    required this.org,
    required this.canManage,
    required this.loadingLogo,
    required this.onUploadLogo,
    required this.onRemoveLogo,
    required this.onManageTeam,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = org.logoUrl;
    final hasLogo = logoUrl != null && logoUrl.trim().isNotEmpty;
    return TaploePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 840;
          final logo = Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TaploeColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: TaploeColors.border),
            ),
            child: hasLogo
                ? Image.network(
                    logoUrl.trim(),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.business_rounded),
                  )
                : const Center(child: Icon(Icons.business_rounded)),
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    org.name,
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: context.text,
                      height: 1,
                    ),
                  ),
                  _PlanBadge(label: 'Plan ${org.planType.toUpperCase()}'),
                ],
              ),
              if (org.websiteUrl?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      size: 17,
                      color: TaploeColors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      org.websiteUrl!.trim(),
                      style: GoogleFonts.dmSans(
                        color: context.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              if (canManage)
                TaploeButton(
                  width: 172,
                  label: hasLogo ? 'Cambiar logo' : 'Agregar logo',
                  icon: Icons.edit_outlined,
                  kind: TaploeButtonKind.secondary,
                  loading: loadingLogo,
                  onPressed: loadingLogo ? null : onUploadLogo,
                ),
              TaploeButton(
                width: 204,
                label: 'Compartir acceso',
                icon: Icons.person_add_alt_1_outlined,
                kind: TaploeButtonKind.secondary,
                onPressed: onManageTeam,
              ),
              TaploeButton(
                width: 204,
                label: 'Gestionar equipo',
                icon: Icons.groups_2_outlined,
                kind: TaploeButtonKind.secondary,
                onPressed: onManageTeam,
              ),
              if (canManage && hasLogo)
                IconButton.outlined(
                  tooltip: 'Quitar logo',
                  onPressed: loadingLogo ? null : onRemoveLogo,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          );

          final middle = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    logo,
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 18),
                actions,
              ],
            );
          }
          return Row(
            children: [
              logo,
              const SizedBox(width: 22),
              middle,
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String label;

  const _PlanBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        border: Border.all(color: TaploeColors.blue),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: TaploeColors.blue,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TeamDesignAdministrationPanel extends StatelessWidget {
  final OrganizationModel org;
  final DigitalProfileModel profile;
  final TextEditingController logo;
  final TextEditingController cover;
  final bool saving;
  final bool savingControls;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<bool> onFormsModeChanged;
  final ValueChanged<bool> onIntegrationsModeChanged;
  final VoidCallback onUploadLogo;
  final VoidCallback onUploadCover;
  final Future<void> Function(ProfileThemeModel theme) onThemeChanged;
  final Widget formsContent;
  final Widget integrationsContent;

  const _TeamDesignAdministrationPanel({
    required this.org,
    required this.profile,
    required this.logo,
    required this.cover,
    required this.saving,
    required this.savingControls,
    required this.onModeChanged,
    required this.onFormsModeChanged,
    required this.onIntegrationsModeChanged,
    required this.onUploadLogo,
    required this.onUploadCover,
    required this.onThemeChanged,
    required this.formsContent,
    required this.integrationsContent,
  });

  @override
  Widget build(BuildContext context) {
    final enforced = org.enforceTeamProfileTheme;
    return TaploePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdminConsistencyHeader(saving: saving),
          const SizedBox(height: 24),
          _AdminConsistencyGrid(
            designEnabled: enforced,
            formsEnabled: org.enforceTeamProfileForms,
            integrationsEnabled: org.enforceTeamProfileIntegrations,
            saving: saving || savingControls,
            onDesignChanged: onModeChanged,
            onFormsChanged: onFormsModeChanged,
            onIntegrationsChanged: onIntegrationsModeChanged,
          ),
          if (enforced) ...[
            const SizedBox(height: 22),
            _AdminManagedContent(
              child: _DesignStudio(
                profile: profile,
                logo: logo,
                cover: cover,
                showVerifiedBadge: false,
                onVerifiedBadgeChanged: (_) {},
                uploadingAsset: null,
                onUploadLogo: onUploadLogo,
                onManageCompanyLogo: onUploadLogo,
                onUploadCover: onUploadCover,
                companyLogoUrl: org.logoUrl,
                companyLogoManaged: true,
                onThemeChanged: onThemeChanged,
                title: 'Identidad visual compartida',
                description:
                    'Estos cambios se aplican a todos los perfiles activos de ${org.name}.',
                showIdentityControls: true,
                showPreviewButton: false,
                showVerifiedControl: false,
              ),
            ),
          ],
          if (org.enforceTeamProfileForms) ...[
            const SizedBox(height: 14),
            _AdminManagedContent(child: formsContent),
          ],
          if (org.enforceTeamProfileIntegrations) ...[
            const SizedBox(height: 14),
            _AdminManagedContent(child: integrationsContent),
          ],
        ],
      ),
    );
  }
}

class _AdminConsistencyHeader extends StatelessWidget {
  final bool saving;

  const _AdminConsistencyHeader({required this.saving});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consistencia del equipo',
                style: GoogleFonts.outfit(
                  color: context.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Define qué elementos se mantienen iguales para todos los perfiles y cuáles puede personalizar cada miembro.',
                style: GoogleFonts.dmSans(color: context.muted, height: 1.35),
              ),
            ],
          ),
        ),
        if (saving)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _AdminConsistencyGrid extends StatelessWidget {
  final bool designEnabled;
  final bool formsEnabled;
  final bool integrationsEnabled;
  final bool saving;
  final ValueChanged<bool> onDesignChanged;
  final ValueChanged<bool> onFormsChanged;
  final ValueChanged<bool> onIntegrationsChanged;

  const _AdminConsistencyGrid({
    required this.designEnabled,
    required this.formsEnabled,
    required this.integrationsEnabled,
    required this.saving,
    required this.onDesignChanged,
    required this.onFormsChanged,
    required this.onIntegrationsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 2.75 : 2.15,
          children: [
            _AdminConsistencyCard(
              icon: Icons.palette_outlined,
              title: 'Diseño compartido',
              description: 'Usa los mismos colores, portada y estilo visual.',
              enabled: designEnabled,
              onChanged: saving ? null : onDesignChanged,
            ),
            _AdminConsistencyCard(
              icon: Icons.dynamic_form_outlined,
              title: 'Formulario compartido',
              description:
                  'Usa el mismo formulario de captura para todos los perfiles.',
              enabled: formsEnabled,
              onChanged: saving ? null : onFormsChanged,
            ),
            _AdminConsistencyCard(
              icon: Icons.add_link_rounded,
              title: 'Integración compartida',
              description:
                  'Usa las mismas conexiones externas para todos los perfiles.',
              enabled: integrationsEnabled,
              onChanged: saving ? null : onIntegrationsChanged,
            ),
          ],
        );
      },
    );
  }
}

class _AdminConsistencyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _AdminConsistencyCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: TaploeColors.blue, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        color: context.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: GoogleFonts.dmSans(
                        color: context.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _PlainStatusLabel(
                text: enabled ? 'Activo' : 'Inactivo',
                icon: enabled
                    ? Icons.check_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
                color: enabled ? TaploeColors.success : context.muted,
              ),
              const Spacer(),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminManagedContent extends StatelessWidget {
  final Widget child;

  const _AdminManagedContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 20),
      child: child,
    );
  }
}

class _TeamProfilesAdministrationPanel extends StatelessWidget {
  final List<DigitalProfileModel> profiles;
  final String Function(DigitalProfileModel profile) memberNameForProfile;
  final String Function(DigitalProfileModel profile) memberEmailForProfile;
  final String? updatingProfileId;
  final ValueChanged<DigitalProfileModel> onEditProfile;
  final VoidCallback onInviteMember;
  final void Function(DigitalProfileModel profile, bool active) onActiveChanged;

  const _TeamProfilesAdministrationPanel({
    required this.profiles,
    required this.memberNameForProfile,
    required this.memberEmailForProfile,
    required this.updatingProfileId,
    required this.onEditProfile,
    required this.onInviteMember,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = profiles
        .where((profile) => profile.status == 'active')
        .length;
    final inactiveCount = profiles
        .where((profile) => profile.status != 'active')
        .length;
    return TaploePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 860;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perfiles del equipo',
                    style: GoogleFonts.outfit(
                      color: context.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Gestiona los perfiles digitales de tu equipo.',
                    style: GoogleFonts.dmSans(
                      color: context.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _AdminProfileMetric(
                    icon: Icons.badge_outlined,
                    value: '${profiles.length}',
                    label: 'Perfiles',
                    color: TaploeColors.blue,
                  ),
                  _AdminProfileMetric(
                    icon: Icons.check_circle_outline_rounded,
                    value: '$activeCount',
                    label: 'Activos',
                    color: TaploeColors.success,
                  ),
                  _AdminProfileMetric(
                    icon: Icons.pause_circle_outline_rounded,
                    value: '$inactiveCount',
                    label: 'Inactivos',
                    color: context.muted,
                  ),
                  TaploeButton(
                    width: 190,
                    label: 'Invitar miembro',
                    icon: Icons.person_add_alt_1_outlined,
                    onPressed: onInviteMember,
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 16), actions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (profiles.isEmpty)
            const _AdminEmptyLine(
              icon: Icons.person_off_outlined,
              text: 'Aún no hay perfiles dentro de esta empresa.',
            )
          else ...[
            const _TeamProfilesTableHeader(),
            ...profiles.map(
              (profile) => _TeamProfileAdminRow(
                profile: profile,
                ownerName: memberNameForProfile(profile),
                ownerEmail: memberEmailForProfile(profile),
                updating: updatingProfileId == profile.id,
                onEdit: () => onEditProfile(profile),
                onActiveChanged: (active) => onActiveChanged(profile, active),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminProfileMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _AdminProfileMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamProfilesTableHeader extends StatelessWidget {
  const _TeamProfilesTableHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: TaploeColors.border),
              bottom: BorderSide(color: TaploeColors.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _AdminTableLabel('Miembro')),
              Expanded(flex: 3, child: _AdminTableLabel('Cargo / Empresa')),
              Expanded(flex: 3, child: _AdminTableLabel('Perfil público')),
              Expanded(
                flex: 2,
                child: _AdminTableLabel(taploeState.t.text('Estado', 'Status')),
              ),
              Expanded(flex: 3, child: _AdminTableLabel('Progreso')),
              SizedBox(width: 330, child: _AdminTableLabel('Acciones')),
            ],
          ),
        );
      },
    );
  }
}

class _AdminTableLabel extends StatelessWidget {
  final String text;

  const _AdminTableLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        color: context.muted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TeamProfileAdminRow extends StatelessWidget {
  final DigitalProfileModel profile;
  final String ownerName;
  final String ownerEmail;
  final bool updating;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  const _TeamProfileAdminRow({
    required this.profile,
    required this.ownerName,
    required this.ownerEmail,
    required this.updating,
    required this.onEdit,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = profile.status == 'active';
    final completion = _profileCompletion(profile);
    final publicUrl = TaploeConfig.profileUrl(profile.publicSlug);
    final ownerLabel = ownerEmail.isEmpty
        ? ownerName
        : '$ownerName · $ownerEmail';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: TaploeColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;
          final member = Row(
            children: [
              _ProfileAvatarMini(profile: profile),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ownerName.isEmpty ? profile.displayName : ownerName,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
          final role = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.jobTitle?.trim().isNotEmpty == true
                    ? profile.jobTitle!
                    : 'Sin cargo',
                style: GoogleFonts.dmSans(
                  color: context.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                profile.companyName?.trim().isNotEmpty == true
                    ? profile.companyName!
                    : ownerLabel,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: GoogleFonts.dmSans(color: context.muted, fontSize: 12),
              ),
            ],
          );
          final link = InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final uri = Uri.tryParse(publicUrl);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    publicUrl.replaceFirst('https://', ''),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: GoogleFonts.dmSans(
                      color: TaploeColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: TaploeColors.blue,
                  size: 15,
                ),
              ],
            ),
          );
          final progress = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                color: completion >= 80 ? TaploeColors.success : context.muted,
                size: 10,
              ),
              const SizedBox(width: 8),
              Text(
                'Completo $completion%',
                style: GoogleFonts.dmSans(
                  color: context.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          final status = _PlainStatusLabel(
            text: active ? 'Activo' : 'Inactivo',
            icon: active
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            color: active ? TaploeColors.success : context.muted,
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaploeButton(
                width: 112,
                label: 'Ver',
                icon: Icons.visibility_outlined,
                kind: TaploeButtonKind.secondary,
                onPressed: () {
                  final uri = Uri.tryParse(publicUrl);
                  if (uri != null) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(width: 8),
              TaploeButton(
                width: 120,
                label: 'Editar',
                icon: Icons.edit_outlined,
                kind: TaploeButtonKind.secondary,
                onPressed: onEdit,
              ),
              const SizedBox(width: 8),
              updating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(value: active, onChanged: onActiveChanged),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                member,
                const SizedBox(height: 10),
                role,
                const SizedBox(height: 8),
                link,
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [status, progress, actions],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: member),
              Expanded(flex: 3, child: role),
              Expanded(flex: 3, child: link),
              Expanded(flex: 2, child: status),
              Expanded(flex: 3, child: progress),
              SizedBox(width: 330, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _PlainStatusLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _PlainStatusLabel({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.dmSans(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatarMini extends StatelessWidget {
  final DigitalProfileModel profile;

  const _ProfileAvatarMini({required this.profile});

  @override
  Widget build(BuildContext context) {
    final photo = profile.profilePhotoUrl;
    return Container(
      width: 46,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TaploeColors.page,
        border: Border.all(color: TaploeColors.border),
      ),
      child: photo == null || photo.trim().isEmpty
          ? const Icon(Icons.person_outline_rounded, color: TaploeColors.blue)
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_outline_rounded,
                color: TaploeColors.blue,
              ),
            ),
    );
  }
}

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final timezone = TextEditingController();
  TaploeLocaleConfig selectedLocale = TaploeLocaleConfig.esMx;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _fill();
    taploeState.addListener(_fill);
  }

  @override
  void dispose() {
    taploeState.removeListener(_fill);
    name.dispose();
    phone.dispose();
    timezone.dispose();
    super.dispose();
  }

  void _fill() {
    if (saving) return;
    final user = taploeState.currentUser;
    if (user == null) return;
    if (name.text == user.username &&
        phone.text == (user.phone ?? '') &&
        timezone.text == user.timezone &&
        selectedLocale.localeCode == taploeState.localeConfig.localeCode) {
      return;
    }
    name.text = user.username;
    phone.text = user.phone ?? '';
    timezone.text = user.timezone;
    selectedLocale = taploeState.localeConfig;
  }

  Future<void> save() async {
    final user = taploeState.currentUser;
    if (user == null) return;
    final localeToSave = selectedLocale;

    final requestedUsername = UserRepository.normalizeUsername(name.text);
    if (requestedUsername.length < 3) {
      taploeToast(
        context,
        'El nombre de usuario debe tener al menos 3 letras o números.',
        error: true,
      );
      return;
    }

    final currentUsername = UserRepository.normalizeUsername(user.username);
    final usernameChanged = requestedUsername != currentUsername;
    final profile = taploeState.activeProfile;
    final willChangePublicLink =
        usernameChanged &&
        profile != null &&
        requestedUsername != profile.publicSlug;

    if (willChangePublicLink) {
      final confirmed = await _confirmUsernamePublicLinkChange(
        context,
        currentSlug: profile.publicSlug,
        nextSlug: requestedUsername,
      );
      if (confirmed != true) return;
    }

    setState(() => saving = true);
    try {
      if (usernameChanged) {
        final usernameTaken = await UserRepository.usernameExists(
          requestedUsername,
          excludeUserId: user.id,
        );
        if (usernameTaken) {
          if (mounted) {
            taploeToast(
              context,
              'Ese nombre de usuario ya está en uso.',
              error: true,
            );
          }
          return;
        }

        if (profile != null) {
          final slugTaken = await ProfileRepository.slugExists(
            requestedUsername,
            excludeProfileId: profile.id,
          );
          if (slugTaken) {
            if (mounted) {
              taploeToast(
                context,
                'Ese enlace público ya está en uso.',
                error: true,
              );
            }
            return;
          }
        }
      }

      final updatedUser = await UserRepository.updateCurrentUser(
        username: requestedUsername,
        phone: phone.text,
        timezone: timezone.text,
        preferredLanguage: localeToSave.languageCode,
        preferredMarket: localeToSave.marketCode,
      );
      taploeState.updateCurrentUser(updatedUser);
      await taploeState.updateLocale(localeToSave);

      if (profile != null && usernameChanged) {
        final updatedProfile = profile.copyWith(
          publicSlug: requestedUsername,
          publicLocale: localeToSave.localeCode,
        );
        taploeState.updateActiveProfile(updatedProfile);
        await ProfileRepository.updateProfile(updatedProfile);
      }

      await taploeState.refreshAll();
      if (mounted) taploeToast(context, 'Configuración actualizada.');
    } catch (e) {
      safePrintError(e);
      if (mounted) {
        taploeToast(context, _settingsSaveErrorMessage(e), error: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = taploeState.currentUser;
    final org = taploeState.organization;
    final capabilities = taploeState.capabilities;
    final t = taploeState.t;
    final billingSubscription =
        taploeState.organizationSubscription ?? taploeState.userSubscription;
    return PageShell(
      title: t.settings,
      subtitle: t.text(
        'Cuenta, preferencias, organización, seguridad y plan.',
        'Account, preferences, organization, security, and plan.',
      ),
      actions: [
        TaploeButton(
          label: t.save,
          width: 122,
          loading: saving,
          onPressed: save,
        ),
      ],
      child: user == null
          ? const TaploeEmpty(
              title: 'Sin usuario',
              message: 'Inicia sesión para editar tu configuración.',
            )
          : _ResponsivePair(
              breakpoint: 980,
              leftFlex: 5,
              rightFlex: 4,
              left: Column(
                children: [
                  TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: t.text('Cuenta', 'Account'),
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 14),
                        TaploeTextField(
                          label: t.text('Nombre de usuario', 'Username'),
                          controller: name,
                          keyboardType: TextInputType.url,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9-]'),
                            ),
                          ],
                          onSubmitted: (_) => save(),
                        ),
                        const SizedBox(height: 12),
                        TaploeTextField(
                          label: 'Email',
                          controller: TextEditingController(text: user.email),
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        TaploeTextField(
                          label: t.text('Teléfono', 'Phone'),
                          controller: phone,
                          onSubmitted: (_) => save(),
                        ),
                        const SizedBox(height: 12),
                        TaploeTextField(
                          label: t.text('Zona horaria', 'Time zone'),
                          controller: timezone,
                          onSubmitted: (_) => save(),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          t.localeAndMarket,
                          style: GoogleFonts.dmSans(
                            color: context.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<TaploeLocaleConfig>(
                          initialValue: selectedLocale,
                          decoration: InputDecoration(
                            labelText: t.marketAndCurrency,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: TaploeColors.border,
                              ),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: TaploeLocaleConfig.esMx,
                              child: Text(t.spanishMexico),
                            ),
                            DropdownMenuItem(
                              value: TaploeLocaleConfig.enUs,
                              child: Text(t.englishUs),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedLocale = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: t.text('Seguridad', 'Security'),
                          icon: Icons.lock_outline_rounded,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.text(
                            'Tu sesión usa autenticación OTP por correo. Puedes cerrarla desde aquí.',
                            'Your session uses email OTP authentication. You can sign out here.',
                          ),
                          style: GoogleFonts.dmSans(color: context.muted),
                        ),
                        const SizedBox(height: 14),
                        TaploeButton(
                          label: t.text('Cerrar sesión', 'Sign out'),
                          icon: Icons.logout_rounded,
                          kind: TaploeButtonKind.secondary,
                          onPressed: taploeState.signOut,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              right: Column(
                children: [
                  _BillingSettingsPanel(
                    user: user,
                    organization: org,
                    subscription: billingSubscription,
                    invoices: taploeState.billingInvoices,
                    capabilities: capabilities,
                  ),
                  const SizedBox(height: 16),
                  TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: t.text('Preferencias', 'Preferences'),
                          icon: Icons.tune_rounded,
                        ),
                        const SizedBox(height: 12),
                        _CheckRow(
                          label: t.text(
                            'Perfil predeterminado configurado',
                            'Default profile configured',
                          ),
                          done: taploeState.activeProfile != null,
                        ),
                        const SizedBox(height: 8),
                        _MutedText(
                          t.text(
                            'Las preferencias de notificaciones se conectarán cuando exista una tabla de preferencias o integración de email/webhook.',
                            'Notification preferences will be connected when a preferences table or email/webhook integration exists.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: t.text('Organización', 'Organization'),
                          icon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 12),
                        if (org == null)
                          _MutedText(
                            t.text(
                              'Esta cuenta todavía no pertenece a una organización.',
                              'This account does not belong to an organization yet.',
                            ),
                          )
                        else ...[
                          _InfoLine(
                            label: t.text('Nombre', 'Name'),
                            value: org.name,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BillingSettingsPanel extends StatelessWidget {
  final AppUserModel user;
  final OrganizationModel? organization;
  final BillingSubscriptionModel? subscription;
  final List<BillingInvoiceModel> invoices;
  final TaploePlanCapabilities capabilities;

  const _BillingSettingsPanel({
    required this.user,
    required this.organization,
    required this.subscription,
    required this.invoices,
    required this.capabilities,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    final hasStripe = sub?.stripeSubscriptionId?.trim().isNotEmpty == true;
    final isOrgBilling = sub?.isOrganizationScope == true;
    final ownerCanManage =
        sub == null || sub.ownerUserId.isEmpty || sub.ownerUserId == user.id;
    final status = _billingStatusLabel(sub);
    final statusColor = _billingStatusColor(sub);
    final t = taploeState.t;
    final billingScopeLabel = isOrgBilling
        ? t.text('Empresa / equipo', 'Business / team')
        : t.text('Individual', 'Individual');
    final ownerLabel = isOrgBilling
        ? organization?.name ?? t.text('Organización', 'Organization')
        : user.username;
    final renewalLabel = sub == null
        ? t.text('Sin suscripción', 'No subscription')
        : sub.cancelAtPeriodEnd
        ? t.text('Cancelada al final del periodo', 'Canceled at period end')
        : sub.grantsAccess
        ? t.text('Activa', 'Active')
        : t.text('Inactiva', 'Inactive');
    final paymentDateLabel = _dateLabel(sub?.nextChargeAt);
    final manageScope = isOrgBilling ? 'organization' : 'user';
    return TaploePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: TaploeColors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.billing,
                  style: GoogleFonts.outfit(
                    color: context.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _BillingPlanBadge(label: capabilities.label),
            ],
          ),
          const SizedBox(height: 12),
          _BillingStatusLine(
            label: status,
            color: statusColor,
            message: _billingStatusMessage(
              subscription: sub,
              capabilities: capabilities,
              organization: organization,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: TaploeColors.border),
          const SizedBox(height: 18),
          _BillingDetailRow(label: t.currentPlan, value: capabilities.label),
          _BillingDetailRow(
            label: t.text('Tipo de plan', 'Plan type'),
            value: billingScopeLabel,
          ),
          _BillingDetailRow(
            label: t.text('Responsable', 'Owner'),
            value: ownerLabel,
          ),
          _BillingDetailRow(
            label: t.text('Ciclo', 'Cycle'),
            value: _billingIntervalLabel(sub?.billingInterval),
          ),
          _BillingDetailRow(
            label: sub?.cancelAtPeriodEnd == true
                ? t.text('Acceso hasta', 'Access until')
                : t.text('Próximo pago', 'Next payment'),
            value: paymentDateLabel,
          ),
          _BillingDetailRow(
            label: t.text('Renovación automática', 'Auto-renewal'),
            value: renewalLabel,
          ),
          if (sub?.isPastDue == true) ...[
            const SizedBox(height: 6),
            _BillingWarningLine(
              text:
                  'El pago está pendiente. Si supera ${_dateLabel(sub?.graceUntil)}, el sistema quitará beneficios automáticamente sin borrar tus datos.',
            ),
          ],
          if (sub == null) ...[
            const SizedBox(height: 6),
            const _BillingWarningLine(
              text:
                  'No hay una suscripción registrada en billing_subscriptions. La app no otorgará beneficios de pago hasta que exista una suscripción vigente.',
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: TaploeColors.border),
          const SizedBox(height: 18),
          _BillingActionRow(
            cancelLabel: sub?.cancelAtPeriodEnd == true ? t.resume : t.cancel,
            canManage: hasStripe && ownerCanManage,
            onChangePlan: () => _showPlansDialog(context),
            onManageSubscription: hasStripe && ownerCanManage
                ? () => _openBillingPortal(context, scope: manageScope)
                : null,
            onCancel: hasStripe && ownerCanManage
                ? () => _openBillingPortal(context, scope: manageScope)
                : null,
          ),
          if (!ownerCanManage || (!hasStripe && sub != null)) ...[
            const SizedBox(height: 12),
            _BillingQuietNote(
              text: !ownerCanManage
                  ? t.text(
                      'Solo el owner que contrató la suscripción puede cambiar pago, cancelar o reanudar.',
                      'Only the owner who purchased the subscription can change payment, cancel, or resume.',
                    )
                  : t.text(
                      'Las acciones de cobro se activan cuando Stripe sincronice esta suscripción.',
                      'Billing actions become available when Stripe syncs this subscription.',
                    ),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: TaploeColors.border),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                color: TaploeColors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.paymentHistory,
                  style: GoogleFonts.outfit(
                    color: context.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (invoices.isEmpty)
            _MutedText(t.noInvoices)
          else
            for (final invoice in invoices.take(6))
              _BillingInvoiceRow(invoice: invoice),
          const SizedBox(height: 18),
          _BillingSecureNote(
            text: t.text(
              'Tus pagos se procesan de forma segura a través de Stripe.',
              'Your payments are processed securely through Stripe.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingPlanBadge extends StatelessWidget {
  final String label;

  const _BillingPlanBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TaploeColors.blue.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: TaploeColors.blue,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BillingStatusLine extends StatelessWidget {
  final String label;
  final Color color;
  final String message;

  const _BillingStatusLine({
    required this.label,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
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
  }
}

class _BillingDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _BillingDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: context.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: GoogleFonts.dmSans(
                color: context.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingActionRow extends StatelessWidget {
  final String cancelLabel;
  final bool canManage;
  final VoidCallback onChangePlan;
  final VoidCallback? onManageSubscription;
  final VoidCallback? onCancel;

  const _BillingActionRow({
    required this.cancelLabel,
    required this.canManage,
    required this.onChangePlan,
    required this.onManageSubscription,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TaploeButton(
          width: 178,
          label: taploeState.t.changePlan,
          icon: Icons.workspace_premium_outlined,
          kind: TaploeButtonKind.secondary,
          onPressed: onChangePlan,
        ),
        TaploeButton(
          width: 225,
          label: taploeState.t.manageSubscription,
          icon: Icons.credit_card_outlined,
          kind: TaploeButtonKind.secondary,
          onPressed: canManage ? onManageSubscription : null,
        ),
        TextButton(
          onPressed: canManage ? onCancel : null,
          style: TextButton.styleFrom(
            foregroundColor: TaploeColors.error,
            disabledForegroundColor: TaploeColors.muted,
            textStyle: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(cancelLabel),
        ),
      ],
    );
  }
}

class _BillingQuietNote extends StatelessWidget {
  final String text;

  const _BillingQuietNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        color: context.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }
}

class _BillingSecureNote extends StatelessWidget {
  final String text;

  const _BillingSecureNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: TaploeColors.muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _BillingWarningLine extends StatelessWidget {
  final String text;

  const _BillingWarningLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: TaploeColors.warning,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _BillingInvoiceRow extends StatelessWidget {
  final BillingInvoiceModel invoice;

  const _BillingInvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final url = invoice.hostedInvoiceUrl ?? invoice.invoicePdf;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaploeColors.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        children: [
          Icon(
            invoice.status == 'paid'
                ? Icons.check_circle_outline_rounded
                : Icons.receipt_long_outlined,
            color: invoice.status == 'paid'
                ? TaploeColors.success
                : TaploeColors.blue,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_moneyLabel(invoice.amountPaid == 0 ? invoice.amountDue : invoice.amountPaid, invoice.currency)} · ${_invoiceStatusLabel(invoice.status)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateLabel(invoice.paidAt ?? invoice.createdAt),
                  style: GoogleFonts.dmSans(
                    color: context.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (url != null && url.isNotEmpty)
            IconButton(
              tooltip: 'Abrir factura',
              onPressed: () {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
    );
  }
}

String _billingStatusLabel(BillingSubscriptionModel? subscription) {
  final t = taploeState.t;
  if (subscription == null) {
    return t.text('Sin suscripción registrada', 'No subscription recorded');
  }
  if (subscription.cancelAtPeriodEnd && subscription.grantsAccess) {
    return t.text('Cancelación programada', 'Cancellation scheduled');
  }
  return switch (subscription.status) {
    'trialing' => t.text('Prueba gratis activa', 'Free trial active'),
    'active' => t.text('Suscripción activa', 'Subscription active'),
    'past_due' => t.text('Pago pendiente', 'Payment pending'),
    'grace_period' => t.text('Periodo de gracia', 'Grace period'),
    'canceled' => t.text('Cancelada', 'Canceled'),
    'expired' => t.text('Vencida', 'Expired'),
    'unpaid' => t.text('Impago', 'Unpaid'),
    _ => subscription.status,
  };
}

Color _billingStatusColor(BillingSubscriptionModel? subscription) {
  if (subscription == null) return TaploeColors.muted;
  if (subscription.grantsAccess && subscription.isPastDue) {
    return TaploeColors.warning;
  }
  if (subscription.grantsAccess) return TaploeColors.success;
  return TaploeColors.error;
}

String _billingStatusMessage({
  required BillingSubscriptionModel? subscription,
  required TaploePlanCapabilities capabilities,
  required OrganizationModel? organization,
}) {
  final t = taploeState.t;
  if (subscription == null) {
    return t.text(
      'Tu plan efectivo es ${capabilities.label}. Si esperabas Premium o Empresa, falta crear o sincronizar la suscripción.',
      'Your effective plan is ${capabilities.label}. If you expected Premium or Business, the subscription still needs to be created or synced.',
    );
  }
  if (subscription.grantsAccess && subscription.isOrganizationScope) {
    return t.text(
      'La organización ${organization?.name ?? ''} otorga beneficios ${capabilities.label} mientras la suscripción esté vigente.',
      'The organization ${organization?.name ?? ''} grants ${capabilities.label} benefits while the subscription is active.',
    );
  }
  if (subscription.grantsAccess) {
    return t.text(
      'Tu cuenta tiene beneficios ${capabilities.label} mientras la suscripción esté vigente.',
      'Your account has ${capabilities.label} benefits while the subscription is active.',
    );
  }
  if (subscription.isOrganizationScope) {
    return t.text(
      'La organización conserva miembros e historial, pero no otorga beneficios de pago hasta renovar.',
      'The organization keeps members and history, but paid benefits stay off until renewal.',
    );
  }
  return t.text(
    'La cuenta vuelve a Gratis hasta que se reactive una suscripción vigente.',
    'The account returns to Free until an active subscription is restored.',
  );
}

String _billingIntervalLabel(String? interval) => switch (interval) {
  'annual' => taploeState.t.annual,
  'monthly' => taploeState.t.monthly,
  null || '' => taploeState.t.text('No definido', 'Not set'),
  _ => interval,
};

String _invoiceStatusLabel(String status) => switch (status) {
  'paid' => 'Pagada',
  'open' => 'Abierta',
  'failed' => 'Fallida',
  'void' => 'Anulada',
  'uncollectible' => 'Incobrable',
  'draft' => 'Borrador',
  _ => status,
};

String _dateLabel(DateTime? value) {
  if (value == null) return 'No definido';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _moneyLabel(double amount, String currency) {
  final fixed = amount.toStringAsFixed(2);
  return '$currency $fixed';
}

Future<bool?> _confirmUsernamePublicLinkChange(
  BuildContext context, {
  required String currentSlug,
  required String nextSlug,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Cambiar enlace público',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Si cambias tu nombre de usuario, también cambiará el enlace público de tu perfil.',
            style: GoogleFonts.dmSans(color: context.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          _InfoLine(
            label: 'Actual',
            value: TaploeConfig.profileUrl(currentSlug),
          ),
          _InfoLine(label: 'Nuevo', value: TaploeConfig.profileUrl(nextSlug)),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TaploeButton(
          width: 130,
          label: 'Cancelar',
          kind: TaploeButtonKind.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        TaploeButton(
          width: 190,
          label: 'Cambiar enlace',
          icon: Icons.link_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
}

String _settingsSaveErrorMessage(Object error) {
  if (error is ArgumentError) {
    final message = error.message?.toString();
    if (message == 'username_too_short') {
      return 'El nombre de usuario debe tener al menos 3 letras o números.';
    }
    if (message == 'username_taken') {
      return 'Ese nombre de usuario ya está en uso.';
    }
  }

  if (error is PostgrestException && error.code == '23505') {
    final combined = '${error.message} ${error.details ?? ''}'.toLowerCase();
    if (combined.contains('full_name') ||
        combined.contains('username') ||
        combined.contains('app_users')) {
      return 'Ese nombre de usuario ya está en uso.';
    }
    if (combined.contains('public_slug') ||
        combined.contains('digital_profiles_public_slug_key')) {
      return 'Ese enlace público ya está en uso.';
    }
  }

  return 'No pudimos guardar la configuración. Intenta de nuevo.';
}
