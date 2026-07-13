import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../repositories.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

enum _AccessUiState {
  loading,
  notFound,
  disabled,
  requiresAuth,
  selectProfile,
  confirm,
  activating,
  success,
  alreadyMine,
  alreadyClaimed,
  error,
}

class AccessResolverView extends StatefulWidget {
  final String token;

  const AccessResolverView({super.key, required this.token});

  @override
  State<AccessResolverView> createState() => _AccessResolverViewState();
}

class _AccessResolverViewState extends State<AccessResolverView> {
  _AccessUiState state = _AccessUiState.loading;
  AccessResolutionModel? resolution;
  DigitalProfileModel? selectedProfile;
  ActivationResultModel? activationResult;
  String? errorMessage;

  ProfileAccessPointModel? get accessPoint => resolution?.accessPoint;
  PhysicalCardModel? get card => resolution?.physicalCard;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      state = _AccessUiState.loading;
      errorMessage = null;
    });

    try {
      final resolved = await CardActivationService.resolveAccessToken(
        widget.token,
      );
      if (!mounted) return;
      resolution = resolved;

      switch (resolved.action) {
        case AccessResolutionAction.notFound:
          setState(() => state = _AccessUiState.notFound);
          return;
        case AccessResolutionAction.disabled:
          setState(() => state = _AccessUiState.disabled);
          return;
        case AccessResolutionAction.redirectExternal:
          await _redirectExternal(resolved);
          return;
        case AccessResolutionAction.openProfile:
          await _openProfile(resolved);
          return;
        case AccessResolutionAction.activate:
          await _prepareActivation(resolved);
          return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        state = _AccessUiState.error;
        errorMessage = 'No pudimos resolver este acceso. Intenta de nuevo.';
      });
    }
  }

  Future<void> _redirectExternal(AccessResolutionModel resolved) async {
    final access = resolved.accessPoint;
    final raw = access?.externalUrl;
    final uri = raw == null ? null : Uri.tryParse(raw);

    if (access?.profileId != null) {
      await AnalyticsRepository.insertEvent(
        profileId: access!.profileId,
        physicalCardId: access.physicalCardId,
        accessPointId: access.id,
        eventType: 'profile_view',
        channel: access.channel,
        metadata: {'target_type': 'external_url'},
      );
    }

    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!mounted) return;
    setState(() => state = _AccessUiState.disabled);
  }

  Future<void> _openProfile(AccessResolutionModel resolved) async {
    final access = resolved.accessPoint;
    final profile = resolved.profile;
    if (access == null || profile == null) {
      if (mounted) setState(() => state = _AccessUiState.notFound);
      return;
    }

    await AnalyticsRepository.recordProfileViewFromAccessPoint(access);

    if (!mounted) return;
    context.go(
      '/p/${profile.publicSlug}?channel=${access.channel}&ap=${access.id}',
    );
  }

  Future<void> _prepareActivation(AccessResolutionModel resolved) async {
    final physicalCard = resolved.physicalCard;
    final currentUser = taploeState.currentUser;

    if (physicalCard?.ownerUserId != null && currentUser != null) {
      if (physicalCard!.ownerUserId == currentUser.id) {
        final profile = physicalCard.activeProfileId == null
            ? taploeState.activeProfile
            : await ProfileRepository.fetchProfileById(
                physicalCard.activeProfileId!,
              );
        if (!mounted) return;
        setState(() {
          selectedProfile = profile ?? taploeState.activeProfile;
          state = _AccessUiState.alreadyMine;
        });
        return;
      }

      if (!mounted) return;
      setState(() => state = _AccessUiState.alreadyClaimed);
      return;
    }

    if (physicalCard?.cannotBeClaimed == true &&
        physicalCard?.ownerUserId != currentUser?.id) {
      if (!mounted) return;
      setState(() => state = _AccessUiState.alreadyClaimed);
      return;
    }

    if (!taploeState.signedIn) {
      await taploeState.savePendingActivationToken(widget.token);
      if (!mounted) return;
      setState(() => state = _AccessUiState.requiresAuth);
      return;
    }

    await taploeState.bootstrap();
    var user = taploeState.currentUser ?? await UserRepository.currentAppUser();
    if (user == null) {
      await taploeState.savePendingActivationToken(widget.token);
      if (!mounted) return;
      setState(() => state = _AccessUiState.requiresAuth);
      return;
    }

    selectedProfile = taploeState.activeProfile;

    if (!mounted) return;
    setState(() => state = _AccessUiState.confirm);
  }

  Future<void> _continueToLogin() async {
    await taploeState.savePendingActivationToken(widget.token);
    if (!mounted) return;
    context.go('/login?token=${Uri.encodeComponent(widget.token)}');
  }

  Future<void> _createProfile() async {
    final user = taploeState.currentUser;
    if (user == null) return;

    setState(() => state = _AccessUiState.loading);
    try {
      final profile = await ProfileRepository.createProfileForUser(user);
      await taploeState.refreshProfiles();
      if (!mounted) return;
      setState(() {
        selectedProfile = profile;
        state = _AccessUiState.confirm;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        state = _AccessUiState.selectProfile;
        errorMessage = 'No se pudo crear un perfil nuevo.';
      });
    }
  }

  Future<void> _activate() async {
    setState(() => state = _AccessUiState.activating);
    try {
      final result = await CardActivationService.activateCardByToken(
        token: widget.token,
      );
      await taploeState.clearPendingActivationToken();
      await taploeState.refreshAll();
      if (!mounted) return;
      setState(() {
        activationResult = result;
        selectedProfile = taploeState.activeProfile;
        state = _AccessUiState.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        state = _AccessUiState.confirm;
        errorMessage = safeActivationErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaploeColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: _buildBody(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (state) {
      case _AccessUiState.loading:
      case _AccessUiState.activating:
        return _LoadingCard(
          title: state == _AccessUiState.activating
              ? 'Vinculando tarjeta'
              : 'Resolviendo acceso seguro',
        );
      case _AccessUiState.notFound:
        return _MessageCard(
          icon: Icons.search_off_rounded,
          title: 'Acceso no encontrado',
          message: 'Este enlace no pertenece a una tarjeta Taploe activa.',
          primaryLabel: 'Ir a Taploe',
          onPrimary: () => context.go('/login'),
        );
      case _AccessUiState.disabled:
        return _MessageCard(
          icon: Icons.block_rounded,
          title: 'Acceso inactivo',
          message: 'Este acceso fue desactivado o reemplazado.',
          primaryLabel: 'Ir a Taploe',
          onPrimary: () => context.go('/login'),
        );
      case _AccessUiState.requiresAuth:
        return ActivationLandingView(
          accessPoint: accessPoint,
          card: card,
          onContinue: _continueToLogin,
        );
      case _AccessUiState.selectProfile:
        return ActivationProfileSelectorView(
          profiles: taploeState.profiles,
          selected: selectedProfile,
          errorMessage: errorMessage,
          onSelected: (profile) => setState(() => selectedProfile = profile),
          onCreateProfile: _createProfile,
          onContinue: selectedProfile == null
              ? null
              : () => setState(() => state = _AccessUiState.confirm),
        );
      case _AccessUiState.confirm:
        return ActivationConfirmView(
          accessPoint: accessPoint,
          card: card,
          profile: selectedProfile,
          errorMessage: errorMessage,
          onChangeProfile: taploeState.profiles.length > 1
              ? () => setState(() => state = _AccessUiState.selectProfile)
              : null,
          onActivate: _activate,
        );
      case _AccessUiState.success:
        return ActivationSuccessView(
          result: activationResult,
          profile: selectedProfile,
          card: card,
        );
      case _AccessUiState.alreadyMine:
        return AlreadyClaimedView(
          title: 'Esta tarjeta ya está vinculada a tu cuenta.',
          message:
              'Puedes ver tu perfil o administrar tus tarjetas desde el panel.',
          profile: selectedProfile,
          mine: true,
        );
      case _AccessUiState.alreadyClaimed:
        return AlreadyClaimedView(
          title: 'Esta tarjeta ya fue vinculada',
          message:
              'Por seguridad, no es posible volver a activarla desde este enlace.',
          profile: selectedProfile,
          mine: false,
        );
      case _AccessUiState.error:
        return _MessageCard(
          icon: Icons.error_outline_rounded,
          title: 'No pudimos continuar',
          message: errorMessage ?? 'Intenta de nuevo en unos segundos.',
          primaryLabel: 'Reintentar',
          onPrimary: _resolve,
        );
    }
  }
}

class ActivationLandingView extends StatelessWidget {
  final ProfileAccessPointModel? accessPoint;
  final PhysicalCardModel? card;
  final VoidCallback onContinue;

  const ActivationLandingView({
    super.key,
    required this.accessPoint,
    required this.card,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return _AccessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TaploeLogo(size: 42),
          const SizedBox(height: 28),
          _AccessIcon(icon: Icons.credit_card_rounded),
          const SizedBox(height: 18),
          _Title('Activa tu tarjeta Taploe'),
          const SizedBox(height: 10),
          _MutedText(
            'Esta tarjeta todavía no está conectada. Inicia sesión para vincularla y crear tu perfil digital.',
          ),
          const SizedBox(height: 24),
          _InfoGrid(
            items: [
              _InfoItem('Tarjeta Taploe', 'Lista para conectar'),
              _InfoItem('Perfil digital', 'Se creará al vincularla'),
              _InfoItem('Proceso seguro', 'Solo tú puedes confirmarlo'),
            ],
          ),
          const SizedBox(height: 26),
          TaploeButton(
            label: 'Continuar',
            icon: Icons.arrow_forward_rounded,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class ActivationProfileSelectorView extends StatelessWidget {
  final List<DigitalProfileModel> profiles;
  final DigitalProfileModel? selected;
  final String? errorMessage;
  final ValueChanged<DigitalProfileModel> onSelected;
  final VoidCallback onCreateProfile;
  final VoidCallback? onContinue;

  const ActivationProfileSelectorView({
    super.key,
    required this.profiles,
    required this.selected,
    required this.errorMessage,
    required this.onSelected,
    required this.onCreateProfile,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return _AccessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TaploeLogo(size: 42),
          const SizedBox(height: 26),
          _Title('¿A qué perfil quieres vincular esta tarjeta?'),
          const SizedBox(height: 10),
          _MutedText(
            'Elige el perfil que se abrirá cuando alguien escanee o acerque esta tarjeta.',
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _InlineError(errorMessage!),
          ],
          const SizedBox(height: 22),
          ...profiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SelectableProfileTile(
                profile: profile,
                selected: selected?.id == profile.id,
                onTap: () => onSelected(profile),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TaploeButton(
            label: 'Crear nuevo perfil',
            icon: Icons.add_rounded,
            kind: TaploeButtonKind.secondary,
            onPressed: onCreateProfile,
          ),
          const SizedBox(height: 12),
          TaploeButton(
            label: 'Continuar',
            icon: Icons.arrow_forward_rounded,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class ActivationConfirmView extends StatelessWidget {
  final ProfileAccessPointModel? accessPoint;
  final PhysicalCardModel? card;
  final DigitalProfileModel? profile;
  final String? errorMessage;
  final VoidCallback? onChangeProfile;
  final VoidCallback onActivate;

  const ActivationConfirmView({
    super.key,
    required this.accessPoint,
    required this.card,
    required this.profile,
    required this.errorMessage,
    required this.onChangeProfile,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.displayName ?? 'tu cuenta Taploe';
    return _AccessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TaploeLogo(size: 42),
          const SizedBox(height: 26),
          _AccessIcon(icon: Icons.link_rounded),
          const SizedBox(height: 18),
          _Title('Vincular esta tarjeta'),
          const SizedBox(height: 10),
          _MutedText(
            profile == null
                ? 'Al vincular esta tarjeta crearemos tu perfil digital.'
                : 'Esta tarjeta quedará conectada al perfil $displayName.',
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _InlineError(errorMessage!),
          ],
          const SizedBox(height: 22),
          _InfoGrid(
            items: [
              _InfoItem(
                profile == null ? 'Perfil digital' : 'Perfil conectado',
                profile == null ? 'Se creará ahora' : displayName,
              ),
              _InfoItem('Al compartir', 'Abrirá tu perfil digital'),
              _InfoItem('Accesos físicos', 'QR y NFC listos'),
            ],
          ),
          const SizedBox(height: 24),
          TaploeButton(
            label: 'Vincular tarjeta',
            icon: Icons.check_circle_rounded,
            onPressed: onActivate,
          ),
          if (onChangeProfile != null) ...[
            const SizedBox(height: 10),
            TaploeButton(
              label: 'Cambiar perfil',
              icon: Icons.swap_horiz_rounded,
              kind: TaploeButtonKind.secondary,
              onPressed: onChangeProfile,
            ),
          ],
        ],
      ),
    );
  }
}

class ActivationSuccessView extends StatelessWidget {
  final ActivationResultModel? result;
  final DigitalProfileModel? profile;
  final PhysicalCardModel? card;

  const ActivationSuccessView({
    super.key,
    required this.result,
    required this.profile,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    final slug = result?.publicSlug ?? profile?.publicSlug;
    return _AccessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TaploeLogo(size: 42),
          const SizedBox(height: 28),
          _AccessIcon(icon: Icons.check_rounded),
          const SizedBox(height: 18),
          _Title('Tarjeta vinculada correctamente'),
          const SizedBox(height: 10),
          _MutedText(
            'Tu tarjeta Taploe ya está lista para compartir tu perfil.',
          ),
          const SizedBox(height: 24),
          _InfoGrid(
            items: [
              _InfoItem(
                'Perfil conectado',
                profile?.displayName ?? 'Perfil Taploe',
              ),
              _InfoItem('Tarjeta Taploe', 'Vinculada a tu cuenta'),
              _InfoItem('Accesos físicos', 'QR y NFC activos'),
            ],
          ),
          const SizedBox(height: 24),
          TaploeButton(
            label: 'Ver mi perfil',
            icon: Icons.open_in_new_rounded,
            onPressed: slug == null ? null : () => context.go('/p/$slug'),
          ),
          const SizedBox(height: 10),
          TaploeButton(
            label: 'Editar perfil',
            icon: Icons.edit_rounded,
            kind: TaploeButtonKind.secondary,
            onPressed: () => context.go('/profile'),
          ),
          const SizedBox(height: 10),
          TaploeButton(
            label: 'Ir al inicio',
            icon: Icons.space_dashboard_outlined,
            kind: TaploeButtonKind.secondary,
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}

class AlreadyClaimedView extends StatelessWidget {
  final String title;
  final String message;
  final DigitalProfileModel? profile;
  final bool mine;

  const AlreadyClaimedView({
    super.key,
    required this.title,
    required this.message,
    required this.profile,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      icon: mine ? Icons.verified_rounded : Icons.lock_rounded,
      title: title,
      message: message,
      primaryLabel: mine ? 'Ver perfil' : 'Ir a Taploe',
      onPrimary: () {
        if (mine && profile != null) {
          context.go('/p/${profile!.publicSlug}');
        } else {
          context.go('/login');
        }
      },
      secondaryLabel: mine ? 'Administrar tarjetas' : null,
      onSecondary: mine ? () => context.go('/cards') : null,
    );
  }
}

class AccessNotFoundView extends StatelessWidget {
  const AccessNotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      icon: Icons.search_off_rounded,
      title: 'Acceso no encontrado',
      message: 'Este enlace no pertenece a una tarjeta Taploe activa.',
      primaryLabel: 'Ir a Taploe',
      onPrimary: () => context.go('/login'),
    );
  }
}

class AccessDisabledView extends StatelessWidget {
  const AccessDisabledView({super.key});

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      icon: Icons.block_rounded,
      title: 'Acceso inactivo',
      message: 'Este acceso fue desactivado o reemplazado.',
      primaryLabel: 'Ir a Taploe',
      onPrimary: () => context.go('/login'),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String title;

  const _LoadingCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return _AccessCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TaploeLogo(size: 42, centered: true),
          const SizedBox(height: 28),
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
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

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return _AccessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TaploeLogo(size: 42),
          const SizedBox(height: 28),
          _AccessIcon(icon: icon),
          const SizedBox(height: 18),
          _Title(title),
          const SizedBox(height: 10),
          _MutedText(message),
          const SizedBox(height: 24),
          TaploeButton(label: primaryLabel, onPressed: onPrimary),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 10),
            TaploeButton(
              label: secondaryLabel!,
              kind: TaploeButtonKind.secondary,
              onPressed: onSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  final Widget child;

  const _AccessCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      padding: EdgeInsets.all(context.isMobile ? 22 : 32),
      child: child,
    );
  }
}

class _AccessIcon extends StatelessWidget {
  final IconData icon;

  const _AccessIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: TaploeColors.blue.withValues(alpha: .08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: TaploeColors.blue, size: 28),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: context.isMobile ? 30 : 38,
        fontWeight: FontWeight.w900,
        height: .98,
        color: context.text,
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;

  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: context.muted,
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaploeColors.error.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaploeColors.error.withValues(alpha: .25)),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(
          color: TaploeColors.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;

  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: columns == 1 ? 4.5 : 1.6,
          children: items.map((item) => _InfoTile(item: item)).toList(),
        );
      },
    );
  }
}

class _InfoItem {
  final String label;
  final String value;

  const _InfoItem(this.label, this.value);
}

class _InfoTile extends StatelessWidget {
  final _InfoItem item;

  const _InfoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: context.muted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableProfileTile extends StatelessWidget {
  final DigitalProfileModel profile;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableProfileTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? TaploeColors.blue.withValues(alpha: .06)
              : TaploeColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? TaploeColors.blue : TaploeColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: TaploeColors.black,
              backgroundImage: profile.profilePhotoUrl == null
                  ? null
                  : NetworkImage(profile.profilePhotoUrl!),
              child: profile.profilePhotoUrl == null
                  ? Text(
                      profile.displayName.isEmpty
                          ? 'T'
                          : profile.displayName[0].toUpperCase(),
                      style: const TextStyle(color: TaploeColors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w900,
                      color: context.text,
                    ),
                  ),
                  Text(
                    TaploeConfig.profileUrl(profile.publicSlug),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: context.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? TaploeColors.blue : context.muted,
            ),
          ],
        ),
      ),
    );
  }
}
