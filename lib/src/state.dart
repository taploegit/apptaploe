import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repositories.dart';
import 'utils.dart';

class TaploeState extends ChangeNotifier {
  SupabaseClient get client => Supabase.instance.client;

  AppUserModel? currentUser;
  OrganizationModel? organization;
  List<DigitalProfileModel> profiles = [];
  List<PhysicalCardModel> cards = [];
  DigitalProfileModel? activeProfile;
  String? pendingActivationToken;
  bool bootstrapping = true;
  StreamSubscription<AuthState>? _authSubscription;
  Future<void>? _bootstrapFuture;

  bool get signedIn => client.auth.currentUser != null && currentUser != null;
  bool get hasLinkedCard => cards.any(_isLinkedCard);
  bool get canAccessDashboard => signedIn && activeProfile != null;

  void startAuthListener() {
    _authSubscription ??= client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          if (data.session != null) {
            unawaited(_safeBootstrapFromAuthEvent());
          }
          break;
        case AuthChangeEvent.signedOut:
          bootstrapping = false;
          _clearSessionState();
          notifyListeners();
          break;
        default:
          break;
      }
    });
  }

  Future<void> _safeBootstrapFromAuthEvent() async {
    try {
      await bootstrap();
    } catch (error) {
      debugPrint('[TaploeState] No se pudo refrescar la sesión.');
      safePrintError(error);
    }
  }

  Future<void> bootstrap() async {
    if (_bootstrapFuture != null) {
      await _bootstrapFuture;
      return;
    }

    _bootstrapFuture = _bootstrap();
    try {
      await _bootstrapFuture;
    } finally {
      _bootstrapFuture = null;
    }
  }

  Future<void> _bootstrap() async {
    bootstrapping = true;
    notifyListeners();

    try {
      final authUser = client.auth.currentUser;
      pendingActivationToken =
          await CardActivationService.getPendingActivation();

      if (authUser == null) {
        _clearSessionState();
        return;
      }

      currentUser = await UserRepository.currentAppUser();

      if (currentUser == null) {
        _clearSessionState();
        return;
      }

      organization = await UserRepository.firstOrganizationForUser(
        currentUser!.id,
      );

      cards = await CardRepository.fetchCardsForUser(currentUser!.id);
      profiles = await _fetchEditableProfiles();
      _selectActiveProfileFallback();
    } catch (error) {
      debugPrint('[TaploeState] Bootstrap falló.');
      safePrintError(error);
    } finally {
      bootstrapping = false;
      notifyListeners();
    }
  }

  void setActiveProfile(DigitalProfileModel profile) {
    activeProfile = profile;
    notifyListeners();
  }

  void updateActiveProfile(DigitalProfileModel profile) {
    profiles = profiles
        .map((current) => current.id == profile.id ? profile : current)
        .toList();
    activeProfile = profile;
    notifyListeners();
  }

  Future<void> refreshProfiles() async {
    if (currentUser == null) return;

    final current = activeProfile;
    profiles = await _fetchEditableProfiles();
    if (current != null && current.ownerUserId != currentUser!.id) {
      activeProfile = await ProfileRepository.fetchProfileById(current.id);
      activeProfile ??= current;
      notifyListeners();
      return;
    }
    _selectActiveProfileFallback();

    notifyListeners();
  }

  Future<List<DigitalProfileModel>> _fetchEditableProfiles() async {
    final user = currentUser;
    if (user == null) return const [];
    final ownProfiles = await ProfileRepository.fetchProfilesForUser(user.id);
    final org = organization;
    if (org == null) return ownProfiles;

    try {
      final members = await TeamRepository.fetchTeam(org.id);
      String? role;
      for (final member in members) {
        if (member.id == user.id && member.status == 'active') {
          role = member.role;
          break;
        }
      }
      if (role != 'owner' && role != 'admin') return ownProfiles;

      final orgProfiles = await ProfileRepository.fetchProfilesForOrg(org.id);
      return _dedupeProfiles([...ownProfiles, ...orgProfiles]);
    } catch (error) {
      debugPrint('[TaploeState] No se pudieron cargar perfiles editables.');
      safePrintError(error);
      return ownProfiles;
    }
  }

  List<DigitalProfileModel> _dedupeProfiles(List<DigitalProfileModel> input) {
    final byId = <String, DigitalProfileModel>{};
    for (final profile in input) {
      byId[profile.id] = profile;
    }
    return byId.values.toList();
  }

  Future<void> refreshCards() async {
    if (currentUser == null) return;

    cards = await CardRepository.fetchCardsForUser(currentUser!.id);
    notifyListeners();
  }

  Future<void> refreshAll() async {
    if (currentUser == null) return;

    organization = await UserRepository.firstOrganizationForUser(
      currentUser!.id,
    );

    await refreshCards();
    await refreshProfiles();

    notifyListeners();
  }

  Future<void> savePendingActivationToken(String token) async {
    pendingActivationToken = token;
    await CardActivationService.savePendingActivation(token);
    notifyListeners();
  }

  Future<void> clearPendingActivationToken() async {
    pendingActivationToken = null;
    await CardActivationService.clearPendingActivation();
    notifyListeners();
  }

  Future<void> signOut() async {
    await client.auth.signOut();

    _clearSessionState();

    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _clearSessionState() {
    currentUser = null;
    organization = null;
    profiles = [];
    cards = [];
    activeProfile = null;
  }

  bool _isLinkedCard(PhysicalCardModel card) {
    return card.activeProfileId != null &&
        card.status != 'disabled' &&
        card.status != 'lost' &&
        card.status != 'replaced';
  }

  void _selectActiveProfileFallback() {
    if (profiles.isEmpty) {
      activeProfile = null;
      return;
    }

    final current = activeProfile;
    if (current != null &&
        profiles.any((profile) => profile.id == current.id)) {
      activeProfile = profiles.firstWhere(
        (profile) => profile.id == current.id,
        orElse: () => current,
      );
      return;
    }

    for (final profile in profiles) {
      if (profile.isDefault) {
        activeProfile = profile;
        return;
      }
    }

    activeProfile = profiles.first;
  }
}

final taploeState = TaploeState();
