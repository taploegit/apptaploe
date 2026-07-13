import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../profile_public_card.dart';
import '../qr_scanner.dart';
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
  share,
  analytics,
  leads,
  team,
  admin,
  settings,
}

class _DashboardViewState extends State<DashboardView> {
  late DashboardSection section;

  @override
  void initState() {
    super.initState();
    section = widget.initialSection;
    taploeState.addListener(_handleTaploeStateChanged);
  }

  @override
  void dispose() {
    taploeState.removeListener(_handleTaploeStateChanged);
    super.dispose();
  }

  void _handleTaploeStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (taploeState.bootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!taploeState.canAccessDashboard) {
      return _CardRequiredView(
        onLinkCard: () => _showCardLinkingDialog(context),
      );
    }

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
              onSelected: (s) => setState(() => section = s),
            ),
          Expanded(
            child: Column(
              children: [
                if (!context.isMobile)
                  _TopHeader(
                    selected: section,
                    onSelected: (s) => setState(() => section = s),
                  ),
                Expanded(child: _content()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: context.isMobile
          ? NavigationBar(
              selectedIndex: [
                DashboardSection.home,
                DashboardSection.profile,
                DashboardSection.share,
                DashboardSection.analytics,
                DashboardSection.leads,
              ].indexOf(section).clamp(0, 4),
              onDestinationSelected: (i) => setState(
                () => section = [
                  DashboardSection.home,
                  DashboardSection.profile,
                  DashboardSection.share,
                  DashboardSection.analytics,
                  DashboardSection.leads,
                ][i],
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  label: 'Perfil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.ios_share_rounded),
                  label: 'Compartir',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: 'Métricas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_rounded),
                  label: 'Leads',
                ),
              ],
            )
          : null,
    );
  }

  Widget _content() {
    switch (section) {
      case DashboardSection.home:
        return const HomeOverviewView();
      case DashboardSection.profile:
        return ProfileEditorView(initialStep: widget.initialProfileStep);
      case DashboardSection.cards:
        return const CardManagerView();
      case DashboardSection.share:
        return const ShareCenterView();
      case DashboardSection.analytics:
        return const AnalyticsDashboardView();
      case DashboardSection.leads:
        return const LeadsView();
      case DashboardSection.team:
        return const TeamView();
      case DashboardSection.admin:
        return const AdminView();
      case DashboardSection.settings:
        return const SettingsView();
    }
  }
}

class _CardRequiredView extends StatelessWidget {
  final VoidCallback onLinkCard;

  const _CardRequiredView({required this.onLinkCard});

