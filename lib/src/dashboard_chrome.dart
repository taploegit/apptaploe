import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets.dart';

class TaploeNavItem {
  final String id;
  final String label;
  final IconData icon;

  const TaploeNavItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class TaploeDashboardSidebar extends StatelessWidget {
  final String selectedId;
  final List<TaploeNavItem> items;
  final ValueChanged<String> onSelected;
  final VoidCallback onLinkCard;
  final VoidCallback? onNewProfile;
  final VoidCallback onSignOut;

  const TaploeDashboardSidebar({
    super.key,
    required this.selectedId,
    required this.items,
    required this.onSelected,
    required this.onLinkCard,
    this.onNewProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final user = taploeState.currentUser;
    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : user?.email ?? 'Taploe';

    return Container(
      width: 272,
      color: TaploeColors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
              children: [
                const TaploeLogo(size: 34),
                const SizedBox(height: 30),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: TaploeColors.black,
                      child: Text(
                        initials(name),
                        style: const TextStyle(
                          color: TaploeColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: TaploeColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SidebarActiveProfileSelector(
                  profiles: taploeState.profiles,
                  activeProfile: taploeState.activeProfile,
                  onSelected: taploeState.setActiveProfile,
                ),
                const SizedBox(height: 24),
                PopupMenuButton<String>(
                  tooltip: 'Crear',
                  offset: const Offset(0, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) {
                    if (value == 'profile') onNewProfile?.call();
                    if (value == 'card') onLinkCard();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      enabled: onNewProfile != null,
                      child: const Row(
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('Nuevo perfil'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
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
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: TaploeColors.blue,
                      borderRadius: BorderRadius.circular(TaploeRadius.pill),
                      border: Border.all(color: TaploeColors.blue),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          color: TaploeColors.white,
                          size: 20,
                        ),
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
                ),
                const SizedBox(height: 26),
                Text(
                  'MENÚ',
                  style: GoogleFonts.dmSans(
                    color: TaploeColors.disabled,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SidebarItem(
                      item: item,
                      active: item.id == selectedId,
                      onTap: () => onSelected(item.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
            child: _SidebarItem(
              item: const TaploeNavItem(
                id: 'sign-out',
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
              ),
              active: false,
              onTap: onSignOut,
              borderless: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarActiveProfileSelector extends StatelessWidget {
  final List<DigitalProfileModel> profiles;
  final DigitalProfileModel? activeProfile;
  final ValueChanged<DigitalProfileModel> onSelected;

  const _SidebarActiveProfileSelector({
    required this.profiles,
    required this.activeProfile,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final name = activeProfile?.displayName.trim().isNotEmpty == true
        ? activeProfile!.displayName.trim()
        : 'Sin perfil seleccionado';
    final selectedId = profiles.any((item) => item.id == activeProfile?.id)
        ? activeProfile!.id
        : null;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedId,
        isExpanded: true,
        menuWidth: 222,
        borderRadius: BorderRadius.circular(16),
        icon: const SizedBox.shrink(),
        selectedItemBuilder: (context) => profiles
            .map((_) => _ProfileSelectorFace(name: name, sidebar: true))
            .toList(),
        items: profiles
            .map(
              (profile) => DropdownMenuItem<String>(
                value: profile.id,
                child: _ProfileSelectorMenuItem(
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
        hint: _ProfileSelectorFace(name: name, sidebar: true),
      ),
    );
  }
}

class _ProfileSelectorFace extends StatelessWidget {
  final String name;
  final bool sidebar;

  const _ProfileSelectorFace({required this.name, required this.sidebar});

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
        borderRadius: BorderRadius.circular(sidebar ? 16 : TaploeRadius.pill),
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
                    color: TaploeColors.textSecondary,
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
                          color: TaploeColors.black,
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

class _ProfileSelectorMenuItem extends StatelessWidget {
  final DigitalProfileModel profile;
  final bool active;

  const _ProfileSelectorMenuItem({required this.profile, required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: active ? TaploeColors.blue : TaploeColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: TaploeColors.black,
                fontWeight: active ? FontWeight.w600 : FontWeight.w600,
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

class _SidebarItem extends StatelessWidget {
  final TaploeNavItem item;
  final bool active;
  final VoidCallback onTap;
  final bool borderless;

  const _SidebarItem({
    required this.item,
    required this.active,
    required this.onTap,
    this.borderless = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? TaploeColors.black : TaploeColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: borderless
            ? BorderSide.none
            : BorderSide(
                color: active ? TaploeColors.black : TaploeColors.border,
              ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: active ? TaploeColors.white : TaploeColors.black,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: active ? TaploeColors.white : TaploeColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaploeDashboardHeader extends StatelessWidget {
  final DigitalProfileModel? activeProfile;
  final List<DigitalProfileModel> profiles;
  final bool profileIncomplete;
  final ValueChanged<DigitalProfileModel> onProfileSelected;
  final VoidCallback onViewProfile;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;

  const TaploeDashboardHeader({
    super.key,
    required this.activeProfile,
    required this.profiles,
    required this.profileIncomplete,
    required this.onProfileSelected,
    required this.onViewProfile,
    required this.onSettings,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: TaploeColors.white,
        border: Border(bottom: BorderSide(color: TaploeColors.border)),
      ),
      child: Row(
        children: [
          if (profiles.isNotEmpty)
            SizedBox(
              width: 250,
              child: _HeaderActiveProfileSelector(
                profiles: profiles,
                activeProfile: activeProfile,
                onSelected: onProfileSelected,
              ),
            ),
          const Spacer(),
          if (profileIncomplete) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: TaploeColors.blueSoft,
                borderRadius: BorderRadius.circular(TaploeRadius.pill),
                border: Border.all(color: TaploeColors.blueBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: TaploeColors.blue,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Perfil incompleto',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TaploeColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          TaploeButton(
            label: 'Ver perfil',
            icon: Icons.open_in_new_rounded,
            kind: TaploeButtonKind.secondary,
            width: 154,
            onPressed: activeProfile == null ? null : onViewProfile,
          ),
          const SizedBox(width: 12),
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
            onSelected: (value) {
              if (value == 'settings') onSettings();
              if (value == 'logout') onSignOut();
            },
            itemBuilder: (_) => const [
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
            child: CircleAvatar(
              radius: 21,
              backgroundColor: TaploeColors.black,
              child: Text(
                initials(
                  taploeState.currentUser?.fullName.isNotEmpty == true
                      ? taploeState.currentUser!.fullName
                      : taploeState.currentUser?.email ?? 'T',
                ),
                style: const TextStyle(
                  color: TaploeColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActiveProfileSelector extends StatelessWidget {
  final List<DigitalProfileModel> profiles;
  final DigitalProfileModel? activeProfile;
  final ValueChanged<DigitalProfileModel> onSelected;

  const _HeaderActiveProfileSelector({
    required this.profiles,
    required this.activeProfile,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final name = activeProfile?.displayName.trim().isNotEmpty == true
        ? activeProfile!.displayName.trim()
        : 'Sin perfil seleccionado';
    final selectedId = profiles.any((item) => item.id == activeProfile?.id)
        ? activeProfile!.id
        : null;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedId,
        isExpanded: true,
        menuWidth: 250,
        borderRadius: BorderRadius.circular(16),
        icon: const SizedBox.shrink(),
        selectedItemBuilder: (context) => profiles
            .map((_) => _ProfileSelectorFace(name: name, sidebar: false))
            .toList(),
        items: profiles
            .map(
              (profile) => DropdownMenuItem<String>(
                value: profile.id,
                child: _ProfileSelectorMenuItem(
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
        hint: _ProfileSelectorFace(name: name, sidebar: false),
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

class TaploeMobileHeader extends StatelessWidget
    implements PreferredSizeWidget {
  final VoidCallback? onMenu;

  const TaploeMobileHeader({super.key, this.onMenu});

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 68,
      leading: onMenu == null
          ? null
          : IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
      title: const TaploeLogo(size: 29),
      actions: [
        CircleAvatar(
          radius: 18,
          backgroundColor: TaploeColors.black,
          child: Text(
            initials(
              taploeState.currentUser?.fullName.isNotEmpty == true
                  ? taploeState.currentUser!.fullName
                  : taploeState.currentUser?.email ?? 'T',
            ),
            style: const TextStyle(
              color: TaploeColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
      shape: const Border(bottom: BorderSide(color: TaploeColors.border)),
    );
  }
}