  @override
  Widget build(BuildContext context) {
    final user = taploeState.currentUser;
    final titleName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
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
                          Icons.qr_code_scanner_rounded,
                          color: TaploeColors.blue,
                          size: 46,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Vincula tu tarjeta Taploe',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: context.text,
                            fontSize: context.isMobile ? 32 : 42,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Hola, $titleName. Escanea el QR físico de tu tarjeta para crear tu perfil digital y empezar a compartirlo.',
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
                        const SizedBox(height: 14),
                        Text(
                          'Al vincularla crearemos tu perfil y podrás completarlo.',
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
                      onSelected: (value) async {
                        if (value == 'settings') {
                          onSelected(DashboardSection.settings);
                        }
                        if (value == 'logout') await taploeState.signOut();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'settings',
                          child: Text('Configuración'),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Text('Cerrar sesión'),
                        ),
                      ],
                      child: CircleAvatar(
                        backgroundColor: TaploeColors.black,
                        child: Text(
                          initials(
                            taploeState.currentUser?.fullName.isNotEmpty == true
                                ? taploeState.currentUser!.fullName
                                : taploeState.currentUser?.email ?? 'T',
                          ),
                          style: const TextStyle(color: Colors.white),
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

class _Sidebar extends StatelessWidget {
  final DashboardSection selected;
  final ValueChanged<DashboardSection> onSelected;

  const _Sidebar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = [
      (DashboardSection.home, Icons.space_dashboard_outlined, 'Inicio'),
      (
        DashboardSection.profile,
        Icons.person_outline_rounded,
        'Perfil digital',
      ),
      (DashboardSection.cards, Icons.credit_card_rounded, 'Tarjetas'),
      (DashboardSection.share, Icons.ios_share_rounded, 'Compartir'),
      (DashboardSection.analytics, Icons.insights_rounded, 'Analítica'),
      (DashboardSection.leads, Icons.handshake_outlined, 'Leads'),
      (DashboardSection.team, Icons.groups_outlined, 'Equipo'),
      (
        DashboardSection.admin,
        Icons.admin_panel_settings_outlined,
        'Administración',
      ),
      (DashboardSection.settings, Icons.settings_outlined, 'Configuración'),
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
                      CircleAvatar(
                        backgroundColor: TaploeColors.black,
                        child: Text(
                          initials(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName
                                : user?.email ?? 'T',
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user?.fullName.isNotEmpty == true
                              ? user!.fullName
                              : user?.email ?? 'Taploe',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map((item) {
                  final active = selected == item.$1;
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
                                  fontWeight: FontWeight.w900,
                                  color: active ? Colors.white : context.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: taploeState.signOut,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Cerrar sesión',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
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
    return PopupMenuButton<String>(
      tooltip: 'Crear',
      offset: const Offset(0, 58),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'profile') onNewProfile();
        if (value == 'card') onAddCard();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, size: 20),
              SizedBox(width: 10),
              Text('Nuevo perfil'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'card',
          child: Row(
            children: [
              Icon(Icons.add_card_rounded, size: 20),
              SizedBox(width: 10),
              Text('Agregar tarjeta'),
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
                fontWeight: FontWeight.w900,
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

Future<DigitalProfileModel?> _showCreateProfileDialog(
  BuildContext context, {
  PhysicalCardModel? assignToCard,
}) async {
  final user = taploeState.currentUser;

  if (user == null) {
    taploeToast(context, 'Inicia sesión para crear un perfil.', error: true);
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
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => errorText = 'Escribe un nombre para el perfil.');
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
        errorText = 'No pudimos crear el perfil. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Nuevo perfil',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
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
              errorText: errorText,
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
      final fallbackName = widget.user.fullName.trim().isEmpty
          ? 'tu perfil Taploe'
          : widget.user.fullName.trim();
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
                  (widget.user.fullName.trim().isEmpty
                      ? 'tu perfil Taploe'
                      : widget.user.fullName.trim()),
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
              fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.dmSans(color: context.muted, height: 1.45),
              children: [
                const TextSpan(text: 'Tu tarjeta ya está conectada al perfil '),
                TextSpan(
                  text: profileName,
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(text: '.'),
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
              fontWeight: FontWeight.w900,
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
                            fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w900,
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
  const HomeOverviewView({super.key});

  @override
  State<HomeOverviewView> createState() => _HomeOverviewViewState();
}

class _HomeOverviewViewState extends State<HomeOverviewView> {
  _HomeOverviewData? data;
  bool loading = true;
  String? _profileId;

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
    if (nextProfileId != _profileId) _load();
  }

  Future<void> _load() async {
    final p = taploeState.activeProfile;
    _profileId = p?.id;
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

    final results = await Future.wait<Object>([
      AnalyticsRepository.fetchSummary(p.id),
      LeadRepository.fetchForProfile(p.id),
      SmartFormRepository.fetchActiveForms(p.id),
      CardRepository.fetchAccessPointsForProfile(p.id),
      AnalyticsRepository.fetchRecentEvents(p.id),
    ]);

    if (taploeState.activeProfile?.id != p.id) return;
    if (mounted) {
      setState(() {
        data = _HomeOverviewData(
          summary: results[0] as AnalyticsSummaryModel,
          leads: results[1] as List<LeadModel>,
          forms: results[2] as List<SmartFormModel>,
          accessPoints: results[3] as List<ProfileAccessPointModel>,
          events: results[4] as List<AnalyticsEventModel>,
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
      title: 'Hola, ${user?.fullName.split(' ').first ?? 'Taploe'}',
      subtitle:
          'Controla tus perfiles, tarjetas, accesos QR/NFC y resultados desde un solo panel.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (p == null)
                  const TaploeEmpty(
                    title: 'Sin perfil seleccionado',
                    message: 'Crea o selecciona un perfil para empezar.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 820;
                      final metricCards = [
                        _MetricPanel(
                          label: 'Vistas',
                          value: '${s?.profileViews ?? 0}',
                          icon: Icons.visibility_outlined,
                        ),
                        _MetricPanel(
                          label: 'NFC',
                          value: '${s?.nfcViews ?? 0}',
                          icon: Icons.nfc_rounded,
                        ),
                        _MetricPanel(
                          label: 'QR',
                          value: '${s?.qrViews ?? 0}',
                          icon: Icons.qr_code_rounded,
                        ),
                        _MetricPanel(
                          label: 'Clicks',
                          value: '${s?.linkClicks ?? 0}',
                          icon: Icons.ads_click_rounded,
                        ),
                        _MetricPanel(
                          label: 'Leads',
                          value: '${d?.leads.length ?? 0}',
                          icon: Icons.handshake_outlined,
                        ),
                        _MetricPanel(
                          label: 'Tarjetas',
                          value: '${profileCards.length}',
                          icon: Icons.credit_card_rounded,
                        ),
                      ];
                      return GridView.count(
                        crossAxisCount: wide ? 6 : 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: wide ? 1.12 : 1.15,
                        children: metricCards,
                      );
                    },
                  ),
                const SizedBox(height: 16),
                _ResponsivePair(
                  breakpoint: 980,
                  leftFlex: 6,
                  rightFlex: 4,
                  left: Column(
                    children: [
                      TaploePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PanelHeader(
                              title: 'Rendimiento reciente',
                              icon: Icons.show_chart_rounded,
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
                                _InsightChip(
                                  label: '${s?.formSubmits ?? 0} formularios',
                                  icon: Icons.dynamic_form_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
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
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p == null
                                        ? '-'
                                        : TaploeConfig.profileUrl(p.publicSlug),
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      color: context.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TaploeButton(
                              width: 120,
                              label: 'Copiar',
                              kind: TaploeButtonKind.secondary,
                              onPressed: p == null
                                  ? null
                                  : () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: TaploeConfig.profileUrl(
                                            p.publicSlug,
                                          ),
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
                                fontWeight: FontWeight.w900,
                                color: context.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _CheckRow(
                              label: 'Datos de contacto',
                              done:
                                  p?.vcard?.email?.isNotEmpty == true ||
                                  p?.vcard?.mobilePhone?.isNotEmpty == true,
                            ),
                            _CheckRow(
                              label: 'Enlace público listo',
                              done: p?.publicSlug.isNotEmpty == true,
                            ),
                            _CheckRow(
                              label: 'Enlaces visibles',
                              done: (p?.links.length ?? 0) > 0,
                            ),
                            _CheckRow(
                              label: 'Tarjeta conectada',
                              done: profileCards.isNotEmpty,
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
                              title: 'Actividad reciente',
                              icon: Icons.bolt_outlined,
                            ),
                            const SizedBox(height: 10),
                            if (d?.events.isEmpty ?? true)
                              const _MutedText('Sin actividad todavía.')
                            else
                              ...d!.events.take(5).map(_ActivityTile.new),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ResponsivePair(
                  breakpoint: 900,
                  left: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Links más usados',
                          icon: Icons.link_rounded,
                        ),
                        const SizedBox(height: 12),
                        if (s?.clicksByLabel.isEmpty ?? true)
                          const _MutedText('Aún no hay clicks en enlaces.')
                        else
                          ...s!.clicksByLabel.entries
                              .take(5)
                              .map(
                                (entry) => _RankRow(
                                  label: entry.key,
                                  value: entry.value,
                                  max: s.clicksByLabel.values.fold<int>(
                                    1,
                                    (a, b) => b > a ? b : a,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  right: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Accesos activos',
                          icon: Icons.qr_code_2_rounded,
                        ),
                        const SizedBox(height: 12),
                        if (d?.accessPoints.isEmpty ?? true)
                          const _MutedText(
                            'Todavía no hay QR/NFC conectados a este perfil.',
                          )
                        else
                          ...d!.accessPoints
                              .take(4)
                              .map((ap) => _AccessPointRow(accessPoint: ap)),
                      ],
                    ),
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
  final List<ProfileAccessPointModel> accessPoints;
  final List<AnalyticsEventModel> events;

  const _HomeOverviewData({
    required this.summary,
    required this.leads,
    required this.forms,
    required this.accessPoints,
    required this.events,
  });
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
              fontWeight: FontWeight.w900,
              color: context.text,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w700,
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
        children: [
          Icon(_eventIcon(event.eventType), color: TaploeColors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _eventLabel(event.eventType),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                color: context.text,
              ),
            ),
          ),
          Text(
            _relativeTime(event.occurredAt),
            style: GoogleFonts.dmSans(color: context.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;

  const _RankRow({required this.label, required this.value, required this.max});

  @override
  Widget build(BuildContext context) {
    final progress = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 5, child: _ProgressBar(value: progress)),
          const SizedBox(width: 10),
          Text(
            '$value',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              color: context.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessPointRow extends StatelessWidget {
  final ProfileAccessPointModel accessPoint;

  const _AccessPointRow({required this.accessPoint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            accessPoint.channel == 'nfc'
                ? Icons.nfc_rounded
                : Icons.qr_code_rounded,
            color: TaploeColors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accessPoint.channel.toUpperCase(),
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
                ),
                Text(
                  accessPoint.publicUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(color: context.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: accessPoint.publicUrl));
              taploeToast(context, 'Acceso copiado.');
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
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
              fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w700,
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
            fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w900,
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

String _relativeTime(DateTime? date) {
  if (date == null) return '-';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return dateShort(date);
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
                fontWeight: FontWeight.w900,
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
              fontWeight: active ? FontWeight.w900 : FontWeight.w800,
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
                    fontWeight: FontWeight.w900,
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
                          fontWeight: FontWeight.w900,
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

  const ProfileEditorView({super.key, this.initialStep = 0});

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
  List<SmartFormModel> _forms = [];
  List<ProfileIntegrationModel> _integrations = [];

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

  void _fill() {
    final p = taploeState.activeProfile;
    if (p == null) return;
    if (_loadedProfileId != p.id) {
      _loadedProfileId = p.id;
      _extrasProfileId = null;
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
      _loadProfileExtras(p.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadProfileExtras(String profileId) async {
    if (_extrasProfileId == profileId) return;
    _extrasProfileId = profileId;
    final results = await Future.wait<Object>([
      SmartFormRepository.fetchForms(profileId),
      IntegrationRepository.fetchForProfile(profileId: profileId),
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

  Future<void> save() async {
    final p = taploeState.activeProfile;
    if (p == null) return;
    setState(() => saving = true);
    try {
      final updated = p.copyWith(
        displayName: displayName.text.trim(),
        jobTitle: jobTitle.text.trim(),
        companyName: company.text.trim(),
        bio: bio.text.trim(),
        publicSlug: slugify(slug.text),
        profilePhotoUrl: profilePhoto.text.trim().isEmpty
            ? null
            : profilePhoto.text.trim(),
        logoUrl: logo.text.trim().isEmpty ? null : logo.text.trim(),
        coverPhotoUrl: cover.text.trim().isEmpty ? null : cover.text.trim(),
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
    if (p == null || user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (!mounted) return;

    final editedBytes = await _showProfileAssetEditor(
      context,
      kind: kind,
      bytes: bytes,
    );
    if (editedBytes == null) return;

    setState(() => uploadingAsset = kind);
    try {
      final url = await ProfileAssetRepository.uploadProfileAsset(
        userId: user.id,
        profileId: p.id,
        kind: kind,
        bytes: editedBytes,
        fileName: '$kind.png',
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

  @override
  Widget build(BuildContext context) {
    final p = taploeState.activeProfile;
    final steps = const [
      'Perfil',
      'Contacto',
      'Enlaces',
      'Diseño',
      'Formularios',
      'Integraciones',
    ];
    return PageShell(
      title: 'Perfil digital',
      subtitle:
          'Edita tu perfil, contacto, diseño y flujos de captura desde un mismo lugar.',
      actions: [
        _SmallPill(
          label: 'Paso ${step + 1} de ${steps.length}: ${steps[step]}',
          icon: Icons.route_outlined,
        ),
        IconButton.outlined(
          tooltip: 'Paso anterior',
          onPressed: step == 0 ? null : () => setState(() => step--),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        IconButton.outlined(
          tooltip: 'Siguiente paso',
          onPressed: step == steps.length - 1
              ? null
              : () => setState(() => step++),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        TaploeButton(
          label: 'Guardar cambios',
          width: 170,
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
                      for (var i = 0; i < steps.length; i++)
                        _WizardStepTile(
                          index: i,
                          label: steps[i],
                          active: step == i,
                          done: _profileStepDone(
                            p,
                            i,
                            forms: _forms,
                            integrations: _integrations,
                          ),
                          onTap: () => setState(() => step = i),
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
                  uploadingAsset: uploadingAsset,
                  onUploadProfilePhoto: () =>
                      uploadProfileAsset('profile-photo', profilePhoto),
                  onUploadLogo: () => uploadProfileAsset('logo', logo),
                  onUploadCover: () => uploadProfileAsset('cover', cover),
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
                      profile: p.copyWith(
                        displayName: displayName.text.trim().isEmpty
                            ? p.displayName
                            : displayName.text.trim(),
                        jobTitle: jobTitle.text.trim(),
                        companyName: company.text.trim(),
                        bio: bio.text.trim(),
                        publicSlug: slugify(slug.text),
                        profilePhotoUrl: profilePhoto.text.trim().isEmpty
                            ? p.profilePhotoUrl
                            : profilePhoto.text.trim(),
                        logoUrl: logo.text.trim().isEmpty
                            ? p.logoUrl
                            : logo.text.trim(),
                        coverPhotoUrl: cover.text.trim().isEmpty
                            ? p.coverPhotoUrl
                            : cover.text.trim(),
                        vcard: ProfileVcardModel(
                          profileId: p.id,
                          email: email.text.trim(),
                          mobilePhone: phone.text.trim(),
                          whatsappPhone: whatsapp.text.trim(),
                          websiteUrl: website.text.trim(),
                        ),
                      ),
                      forms: _forms,
                      integrations: _integrations,
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
  final VoidCallback onTap;

  const _WizardStepTile({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
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
                    fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                done ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 18,
                color: done
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
  final String? uploadingAsset;
  final VoidCallback onUploadProfilePhoto;
  final VoidCallback onUploadLogo;
  final VoidCallback onUploadCover;
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
    required this.uploadingAsset,
    required this.onUploadProfilePhoto,
    required this.onUploadLogo,
    required this.onUploadCover,
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
              hint: 'Daniel Nuño',
              onSubmitted: (_) => save(),
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
            const SizedBox(height: 14),
            TaploeTextField(
              label: 'Slug público',
              controller: slug,
              hint: 'daniel-nuno',
              onSubmitted: (_) => save(),
            ),
            const SizedBox(height: 14),
            _ProfileAssetPicker(
              label: 'Logo',
              value: logo.text,
              icon: Icons.workspace_premium_outlined,
              loading: uploadingAsset == 'logo',
              onTap: onUploadLogo,
              fallback: const TaploeLogo(size: 24),
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
              trailing: '${profile.links.length}',
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
                onPressed: () =>
                    _showLinkEditorDialog(context, profile: profile),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (step == 3) ...[_DesignStudio(profile: profile)],
          if (step == 4) ...[
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
      padding: const EdgeInsets.all(12),
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
                        fontWeight: FontWeight.w900,
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
            decoration: InputDecoration(hintText: hint),
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
                          fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w900,
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
                              fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
              color: _linkBrandColor(type),
            ),
          ),
        ),
      );
    }
    return Icon(_linkIcon(type), color: _linkBrandColor(type), size: size);
  }
}

class _DesignStudio extends StatelessWidget {
  final DigitalProfileModel profile;

  const _DesignStudio({required this.profile});

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
                'Diseño de tu perfil',
                style: GoogleFonts.outfit(
                  color: context.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
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
        Text(
          'Elige un estilo profesional y personaliza tu perfil en segundos.',
          style: GoogleFonts.dmSans(color: context.muted),
        ),
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
              onTap: () => _saveThemeQuick(profile, preset.toTheme(theme)),
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
                _saveThemeQuick(profile, theme.copyWithPrimary(value)),
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
                _saveThemeQuick(profile, theme.copyWithAccent(value)),
          ),
        ),
        const SizedBox(height: 12),
        _ResponsivePair(
          left: _SegmentControl(
            title: 'Estilo de botones',
            value: theme.buttonStyle,
            options: const ['pill', 'rounded', 'square'],
            labels: const ['Redondeado', 'Suave', 'Cuadrado'],
            onChanged: (value) =>
                _saveThemeQuick(profile, theme.copyWithButtonStyle(value)),
          ),
          right: _SegmentControl(
            title: 'Tipografía',
            value: theme.fontFamily,
            options: const ['system', 'poppins', 'montserrat'],
            labels: const ['Inter', 'Poppins', 'Montserrat'],
            onChanged: (value) =>
                _saveThemeQuick(profile, theme.copyWithFontFamily(value)),
          ),
        ),
        const SizedBox(height: 12),
        _ResponsivePair(
          left: _SegmentControl(
            title: 'Fondo',
            value: _backgroundMode(theme),
            options: const ['light', 'dark'],
            labels: const ['Claro', 'Oscuro'],
            onChanged: (value) =>
                _saveThemeQuick(profile, theme.copyWithBackgroundMode(value)),
          ),
          right: _ColorSwatches(
            title: 'Fondo personalizado',
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
                _saveThemeQuick(profile, theme.copyWithBackgroundColor(value)),
          ),
        ),
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
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
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
                fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
              color: context.text,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: context.muted,
              fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
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
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
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
                        fontWeight: FontWeight.w900,
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
                        fontWeight: FontWeight.w800,
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
    return Center(
      child: SizedBox(
        width: 320,
        child: TaploePublicProfileCard(
          profile: profile,
          links: profile.links,
          forms: forms,
          integrations: integrations,
          framed: true,
        ),
      ),
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
          width: 230,
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
                    fit: BoxFit.cover,
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
                    fontWeight: FontWeight.w900,
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
            width: 150,
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
      final cropped = await _cropImageToPng(
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
        taploeToast(context, 'No pudimos preparar la imagen.', error: true);
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
            child: Image.memory(
              widget.bytes,
              fit: BoxFit.cover,
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
              fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
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
        fontWeight: FontWeight.w900,
      ),
      side: BorderSide(color: selected ? TaploeColors.blue : context.border),
    );
  }
}

Future<Uint8List> _cropImageToPng(
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

  var cropWidth = imageWidth;
  var cropHeight = imageHeight;
  if (imageAspect > targetAspect) {
    cropWidth = imageHeight * targetAspect;
  } else {
    cropHeight = imageWidth / targetAspect;
  }
  cropWidth = (cropWidth / zoom).clamp(1, imageWidth).toDouble();
  cropHeight = (cropHeight / zoom).clamp(1, imageHeight).toDouble();

  final left = ((alignment.x + 1) / 2) * (imageWidth - cropWidth);
  final top = ((alignment.y + 1) / 2) * (imageHeight - cropHeight);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..isAntiAlias = true;
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(left, top, cropWidth, cropHeight),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );
  final picture = recorder.endRecording();
  final output = await picture.toImage(width, height);
  final data = await output.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw StateError('No se pudo procesar la imagen.');
  return data.buffer.asUint8List();
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
  await ProfileRepository.updateProfile(updated);
  await taploeState.refreshProfiles();
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
                  fontWeight: FontWeight.w900,
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
              const SizedBox(height: 10),
              TaploeToggleRow(
                title: 'Destacado',
                subtitle: 'Se mostrará con mayor prioridad en tu perfil.',
                icon: Icons.star_border_rounded,
                value: isFeatured,
                onChanged: (v) => setState(() => isFeatured = v),
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
              fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w800,
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
                      decoration: const InputDecoration(
                        labelText: 'Tipo de campo',
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
              fontWeight: FontWeight.w900,
              color: context.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega una tarjeta Taploe para vincular QR, NFC y perfil.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.muted, height: 1.4),
          ),
        ],
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
          label: 'Agregar tarjeta',
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
        const SizedBox(height: 36),
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
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        _CardStatusPill(status: card.status),
        const SizedBox(height: 28),
        Text(
          'Perfil vinculado',
          style: GoogleFonts.dmSans(
            color: context.muted,
            fontWeight: FontWeight.w800,
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
                      .followedBy(const [
                        DropdownMenuItem<String>(
                          value: _dividerValue,
                          enabled: false,
                          child: Divider(height: 1),
                        ),
                        DropdownMenuItem<String>(
                          value: _newProfileValue,
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: TaploeColors.blue,
                              ),
                              SizedBox(width: 8),
                              Text('Crear nuevo perfil'),
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
                    fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w900,
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
                                  fontWeight: FontWeight.w800,
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
    final p = taploeState.activeProfile;
    _profileId = p?.id;
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
    final d = await AnalyticsRepository.fetchSummary(p.id);
    if (taploeState.activeProfile?.id != p.id) return;
    if (mounted) {
      setState(() {
        data = d;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final views = d?.profileViews ?? 0;
    final ctr = views == 0 ? 0 : ((d!.linkClicks / views) * 100).round();
    return PageShell(
      title: 'Analítica',
      subtitle: 'Mide visitas por NFC, QR, link directo, clicks y formularios.',
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
          : Column(
              children: [
                GridView.count(
                  crossAxisCount: context.isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: context.isWide ? 1.45 : 1.1,
                  children: [
                    _MetricPanel(
                      label: 'Vistas totales',
                      value: '${d.profileViews}',
                      icon: Icons.visibility_outlined,
                    ),
                    _MetricPanel(
                      label: 'NFC',
                      value: '${d.nfcViews}',
                      icon: Icons.nfc_rounded,
                    ),
                    _MetricPanel(
                      label: 'QR',
                      value: '${d.qrViews}',
                      icon: Icons.qr_code_rounded,
                    ),
                    _MetricPanel(
                      label: 'Clicks',
                      value: '${d.linkClicks}',
                      icon: Icons.ads_click_rounded,
                    ),
                    _MetricPanel(
                      label: 'CTR',
                      value: '$ctr%',
                      icon: Icons.trending_up_rounded,
                    ),
                    _MetricPanel(
                      label: 'Leads/form',
                      value: '${d.formSubmits}',
                      icon: Icons.dynamic_form_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ResponsivePair(
                  breakpoint: 960,
                  leftFlex: 6,
                  rightFlex: 4,
                  left: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Últimos 7 días',
                          icon: Icons.timeline_rounded,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 260,
                          child: _ViewsLineChart(values: d.viewsByDay),
                        ),
                      ],
                    ),
                  ),
                  right: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Canales',
                          icon: Icons.hub_outlined,
                        ),
                        const SizedBox(height: 14),
                        _RankRow(
                          label: 'NFC',
                          value: d.nfcViews,
                          max: views == 0 ? 1 : views,
                        ),
                        _RankRow(
                          label: 'QR',
                          value: d.qrViews,
                          max: views == 0 ? 1 : views,
                        ),
                        _RankRow(
                          label: 'Directo',
                          value: d.directViews,
                          max: views == 0 ? 1 : views,
                        ),
                        const Divider(height: 24),
                        _InsightChip(
                          label: '${d.contactsSaved} contactos guardados',
                          icon: Icons.person_add_alt_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TaploePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PanelHeader(
                        title: 'Clicks por enlace',
                        icon: Icons.link_rounded,
                      ),
                      const SizedBox(height: 12),
                      if (d.clicksByLabel.isEmpty)
                        const _MutedText('Sin clicks todavía.')
                      else
                        ...d.clicksByLabel.entries.map(
                          (e) => _RankRow(
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
    final p = taploeState.activeProfile;
    _profileId = p?.id;
    if (p == null) {
      if (mounted) {
        setState(() {
          leads = [];
          loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => loading = true);
    final rows = await LeadRepository.fetchForProfile(p.id);
    if (taploeState.activeProfile?.id != p.id) return;
    if (mounted) {
      setState(() {
        leads = rows;
        loading = false;
      });
    }
  }

  Future<void> status(LeadModel lead, String value) async {
    await LeadRepository.updateStatus(lead.id, value);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final byStatus = <String, int>{
      for (final status in ['new', 'contacted', 'qualified', 'won', 'lost'])
        status: leads.where((lead) => lead.status == status).length,
    };
    return PageShell(
      title: 'Leads',
      subtitle: 'Contactos generados desde formularios e interacciones.',
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
          : Column(
              children: [
                GridView.count(
                  crossAxisCount: context.isWide ? 5 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: context.isWide ? 1.35 : 1.25,
                  children: [
                    _MetricPanel(
                      label: 'Nuevos',
                      value: '${byStatus['new']}',
                      icon: Icons.fiber_new_rounded,
                    ),
                    _MetricPanel(
                      label: 'Contactados',
                      value: '${byStatus['contacted']}',
                      icon: Icons.mark_email_read_outlined,
                    ),
                    _MetricPanel(
                      label: 'Calificados',
                      value: '${byStatus['qualified']}',
                      icon: Icons.verified_outlined,
                    ),
                    _MetricPanel(
                      label: 'Ganados',
                      value: '${byStatus['won']}',
                      icon: Icons.emoji_events_outlined,
                    ),
                    _MetricPanel(
                      label: 'Perdidos',
                      value: '${byStatus['lost']}',
                      icon: Icons.archive_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TaploePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PanelHeader(
                        title: 'Bandeja de leads',
                        icon: Icons.handshake_outlined,
                        trailing: '${leads.length} total',
                      ),
                      const SizedBox(height: 10),
                      ...leads.map((lead) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: TaploeColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: TaploeColors.black,
                                child: Text(
                                  lead.displayName.isNotEmpty
                                      ? lead.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lead.displayName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      [lead.company, lead.email, lead.phone]
                                          .where((e) => e?.isNotEmpty == true)
                                          .join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        color: context.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _SmallPill(
                                          label: 'Score ${lead.score}',
                                          icon: Icons.local_fire_department,
                                        ),
                                        _SmallPill(
                                          label: lead.sourceChannel ?? 'direct',
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
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: lead.status,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'new',
                                    child: Text('Nuevo'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'contacted',
                                    child: Text('Contactado'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'qualified',
                                    child: Text('Calificado'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'won',
                                    child: Text('Ganado'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'lost',
                                    child: Text('Perdido'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) status(lead, v);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
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
      setState(() => loading = false);
      return;
    }
    final rows = await TeamRepository.fetchTeam(org.id);
    if (mounted) {
      setState(() {
        members = rows;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalViews = members.fold<int>(
      0,
      (sum, member) => sum + member.views,
    );
    final totalLeads = members.fold<int>(
      0,
      (sum, member) => sum + member.leads,
    );
    final totalProfiles = members.fold<int>(
      0,
      (sum, member) => sum + member.profiles,
    );
    final topViews = members.fold<int>(
      1,
      (max, member) => member.views > max ? member.views : max,
    );
    return PageShell(
      title: 'Equipo',
      subtitle:
          'Vista por miembro cuando la cuenta pertenece a una organización.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : taploeState.organization == null
          ? const TaploeEmpty(
              title: 'Sin organización',
              message: 'Esta cuenta todavía no está conectada a un equipo.',
            )
          : members.isEmpty
          ? const TaploeEmpty(
              title: 'Sin miembros',
              message: 'Agrega miembros a la organización.',
            )
          : Column(
              children: [
                GridView.count(
                  crossAxisCount: context.isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: context.isWide ? 1.55 : 1.18,
                  children: [
                    _MetricPanel(
                      label: 'Miembros',
                      value: '${members.length}',
                      icon: Icons.groups_outlined,
                    ),
                    _MetricPanel(
                      label: 'Perfiles',
                      value: '$totalProfiles',
                      icon: Icons.badge_outlined,
                    ),
                    _MetricPanel(
                      label: 'Vistas',
                      value: '$totalViews',
                      icon: Icons.visibility_outlined,
                    ),
                    _MetricPanel(
                      label: 'Leads',
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
                          title: 'Miembros',
                          icon: Icons.groups_outlined,
                          trailing: '${members.length} activos',
                        ),
                        const SizedBox(height: 10),
                        ...members.map((m) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: TaploeColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: TaploeColors.black,
                                  child: Text(
                                    initials(m.name),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        '${m.role} · ${m.email}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(
                                          color: context.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _SmallPill(
                                      label: '${m.profiles} perfiles',
                                      icon: Icons.badge_outlined,
                                    ),
                                    _SmallPill(
                                      label: '${m.leads} leads',
                                      icon: Icons.handshake_outlined,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  right: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Rendimiento',
                          icon: Icons.leaderboard_outlined,
                        ),
                        const SizedBox(height: 14),
                        ...members.map(
                          (m) => _RankRow(
                            label: m.name,
                            value: m.views,
                            max: topViews,
                          ),
                        ),
                        const Divider(height: 24),
                        _InsightChip(
                          label: totalProfiles == 0
                              ? 'Crea perfiles para medir resultados por persona'
                              : '$totalProfiles perfiles administrados',
                          icon: Icons.insights_rounded,
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

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  OrganizationSummaryModel? summary;
  List<TeamMemberModel> members = [];
  List<SmartFormModel> forms = [];
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
    final profile = taploeState.activeProfile;
    if (org == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final result = await Future.wait<Object>([
      OrganizationRepository.fetchSummary(org),
      TeamRepository.fetchTeam(org.id),
      if (profile != null)
        SmartFormRepository.fetchForms(profile.id)
      else
        Future.value(<SmartFormModel>[]),
    ]);

    if (!mounted) return;
    setState(() {
      summary = result[0] as OrganizationSummaryModel;
      members = result[1] as List<TeamMemberModel>;
      forms = result[2] as List<SmartFormModel>;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final org = taploeState.organization;
    final data = summary;
    return PageShell(
      title: 'Administración',
      subtitle:
          'Controla equipo, formularios e información operativa desde un solo lugar.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : org == null
          ? TaploePanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.business_rounded,
                    color: TaploeColors.blue,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Crea un espacio para tu equipo',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Administra miembros, perfiles, tarjetas y resultados desde Taploe Business.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(color: context.muted),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      TaploeButton(
                        label: 'Solicitar plan para equipo',
                        icon: Icons.workspace_premium_outlined,
                        onPressed: () => taploeToast(
                          context,
                          'El flujo de plan de equipo quedará conectado a ventas.',
                        ),
                      ),
                      TaploeButton(
                        label: 'Ver perfil público',
                        icon: Icons.open_in_new_rounded,
                        kind: TaploeButtonKind.secondary,
                        onPressed: taploeState.activeProfile == null
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: TaploeConfig.profileUrl(
                                      taploeState.activeProfile!.publicSlug,
                                    ),
                                  ),
                                );
                                taploeToast(context, 'Enlace copiado.');
                              },
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Column(
              children: [
                TaploePanel(
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: TaploeColors.page,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: TaploeColors.border),
                        ),
                        child: org.logoUrl == null
                            ? const Icon(Icons.business_rounded)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.network(
                                  org.logoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.business_rounded),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              org.name,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Plan ${org.planType.toUpperCase()} · ${org.websiteUrl ?? 'Sin sitio web'}',
                              style: GoogleFonts.dmSans(color: context.muted),
                            ),
                          ],
                        ),
                      ),
                      _SmallPill(
                        label: org.slug == null ? 'Sin slug' : '@${org.slug}',
                        icon: Icons.verified_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: context.isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: context.isWide ? 1.45 : 1.1,
                  children: [
                    _MetricPanel(
                      label: 'Miembros activos',
                      value: '${data?.members ?? 0}',
                      icon: Icons.groups_outlined,
                    ),
                    _MetricPanel(
                      label: 'Perfiles activos',
                      value: '${data?.profiles ?? 0}',
                      icon: Icons.badge_outlined,
                    ),
                    _MetricPanel(
                      label: 'Tarjetas activas',
                      value: '${data?.cards ?? 0}',
                      icon: Icons.credit_card_rounded,
                    ),
                    _MetricPanel(
                      label: 'Vistas totales',
                      value: '${data?.views ?? 0}',
                      icon: Icons.visibility_outlined,
                    ),
                    _MetricPanel(
                      label: 'Taps NFC',
                      value: '${data?.nfc ?? 0}',
                      icon: Icons.nfc_rounded,
                    ),
                    _MetricPanel(
                      label: 'QR',
                      value: '${data?.qr ?? 0}',
                      icon: Icons.qr_code_rounded,
                    ),
                    _MetricPanel(
                      label: 'Clicks',
                      value: '${data?.clicks ?? 0}',
                      icon: Icons.ads_click_rounded,
                    ),
                    _MetricPanel(
                      label: 'Leads',
                      value: '${data?.leads ?? 0}',
                      icon: Icons.handshake_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ResponsivePair(
                  breakpoint: 980,
                  left: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Formularios del perfil seleccionado',
                          icon: Icons.dynamic_form_outlined,
                          trailing: '${forms.length}',
                        ),
                        const SizedBox(height: 12),
                        if (forms.isEmpty)
                          const _MutedText(
                            'Aún no hay formularios creados para este perfil.',
                          )
                        else
                          ...forms.map(
                            (form) => _ActionCard(
                              title: form.name,
                              subtitle: form.description ?? form.formKey,
                              icon: form.isActive
                                  ? Icons.toggle_on_rounded
                                  : Icons.toggle_off_outlined,
                            ),
                          ),
                      ],
                    ),
                  ),
                  right: TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Roles y miembros',
                          icon: Icons.admin_panel_settings_outlined,
                          trailing: '${members.length}',
                        ),
                        const SizedBox(height: 12),
                        if (members.isEmpty)
                          const _MutedText('Sin miembros activos.')
                        else
                          ...members.map(
                            (member) => _ActionCard(
                              title: member.name,
                              subtitle:
                                  '${member.role} · ${member.email} · ${member.cards} tarjetas',
                              icon: Icons.person_outline_rounded,
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

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final timezone = TextEditingController();
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
    final user = taploeState.currentUser;
    if (user == null) return;
    if (name.text == user.fullName &&
        phone.text == (user.phone ?? '') &&
        timezone.text == user.timezone) {
      return;
    }
    name.text = user.fullName;
    phone.text = user.phone ?? '';
    timezone.text = user.timezone;
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await UserRepository.updateCurrentUser(
        fullName: name.text,
        phone: phone.text,
        timezone: timezone.text,
      );
      await taploeState.refreshAll();
      if (mounted) taploeToast(context, 'Configuración actualizada.');
    } catch (e) {
      safePrintError(e);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos guardar la configuración. Intenta de nuevo.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = taploeState.currentUser;
    final org = taploeState.organization;
    return PageShell(
      title: 'Configuración',
      subtitle: 'Cuenta, preferencias, organización, seguridad y plan.',
      actions: [
        TaploeButton(
          label: 'Guardar',
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
                          title: 'Cuenta',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 14),
                        TaploeTextField(
                          label: 'Nombre',
                          controller: name,
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
                          label: 'Teléfono',
                          controller: phone,
                          onSubmitted: (_) => save(),
                        ),
                        const SizedBox(height: 12),
                        TaploeTextField(
                          label: 'Zona horaria',
                          controller: timezone,
                          onSubmitted: (_) => save(),
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
                          title: 'Seguridad',
                          icon: Icons.lock_outline_rounded,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tu sesión usa autenticación OTP por correo. Puedes cerrarla desde aquí.',
                          style: GoogleFonts.dmSans(color: context.muted),
                        ),
                        const SizedBox(height: 14),
                        TaploeButton(
                          label: 'Cerrar sesión',
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
                  TaploePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Preferencias',
                          icon: Icons.tune_rounded,
                        ),
                        const SizedBox(height: 12),
                        _CheckRow(
                          label: 'Perfil predeterminado configurado',
                          done: taploeState.activeProfile != null,
                        ),
                        const SizedBox(height: 8),
                        const _MutedText(
                          'Las preferencias de notificaciones se conectarán cuando exista una tabla de preferencias o integración de email/webhook.',
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
                          title: 'Organización',
                          icon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 12),
                        if (org == null)
                          const _MutedText(
                            'Esta cuenta todavía no pertenece a una organización.',
                          )
                        else ...[
                          _InfoLine(label: 'Nombre', value: org.name),
                          _InfoLine(
                            label: 'Plan',
                            value: org.planType.toUpperCase(),
                          ),
                          _InfoLine(
                            label: 'Sitio web',
                            value: org.websiteUrl ?? '-',
                          ),
                          _InfoLine(label: 'Teléfono', value: org.phone ?? '-'),
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
