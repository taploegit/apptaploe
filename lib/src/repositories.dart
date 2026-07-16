import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_location.dart';
import 'models.dart';
import 'plan_capabilities.dart';
import 'utils.dart';

SupabaseClient get _db => Supabase.instance.client;

const int taploeMaxProfileLinks = 15;

class ProfileAssetRepository {
  static const bucket = 'profile-assets';

  static Future<String> uploadProfileAsset({
    required String authUserId,
    required String profileId,
    required String kind,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final extension = _extensionFrom(fileName);
    final contentType = _contentTypeFor(extension);
    final path =
        '$authUserId/$profileId/$kind-${DateTime.now().millisecondsSinceEpoch}.$extension';

    debugPrint('[TaploeStorage] Uploading $bucket/$path');

    await _db.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return _db.storage.from(bucket).getPublicUrl(path);
  }

  static String _extensionFrom(String fileName) {
    final clean = fileName.toLowerCase().split('?').first;
    final parts = clean.split('.');
    if (parts.length < 2) return 'jpg';
    final ext = parts.last;
    if (ext == 'jpeg' || ext == 'jpg' || ext == 'png' || ext == 'webp') {
      return ext;
    }
    return 'jpg';
  }

  static String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}

class OrganizationAssetRepository {
  static const bucket = 'company-logos';

  static Future<String> uploadCompanyLogo({
    required String authUserId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final extension = _extensionFrom(fileName);
    final contentType = _contentTypeFor(extension);
    final path =
        '$authUserId/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';

    debugPrint('[TaploeStorage] Uploading $bucket/$path');

    await _db.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return _db.storage.from(bucket).getPublicUrl(path);
  }

  static String _extensionFrom(String fileName) {
    final clean = fileName.toLowerCase().split('?').first;
    final parts = clean.split('.');
    if (parts.length < 2) return 'jpg';
    final ext = parts.last;
    if (ext == 'jpeg' || ext == 'jpg' || ext == 'png' || ext == 'webp') {
      return ext;
    }
    return 'jpg';
  }

  static String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}

class SessionStorage {
  static const _pendingActivationTokenKey = 'taploe.pendingActivationToken';
  static const _lastAccessPointIdKey = 'taploe.lastAccessPointId';
  static const _lastPhysicalCardIdKey = 'taploe.lastPhysicalCardId';
  static const _lastAccessChannelKey = 'taploe.lastAccessChannel';
  static const _lastProfileIdKey = 'taploe.lastProfileId';
  static const _visitorSessionIdKey = 'taploe.visitorSessionId';

  static Future<void> savePendingActivationToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingActivationTokenKey, token);
  }

  static Future<String?> getPendingActivationToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingActivationTokenKey);
  }

  static Future<void> clearPendingActivationToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingActivationTokenKey);
  }

  static Future<void> saveVisitorAttribution({
    required String accessPointId,
    required String channel,
    String? physicalCardId,
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAccessPointIdKey, accessPointId);
    await prefs.setString(_lastAccessChannelKey, channel);
    await prefs.setString(
      _visitorSessionIdKey,
      prefs.getString(_visitorSessionIdKey) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
    );
    if (physicalCardId != null) {
      await prefs.setString(_lastPhysicalCardIdKey, physicalCardId);
    }
    if (profileId != null) {
      await prefs.setString(_lastProfileIdKey, profileId);
    }
  }

  static Future<Map<String, String?>> getVisitorAttribution() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'accessPointId': prefs.getString(_lastAccessPointIdKey),
      'physicalCardId': prefs.getString(_lastPhysicalCardIdKey),
      'channel': prefs.getString(_lastAccessChannelKey),
      'profileId': prefs.getString(_lastProfileIdKey),
      'visitorSessionId': prefs.getString(_visitorSessionIdKey),
    };
  }
}

class NotificationRepository {
  static Future<List<AppNotificationModel>> fetchRecent(String userId) async {
    try {
      final rows = await _db
          .from('app_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(12);
      return (rows as List)
          .map(
            (row) =>
                AppNotificationModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
    } catch (error) {
      debugPrint('[TaploeNotifications] No se pudieron cargar notificaciones.');
      safePrintError(error);
      return const [];
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await _db
          .from('app_notifications')
          .update({'read_at': nowIso()})
          .eq('id', notificationId)
          .isFilter('read_at', null);
    } catch (error) {
      debugPrint('[TaploeNotifications] No se pudo marcar como leída.');
      safePrintError(error);
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      await _db
          .from('app_notifications')
          .update({'read_at': nowIso()})
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (error) {
      debugPrint('[TaploeNotifications] No se pudieron marcar como leídas.');
      safePrintError(error);
    }
  }
}

class TeamInviteException implements Exception {
  final String code;

  const TeamInviteException(this.code);

  @override
  String toString() => code;
}

class QuoteRequestRepository {
  static Future<void> createTeamPlanRequest({
    required String solutionType,
    required int approximateQuantity,
    required String fullName,
    required String email,
    String? company,
    String? phone,
    String? message,
  }) async {
    await _db.from('quote_requests').insert({
      'solution_type': solutionType,
      'approximate_quantity': approximateQuantity,
      'full_name': fullName.trim(),
      'company': company?.trim().isEmpty == true ? null : company?.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'email': email.trim().toLowerCase(),
      'message': message?.trim().isEmpty == true ? null : message?.trim(),
      'metadata': {
        'source': 'dashboard_team_plan',
        'requested_by_user_id': _db.auth.currentUser?.id,
      },
    });
  }
}

class UserRepository {
  static String normalizeUsername(String value) => normalizePublicSlug(value);

  static Future<User?> verifiedAuthUser() async {
    if (_db.auth.currentUser == null) return null;

    try {
      final response = await _db.auth.getUser();
      return response.user;
    } catch (error) {
      debugPrint('[TaploeAuth] No se pudo validar la sesión con Auth.');
      safePrintError(error);
      return null;
    }
  }

  static Future<AppUserModel?> _fetchByAuthUserId(String authUserId) async {
    final existing = await _db
        .from('app_users')
        .select()
        .eq('auth_user_id', authUserId)
        .maybeSingle();

    if (existing == null) return null;
    return AppUserModel.fromJson(Map<String, dynamic>.from(existing));
  }

  static Future<AppUserModel?> currentAppUser({
    String? preferredLanguage,
    String? preferredMarket,
    bool persistLocaleOverride = false,
  }) async {
    final auth = await verifiedAuthUser();
    if (auth == null) return null;

    final existing = await _fetchByAuthUserId(auth.id);
    if (existing != null) {
      if (persistLocaleOverride &&
          preferredLanguage != null &&
          preferredMarket != null &&
          (existing.preferredLanguage != preferredLanguage ||
              existing.preferredMarket != preferredMarket)) {
        return updateLocalePreference(
          preferredLanguage: preferredLanguage,
          preferredMarket: preferredMarket,
        );
      }
      return existing;
    }

    final email = auth.email ?? '';
    final name =
        (auth.userMetadata?['username'] ??
                auth.userMetadata?['full_name'] ??
                auth.userMetadata?['name'] ??
                email.split('@').first)
            .toString();
    final username = await generateUniqueUsername(name);

    try {
      await _db.from('app_users').insert({
        'auth_user_id': auth.id,
        'username': username,
        'email': email,
        'status': 'active',
        'plan_type': 'free',
        'preferred_language': preferredLanguage ?? 'es',
        'preferred_market': preferredMarket ?? 'mx',
        'timezone': preferredMarket == 'us'
            ? 'America/Los_Angeles'
            : 'America/Tijuana',
      });
    } on PostgrestException catch (error) {
      if (!_isDuplicateAuthUser(error)) rethrow;
    }

    return _fetchByAuthUserId(auth.id);
  }

  static Future<AppUserModel?> fetchById(String userId) async {
    final row = await _db
        .from('app_users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AppUserModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<AppUserModel> upsertCurrentUser({
    String? username,
    required String email,
    String? preferredLanguage,
    String? preferredMarket,
  }) async {
    final auth = await verifiedAuthUser();
    if (auth == null) throw Exception('No hay sesión activa.');

    final existing = await _fetchByAuthUserId(auth.id);
    final requestedUsername = username?.trim().isNotEmpty == true
        ? normalizeUsername(username!)
        : null;

    if (existing != null) {
      if (requestedUsername != null &&
          requestedUsername != normalizeUsername(existing.username) &&
          await usernameExists(requestedUsername, excludeUserId: existing.id)) {
        throw ArgumentError('username_taken');
      }

      final updates = <String, dynamic>{
        'username': requestedUsername ?? existing.username,
        'email': email.trim().toLowerCase(),
        'last_login_at': nowIso(),
        'updated_at': nowIso(),
      };
      if (preferredLanguage != null) {
        updates['preferred_language'] = preferredLanguage;
      }
      if (preferredMarket != null) {
        updates['preferred_market'] = preferredMarket;
      }

      await _db.from('app_users').update(updates).eq('auth_user_id', auth.id);

      return (await _fetchByAuthUserId(auth.id))!;
    }

    final generatedUsername = await generateUniqueUsername(
      requestedUsername ?? email.split('@').first,
    );

    try {
      await _db.from('app_users').insert({
        'auth_user_id': auth.id,
        'username': generatedUsername,
        'email': email.trim().toLowerCase(),
        'status': 'active',
        'plan_type': 'free',
        'preferred_language': preferredLanguage ?? 'es',
        'preferred_market': preferredMarket ?? 'mx',
        'timezone': preferredMarket == 'us'
            ? 'America/Los_Angeles'
            : 'America/Tijuana',
        'last_login_at': nowIso(),
      });
    } on PostgrestException catch (error) {
      if (!_isDuplicateAuthUser(error)) rethrow;
    }

    return (await _fetchByAuthUserId(auth.id))!;
  }

  static bool _isDuplicateAuthUser(PostgrestException error) {
    return error.code == '23505' &&
        error.message.contains('app_users_auth_user_id_key');
  }

  static Future<bool> usernameExists(
    String username, {
    String? excludeUserId,
  }) async {
    final clean = normalizeUsername(username);
    if (clean.isEmpty) return false;

    final query = _db.from('app_users').select('id').ilike('username', clean);
    final rows = excludeUserId == null
        ? await query.limit(1)
        : await query.neq('id', excludeUserId).limit(1);
    return rows.isNotEmpty;
  }

  static Future<String> generateUniqueUsername(String base) async {
    final normalizedBase = normalizeUsername(base);
    final usernameBase = normalizedBase.length >= 3
        ? normalizedBase
        : 'taploe-${DateTime.now().millisecondsSinceEpoch}';
    var username = usernameBase;
    var i = 1;
    while (await usernameExists(username)) {
      username = '$usernameBase-$i';
      i++;
    }
    return username;
  }

  static Future<AppUserModel> updateCurrentUser({
    required String username,
    String? phone,
    String? timezone,
    String? preferredLanguage,
    String? preferredMarket,
  }) async {
    final current = await verifiedAuthUser();
    if (current == null) throw Exception('No hay sesión activa.');
    final existing = await _fetchByAuthUserId(current.id);
    if (existing == null) throw Exception('No se pudo cargar el usuario.');

    final cleanUsername = normalizeUsername(username);
    if (cleanUsername.length < 3) {
      throw ArgumentError('username_too_short');
    }
    if (await usernameExists(cleanUsername, excludeUserId: existing.id)) {
      throw ArgumentError('username_taken');
    }

    final updates = <String, dynamic>{
      'username': cleanUsername,
      'phone': phone?.trim(),
      'updated_at': nowIso(),
    };
    if (timezone != null && timezone.trim().isNotEmpty) {
      updates['timezone'] = timezone.trim();
    }
    if (preferredLanguage != null) {
      updates['preferred_language'] = preferredLanguage;
    }
    if (preferredMarket != null) {
      updates['preferred_market'] = preferredMarket;
    }

    await _db.from('app_users').update(updates).eq('auth_user_id', current.id);

    final user = await _fetchByAuthUserId(current.id);
    if (user == null) throw Exception('No se pudo cargar el usuario.');
    if (preferredLanguage != null && preferredMarket != null) {
      await ProfileRepository.syncOwnerPublicLocale(user);
    }
    return user;
  }

  static Future<AppUserModel> updateLocalePreference({
    required String preferredLanguage,
    required String preferredMarket,
  }) async {
    final current = await verifiedAuthUser();
    if (current == null) throw Exception('No hay sesión activa.');

    await _db
        .from('app_users')
        .update({
          'preferred_language': preferredLanguage,
          'preferred_market': preferredMarket,
          'updated_at': nowIso(),
        })
        .eq('auth_user_id', current.id);

    final user = await _fetchByAuthUserId(current.id);
    if (user == null) throw Exception('No se pudo cargar el usuario.');
    await ProfileRepository.syncOwnerPublicLocale(user);
    return user;
  }

  static Future<OrganizationModel?> firstOrganizationForUser(
    String userId,
  ) async {
    final membership = await _db
        .from('organization_members')
        .select('org_id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();

    final orgId = membership == null ? null : membership['org_id'] as String?;
    if (orgId == null) return null;

    final org = await _db
        .from('organizations')
        .select()
        .eq('id', orgId)
        .maybeSingle();
    if (org == null) return null;
    return OrganizationModel.fromJson(Map<String, dynamic>.from(org));
  }

  static Future<DigitalProfileModel> ensureDefaultProfile(
    AppUserModel user,
  ) async {
    final existing = await ProfileRepository.fetchProfilesForUser(user.id);
    if (existing.isNotEmpty) {
      await ProfileRepository.ensureInitialRecords(existing.first, user);
      return (await ProfileRepository.fetchProfileById(existing.first.id)) ??
          existing.first;
    }

    final slug = await ProfileRepository.generateUniqueSlug(
      user.username.isNotEmpty ? user.username : user.email,
    );

    final inserted = await _db
        .from('digital_profiles')
        .insert({
          'owner_user_id': user.id,
          'display_name': user.username.isNotEmpty
              ? user.username
              : 'Taploe User',
          'profile_name': 'Perfil principal',
          'public_slug': slug,
          'public_locale': user.localeConfig.localeCode,
          'status': 'active',
          'visibility': 'public',
          'is_default': true,
        })
        .select()
        .single();

    final profileId = inserted['id'] as String;
    final profile = DigitalProfileModel(
      id: profileId,
      ownerUserId: user.id,
      displayName: user.username.isNotEmpty ? user.username : 'Taploe User',
      profileName: 'Perfil principal',
      publicSlug: slug,
      publicLocale: user.localeConfig.localeCode,
      status: 'active',
      isDefault: true,
    );

    await ProfileRepository.ensureInitialRecords(profile, user);

    return (await ProfileRepository.fetchProfileById(profileId))!;
  }
}

class BillingRepository {
  static const _subscriptionSelect = '''
    id,scope,user_id,org_id,owner_user_id,plan_type,billing_interval,status,
    cancel_at_period_end,trial_start,trial_end,current_period_start,
    current_period_end,grace_until,canceled_at,ended_at,stripe_customer_id,
    stripe_subscription_id,stripe_price_id,stripe_product_id,quantity,currency,
    last_payment_at,next_payment_at,latest_invoice_id,latest_invoice_status,
    hosted_invoice_url,payment_issue,payment_action_required,
    trial_ending_notified_at,metadata,created_at
  ''';

  static const _invoiceSelect = '''
    id,subscription_id,user_id,org_id,stripe_invoice_id,
    stripe_payment_intent_id,status,currency,amount_due,amount_paid,
    amount_remaining,hosted_invoice_url,invoice_pdf,period_start,period_end,
    paid_at,created_at
  ''';

  static Future<BillingSubscriptionModel?> fetchUserSubscription(
    String userId,
  ) async {
    try {
      final row = await _db
          .from('billing_subscriptions')
          .select(_subscriptionSelect)
          .eq('scope', 'user')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return BillingSubscriptionModel.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('[TaploeBilling] No se pudo cargar suscripción individual.');
      safePrintError(error);
      return null;
    }
  }

  static Future<BillingSubscriptionModel?> fetchOrganizationSubscription(
    String orgId,
  ) async {
    try {
      final row = await _db
          .from('billing_subscriptions')
          .select(_subscriptionSelect)
          .eq('scope', 'organization')
          .eq('org_id', orgId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return BillingSubscriptionModel.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('[TaploeBilling] No se pudo cargar suscripción de empresa.');
      safePrintError(error);
      return null;
    }
  }

  static Future<List<BillingInvoiceModel>> fetchInvoices({
    String? userId,
    String? orgId,
    int limit = 12,
  }) async {
    try {
      List rows;
      if (orgId != null && orgId.isNotEmpty) {
        rows = await _db
            .from('billing_invoices')
            .select(_invoiceSelect)
            .eq('org_id', orgId)
            .order('created_at', ascending: false)
            .limit(limit);
      } else if (userId != null && userId.isNotEmpty) {
        rows = await _db
            .from('billing_invoices')
            .select(_invoiceSelect)
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(limit);
      } else {
        return const [];
      }
      return rows
          .map(
            (row) => BillingInvoiceModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } catch (error) {
      debugPrint('[TaploeBilling] No se pudo cargar historial de pagos.');
      safePrintError(error);
      return const [];
    }
  }

  static Future<String> createCheckoutSession({
    required String plan,
    required String billingPeriod,
    required int quantity,
    String language = 'es',
    String market = 'mx',
    String locale = 'es-MX',
  }) async {
    final response = await _db.functions.invoke(
      'create-checkout-session',
      body: {
        'plan': plan,
        'billingPeriod': billingPeriod,
        'quantity': quantity,
        'language': language == 'en' ? 'en' : 'es',
        'market': market == 'us' ? 'us' : 'mx',
        'locale': locale,
      },
    );
    final data = response.data;
    if (data is Map && data['checkoutUrl'] is String) {
      return data['checkoutUrl'] as String;
    }
    throw StateError('checkout_url_missing');
  }

  static Future<String> createPortalSession({String scope = 'user'}) async {
    final response = await _db.functions.invoke(
      'create-portal-session',
      body: {'scope': scope == 'organization' ? 'organization' : 'user'},
    );
    final data = response.data;
    if (data is Map && data['portalUrl'] is String) {
      return data['portalUrl'] as String;
    }
    throw StateError('portal_url_missing');
  }
}

class OrganizationRepository {
  static Future<OrganizationModel?> fetchById(String orgId) async {
    try {
      final row = await _db
          .from('organizations')
          .select()
          .eq('id', orgId)
          .maybeSingle();
      if (row == null) return null;
      return OrganizationModel.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('[TaploeOrganizations] No se pudo cargar la organización.');
      safePrintError(error);
      return null;
    }
  }

  static Future<bool> slugExists(String slug) async {
    final clean = normalizePublicSlug(slug);
    if (clean.isEmpty) return false;
    final rows = await _db
        .from('organizations')
        .select('id')
        .eq('slug', clean)
        .limit(1);
    return rows.isNotEmpty;
  }

  static Future<String> generateUniqueSlug(String base) async {
    final slugBase = slugify(base);
    var slug = slugBase;
    var i = 1;
    while (await slugExists(slug)) {
      slug = '$slugBase-$i';
      i++;
    }
    return slug;
  }

  static Future<OrganizationModel> createCompanyForOwner({
    required AppUserModel owner,
    required String name,
    String? logoUrl,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw ArgumentError('company_name_too_short');
    }

    final slug = await generateUniqueSlug(cleanName);
    final orgRow = await _db
        .from('organizations')
        .insert({
          'name': cleanName,
          'slug': slug,
          'company_logo_url': logoUrl?.trim().isEmpty == true
              ? null
              : logoUrl?.trim(),
          'plan_type': 'business',
          'created_by_user_id': owner.id,
          'updated_at': nowIso(),
        })
        .select()
        .single();

    final org = OrganizationModel.fromJson(Map<String, dynamic>.from(orgRow));
    await _db.from('organization_members').insert({
      'org_id': org.id,
      'user_id': owner.id,
      'role': 'owner',
      'status': 'active',
      'joined_at': nowIso(),
    });

    await _db
        .from('digital_profiles')
        .update({'org_id': org.id, 'updated_at': nowIso()})
        .eq('owner_user_id', owner.id)
        .isFilter('org_id', null);

    return org;
  }

  static Map<String, dynamic> _teamThemePayload(ProfileThemeModel theme) {
    final payload = Map<String, dynamic>.from(theme.toJson())
      ..remove('profile_id')
      ..remove('updated_at');
    return payload;
  }

  static Future<OrganizationModel?> saveTeamProfileTheme({
    required OrganizationModel org,
    required bool enforce,
    required ProfileThemeModel theme,
    String? logoUrl,
    String? coverPhotoUrl,
  }) async {
    await _db.rpc(
      'set_org_team_profile_theme',
      params: {
        'p_org_id': org.id,
        'p_enforce': enforce,
        'p_theme': _teamThemePayload(theme),
        'p_logo_url': logoUrl?.trim().isEmpty == true ? null : logoUrl?.trim(),
        'p_cover_photo_url': coverPhotoUrl?.trim().isEmpty == true
            ? null
            : coverPhotoUrl?.trim(),
      },
    );
    return fetchById(org.id);
  }

  static Future<OrganizationModel?> saveTeamProfileControls({
    required OrganizationModel org,
    required bool enforceForms,
    required bool enforceIntegrations,
  }) async {
    await _db.rpc(
      'set_org_team_profile_controls',
      params: {
        'p_org_id': org.id,
        'p_enforce_forms': enforceForms,
        'p_enforce_integrations': enforceIntegrations,
      },
    );
    return fetchById(org.id);
  }

  static Future<OrganizationModel?> updateCompanyLogo({
    required OrganizationModel org,
    String? logoUrl,
  }) async {
    final cleanLogoUrl = _cleanOptionalUrl(logoUrl);
    try {
      await _db.rpc(
        'set_org_company_logo',
        params: {'p_org_id': org.id, 'p_logo_url': cleanLogoUrl},
      );
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      await _updateCompanyLogoDirectly(org: org, logoUrl: cleanLogoUrl);
    }
    return fetchById(org.id);
  }

  static String? _cleanOptionalUrl(String? url) {
    final clean = url?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static Future<void> _updateCompanyLogoDirectly({
    required OrganizationModel org,
    required String? logoUrl,
  }) async {
    await _db
        .from('organizations')
        .update({'company_logo_url': logoUrl, 'updated_at': nowIso()})
        .eq('id', org.id);
  }

  static Future<OrganizationSummaryModel> fetchSummary(
    OrganizationModel org,
  ) async {
    final memberships = await _db
        .from('organization_members')
        .select('user_id')
        .eq('org_id', org.id)
        .eq('status', 'active');

    final userIds = (memberships as List)
        .map((row) => (row as Map)['user_id'])
        .whereType<String>()
        .toList();

    final profiles = await _db
        .from('digital_profiles')
        .select('id')
        .eq('org_id', org.id)
        .neq('status', 'deleted');

    final profileIds = (profiles as List)
        .map((row) => (row as Map)['id'])
        .whereType<String>()
        .toList();

    final cards = userIds.isEmpty
        ? <dynamic>[]
        : await _db
              .from('physical_cards')
              .select('id,status')
              .inFilter('owner_user_id', userIds);

    final leads = await _db.from('leads').select('id').eq('org_id', org.id);

    final events = profileIds.isEmpty
        ? <dynamic>[]
        : await _db
              .from('analytics_events')
              .select('event_type,access_channel')
              .inFilter('profile_id', profileIds);

    int views = 0, nfc = 0, qr = 0, clicks = 0;
    for (final raw in events) {
      final event = raw as Map;
      final type = event['event_type'] as String? ?? '';
      final channel = event['access_channel'] as String? ?? 'direct';
      if (type == 'profile_view') {
        views++;
        if (channel == 'nfc') nfc++;
        if (channel == 'qr') qr++;
      }
      if (type == 'link_click' || type == 'calendar_click') clicks++;
    }

    return OrganizationSummaryModel(
      members: userIds.length,
      profiles: profileIds.length,
      cards: cards.where((card) {
        final status = (card as Map)['status'] as String? ?? '';
        return status == 'claimed';
      }).length,
      views: views,
      nfc: nfc,
      qr: qr,
      clicks: clicks,
      leads: (leads as List).length,
    );
  }
}

class AuthRepository {
  static Future<void> sendOtp(String email) async {
    await _db.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: true,
    );
  }

  static Future<void> signInWithOAuth(OAuthProvider provider) async {
    final redirectUri = Uri(
      scheme: Uri.base.scheme,
      host: Uri.base.host,
      port: Uri.base.hasPort ? Uri.base.port : null,
      path: '/auth-loading',
    );
    await _db.auth.signInWithOAuth(
      provider,
      redirectTo: redirectUri.toString(),
    );
  }

  static Future<AppUserModel> verifyOtp({
    required String email,
    required String token,
    String? username,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedToken = token.trim();
    try {
      await _db.auth.verifyOTP(
        email: normalizedEmail,
        token: normalizedToken,
        type: OtpType.email,
      );
    } on AuthException {
      await _db.auth.verifyOTP(
        email: normalizedEmail,
        token: normalizedToken,
        type: OtpType.signup,
      );
    }

    return UserRepository.upsertCurrentUser(
      username: username,
      email: normalizedEmail,
    );
  }
}

class ProfileRepository {
  static const _selectFull = '''
    *,
    profile_theme_settings(*),
    profile_vcard_details(*),
    profile_links(*)
  ''';

  static Future<bool> slugExists(
    String slug, {
    String? excludeProfileId,
  }) async {
    final query = _db
        .from('digital_profiles')
        .select('id')
        .eq('public_slug', slug);
    final rows = excludeProfileId == null
        ? await query.limit(1)
        : await query.neq('id', excludeProfileId).limit(1);
    return rows.isNotEmpty;
  }

  static Future<String> generateUniqueSlug(String base) async {
    final slugBase = slugify(base);
    var slug = slugBase;
    var i = 1;
    while (await slugExists(slug)) {
      slug = '$slugBase-$i';
      i++;
    }
    return slug;
  }

  static Future<void> ensureInitialRecords(
    DigitalProfileModel profile,
    AppUserModel user,
  ) async {
    final theme = await _db
        .from('profile_theme_settings')
        .select('profile_id')
        .eq('profile_id', profile.id)
        .maybeSingle();

    if (theme == null) {
      Map<String, dynamic>? teamTheme;
      final orgId = profile.orgId;
      if (orgId != null && orgId.isNotEmpty) {
        final org = await OrganizationRepository.fetchById(orgId);
        if (org?.enforceTeamProfileTheme == true &&
            org?.teamProfileTheme != null) {
          teamTheme = OrganizationRepository._teamThemePayload(
            org!.teamProfileTheme!,
          );
        }
      }
      await _db.from('profile_theme_settings').insert({
        'profile_id': profile.id,
        ...?teamTheme,
        if (teamTheme == null) ...{
          'theme_style': 'light',
          'layout_style': 'centered',
          'primary_color': '#1557FF',
          'secondary_color': '#FFFFFF',
          'accent_color': '#1557FF',
          'background_type': 'solid',
          'background_color_start': '#FFFFFF',
          'button_style': 'pill',
          'font_family': 'system',
        },
      });
    }

    final vcard = await _db
        .from('profile_vcard_details')
        .select('profile_id')
        .eq('profile_id', profile.id)
        .maybeSingle();

    if (vcard == null) {
      await _db.from('profile_vcard_details').insert({
        'profile_id': profile.id,
        'first_name': user.username,
        'email': user.email,
      });
    }
  }

  static Future<void> syncOwnerPublicLocale(AppUserModel user) async {
    await _db
        .from('digital_profiles')
        .update({
          'public_locale': user.localeConfig.localeCode,
          'updated_at': nowIso(),
        })
        .eq('owner_user_id', user.id);
  }

  static Future<List<DigitalProfileModel>> fetchProfilesForUser(
    String userId,
  ) async {
    final rows = await _db
        .from('digital_profiles')
        .select(_selectFull)
        .eq('owner_user_id', userId)
        .neq('status', 'deleted')
        .order('created_at');
    final profiles = (rows as List)
        .map((e) => DigitalProfileModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return Future.wait(profiles.map(_withOrganizationBranding));
  }

  static Future<List<DigitalProfileModel>> fetchProfilesForOrg(
    String orgId,
  ) async {
    final org = await OrganizationRepository.fetchById(orgId);
    final rows = await _db
        .from('digital_profiles')
        .select(_selectFull)
        .eq('org_id', orgId)
        .neq('status', 'deleted')
        .order('created_at');
    return (rows as List)
        .map(
          (e) => _applyOrganizationBranding(
            DigitalProfileModel.fromJson(Map<String, dynamic>.from(e)),
            org,
          ),
        )
        .toList();
  }

  static Future<DigitalProfileModel?> fetchProfileById(String id) async {
    final row = await _db
        .from('digital_profiles')
        .select(_selectFull)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _withOrganizationBranding(
      DigitalProfileModel.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  static Future<DigitalProfileModel?> fetchProfileBySlug(String slug) async {
    final row = await _db
        .from('digital_profiles')
        .select(_selectFull)
        .eq('public_slug', slug)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) return null;
    return _withOrganizationBranding(
      DigitalProfileModel.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  static Future<DigitalProfileModel> _withOrganizationBranding(
    DigitalProfileModel profile,
  ) async {
    final orgId = profile.orgId;
    if (orgId == null || orgId.isEmpty) return profile;
    final org = await OrganizationRepository.fetchById(orgId);
    return _applyOrganizationBranding(profile, org);
  }

  static DigitalProfileModel _applyOrganizationBranding(
    DigitalProfileModel profile,
    OrganizationModel? org,
  ) {
    if (org == null) return profile;
    final companyLogoUrl = org.logoUrl?.trim();
    final hasCompanyLogo = companyLogoUrl != null && companyLogoUrl.isNotEmpty;
    final teamTheme = org.teamProfileTheme;
    return profile.copyWith(
      logoUrl: hasCompanyLogo ? companyLogoUrl : null,
      clearLogoUrl: !hasCompanyLogo,
      coverPhotoUrl: org.enforceTeamProfileTheme
          ? org.teamProfileCoverPhotoUrl ?? profile.coverPhotoUrl
          : profile.coverPhotoUrl,
      theme: org.enforceTeamProfileTheme
          ? teamTheme == null
                ? profile.theme
                : _themeForProfile(teamTheme, profile.id)
          : profile.theme,
    );
  }

  static Future<TaploePlanCapabilities> fetchCapabilitiesForProfile(
    DigitalProfileModel profile,
  ) async {
    final results = await Future.wait<Object?>([
      UserRepository.fetchById(profile.ownerUserId),
      profile.orgId == null || profile.orgId!.isEmpty
          ? Future<OrganizationModel?>.value(null)
          : OrganizationRepository.fetchById(profile.orgId!),
      BillingRepository.fetchUserSubscription(profile.ownerUserId),
      profile.orgId == null || profile.orgId!.isEmpty
          ? Future<BillingSubscriptionModel?>.value(null)
          : BillingRepository.fetchOrganizationSubscription(profile.orgId!),
    ]);
    return taploeCapabilitiesFor(
      user: results[0] as AppUserModel?,
      organization: results[1] as OrganizationModel?,
      userSubscription: results[2] as BillingSubscriptionModel?,
      organizationSubscription: results[3] as BillingSubscriptionModel?,
    );
  }

  static ProfileThemeModel _themeForProfile(
    ProfileThemeModel theme,
    String profileId,
  ) => ProfileThemeModel(
    id: theme.id,
    profileId: profileId,
    themeStyle: theme.themeStyle,
    layoutStyle: theme.layoutStyle,
    primaryColor: theme.primaryColor,
    secondaryColor: theme.secondaryColor,
    accentColor: theme.accentColor,
    backgroundType: theme.backgroundType,
    backgroundColorStart: theme.backgroundColorStart,
    backgroundColorEnd: theme.backgroundColorEnd,
    backgroundImageUrl: theme.backgroundImageUrl,
    buttonStyle: theme.buttonStyle,
    fontFamily: theme.fontFamily,
  );

  static Future<DigitalProfileModel> createProfileForUser(
    AppUserModel user, {
    String? displayName,
    String? publicSlug,
  }) async {
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : (user.username.isNotEmpty
              ? user.username
              : user.email.split('@').first);
    final requestedSlug = publicSlug == null
        ? null
        : normalizePublicSlug(publicSlug);
    if (requestedSlug != null && requestedSlug.length < 3) {
      throw ArgumentError('profile_slug_too_short');
    }
    if (requestedSlug != null && await slugExists(requestedSlug)) {
      throw ArgumentError('profile_slug_taken');
    }
    final slug = requestedSlug ?? await generateUniqueSlug(name);
    final existingProfiles = await fetchProfilesForUser(user.id);
    final org = await UserRepository.firstOrganizationForUser(user.id);
    final userSubscription = await BillingRepository.fetchUserSubscription(
      user.id,
    );
    final organizationSubscription = org == null
        ? null
        : await BillingRepository.fetchOrganizationSubscription(org.id);
    final capabilities = taploeCapabilitiesFor(
      user: user,
      organization: org,
      userSubscription: userSubscription,
      organizationSubscription: organizationSubscription,
    );
    if (!capabilities.canCreateProfile(existingProfiles.length)) {
      throw ArgumentError('profile_limit_reached');
    }
    final count = existingProfiles.length + 1;

    final row = await _db
        .from('digital_profiles')
        .insert({
          'owner_user_id': user.id,
          'display_name': name,
          'profile_name': count == 1 ? 'Perfil principal' : 'Perfil $count',
          'public_slug': slug,
          'public_locale': user.localeConfig.localeCode,
          'status': 'active',
          'visibility': 'public',
          'is_default': count == 1,
        })
        .select()
        .single();

    final profile = DigitalProfileModel.fromJson(
      Map<String, dynamic>.from(row),
    );
    await ensureInitialRecords(profile, user);
    return (await fetchProfileById(profile.id)) ?? profile;
  }

  static Future<DigitalProfileModel> updateProfile(
    DigitalProfileModel profile,
  ) async {
    await _db
        .from('digital_profiles')
        .update(profile.toUpdate())
        .eq('id', profile.id);

    if (profile.theme != null && profile.theme!.profileId.isNotEmpty) {
      await _db
          .from('profile_theme_settings')
          .upsert(profile.theme!.toJson(), onConflict: 'profile_id');
    }
    if (profile.vcard != null && profile.vcard!.profileId.isNotEmpty) {
      await _db
          .from('profile_vcard_details')
          .upsert(profile.vcard!.toJson(), onConflict: 'profile_id');
    }

    return (await fetchProfileById(profile.id))!;
  }

  static Future<DigitalProfileModel> updateVerifiedBadge({
    required DigitalProfileModel profile,
    required bool value,
  }) async {
    await _db
        .from('digital_profiles')
        .update({'show_verified_badge': value, 'updated_at': nowIso()})
        .eq('id', profile.id);

    return (await fetchProfileById(profile.id))!;
  }

  static Future<ProfileLinkModel> addLink({
    required String profileId,
    required String linkType,
    required String label,
    String? value,
    String? url,
    String? iconKey,
    bool isVisible = true,
    bool isFeatured = false,
    String openMode = 'external',
    Map<String, dynamic> metadata = const {},
    int sortOrder = 0,
  }) async {
    final existing = await _db
        .from('profile_links')
        .select('id')
        .eq('profile_id', profileId)
        .limit(taploeMaxProfileLinks);
    if (existing.length >= taploeMaxProfileLinks) {
      throw ArgumentError('profile_link_limit_reached');
    }

    final row = await _db
        .from('profile_links')
        .insert({
          'profile_id': profileId,
          'link_type': linkType,
          'label': label,
          'value': value,
          'url': url,
          'icon_key': iconKey,
          'is_visible': isVisible,
          'is_featured': isFeatured,
          'sort_order': sortOrder,
          'open_mode': openMode,
          'metadata': metadata,
        })
        .select()
        .single();
    return ProfileLinkModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<ProfileLinkModel> updateLink(ProfileLinkModel link) async {
    final row = await _db
        .from('profile_links')
        .update(link.toJson())
        .eq('id', link.id)
        .select()
        .single();
    return ProfileLinkModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<void> deleteLink(String id) async {
    await _db.from('profile_links').delete().eq('id', id);
  }
}

class AccessPointRepository {
  static Future<ProfileAccessPointModel?> fetchByToken(String token) async {
    debugPrint(
      '[TaploeCardLink] Buscando profile_access_points token="$token"',
    );
    final row = await _db
        .from('profile_access_points')
        .select()
        .eq('token', token)
        .maybeSingle();
    debugPrint('[TaploeCardLink] Access point encontrado: ${row != null}');
    if (row == null) return null;
    return ProfileAccessPointModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<List<ProfileAccessPointModel>> fetchAccessPointsForCard(
    String physicalCardId,
  ) async {
    final rows = await _db
        .from('profile_access_points')
        .select()
        .eq('physical_card_id', physicalCardId)
        .order('channel');
    return (rows as List)
        .map(
          (e) => ProfileAccessPointModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  static Future<List<ProfileAccessPointModel>> fetchAccessPointsForProfile(
    String profileId,
  ) async {
    final rows = await _db
        .from('profile_access_points')
        .select()
        .eq('profile_id', profileId)
        .eq('is_active', true)
        .order('channel');
    return (rows as List)
        .map(
          (e) => ProfileAccessPointModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }
}

class CardRepository {
  static Future<ProfileAccessPointModel?> fetchAccessPoint(String token) {
    return AccessPointRepository.fetchByToken(token);
  }

  static Future<List<PhysicalCardModel>> fetchCardsForUser(
    String userId,
  ) async {
    final rows = await _db
        .from('physical_cards')
        .select('*, product_types(name, code)')
        .eq('owner_user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => PhysicalCardModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<PhysicalCardModel>> fetchCardsForProfile(
    String profileId,
  ) async {
    final rows = await _db
        .from('physical_cards')
        .select('*, product_types(name, code)')
        .eq('active_profile_id', profileId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => PhysicalCardModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<ProfileAccessPointModel>> fetchAccessPointsForCard(
    String physicalCardId,
  ) {
    return AccessPointRepository.fetchAccessPointsForCard(physicalCardId);
  }

  static Future<List<ProfileAccessPointModel>> fetchAccessPointsForProfile(
    String profileId,
  ) {
    return AccessPointRepository.fetchAccessPointsForProfile(profileId);
  }

  static Future<PhysicalCardModel> fetchCardById(String id) async {
    final row = await _db
        .from('physical_cards')
        .select('*, product_types(name, code)')
        .eq('id', id)
        .single();
    return PhysicalCardModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<void> changeActiveProfile({
    required PhysicalCardModel card,
    required DigitalProfileModel profile,
    required String userId,
  }) async {
    if (card.ownerUserId != userId || profile.ownerUserId != userId) {
      throw StateError(
        'La tarjeta solo puede vincularse a un perfil del mismo usuario.',
      );
    }

    try {
      debugPrint('[TaploeCards] Calling change_card_active_profile ${card.id}');
      await _db.rpc(
        'change_card_active_profile',
        params: {'p_card_id': card.id, 'p_profile_id': profile.id},
      );
    } catch (error) {
      throw StateError('change_card_active_profile rpc failed: $error');
    }
  }
}

class CardActivationService {
  static String? pendingActivationToken;

  static Future<void> savePendingActivation(String token) async {
    pendingActivationToken = token;
    await SessionStorage.savePendingActivationToken(token);
  }

  static Future<String?> getPendingActivation() async {
    pendingActivationToken ??= await SessionStorage.getPendingActivationToken();
    return pendingActivationToken;
  }

  static Future<void> clearPendingActivation() async {
    pendingActivationToken = null;
    await SessionStorage.clearPendingActivationToken();
  }

  static Future<AccessResolutionModel> resolveAccessToken(String token) async {
    final accessPoint = await AccessPointRepository.fetchByToken(token);
    if (accessPoint == null) {
      return const AccessResolutionModel(
        action: AccessResolutionAction.notFound,
      );
    }

    PhysicalCardModel? card;
    DigitalProfileModel? profile;

    if (accessPoint.physicalCardId != null) {
      try {
        card = await CardRepository.fetchCardById(accessPoint.physicalCardId!);
      } catch (error) {
        debugPrint(
          '[TaploeCardLink] No se pudo leer physical_cards '
          '${accessPoint.physicalCardId}: $error',
        );
        card = null;
      }
    }

    if (!accessPoint.isActive || accessPoint.targetType == 'disabled') {
      return AccessResolutionModel(
        accessPoint: accessPoint,
        physicalCard: card,
        action: AccessResolutionAction.disabled,
      );
    }

    if (accessPoint.targetType == 'activation') {
      return AccessResolutionModel(
        accessPoint: accessPoint,
        physicalCard: card,
        requiresAuth: _db.auth.currentUser == null,
        action: AccessResolutionAction.activate,
      );
    }

    if (accessPoint.targetType == 'external_url') {
      return AccessResolutionModel(
        accessPoint: accessPoint,
        physicalCard: card,
        action: AccessResolutionAction.redirectExternal,
      );
    }

    if (accessPoint.targetType == 'profile' && accessPoint.profileId != null) {
      profile = await ProfileRepository.fetchProfileById(
        accessPoint.profileId!,
      );
      if (profile == null) {
        return AccessResolutionModel(
          accessPoint: accessPoint,
          physicalCard: card,
          action: AccessResolutionAction.notFound,
        );
      }
      return AccessResolutionModel(
        accessPoint: accessPoint,
        physicalCard: card,
        profile: profile,
        action: AccessResolutionAction.openProfile,
      );
    }

    return AccessResolutionModel(
      accessPoint: accessPoint,
      physicalCard: card,
      action: AccessResolutionAction.notFound,
    );
  }

  static Future<ActivationResultModel> activateCardByToken({
    required String token,
    String? profileId,
  }) async {
    debugPrint(
      '[TaploeCardLink] Activando tarjeta directamente en Supabase '
      'profileId="${profileId ?? 'client-created'}"',
    );

    if (await UserRepository.verifiedAuthUser() == null) {
      throw Exception(
        'No pudimos validar tu sesión. Vuelve a iniciar sesión e intenta de nuevo.',
      );
    }

    final user = await UserRepository.currentAppUser();
    if (user == null) {
      throw Exception(
        'No pudimos validar tu sesión. Vuelve a iniciar sesión e intenta de nuevo.',
      );
    }

    final accessPoint = await AccessPointRepository.fetchByToken(token);
    if (accessPoint == null ||
        !accessPoint.isActive ||
        accessPoint.targetType != 'activation' ||
        accessPoint.physicalCardId == null) {
      throw Exception('Esta tarjeta no está disponible para vincular.');
    }

    late final PhysicalCardModel card;
    try {
      card = await CardRepository.fetchCardById(accessPoint.physicalCardId!);
    } catch (error) {
      debugPrint(
        '[TaploeCardLink] No se pudo leer physical_cards '
        '${accessPoint.physicalCardId}: $error',
      );
      throw Exception('Esta tarjeta no está disponible para vincular.');
    }
    if (card.status == 'disabled' ||
        card.status == 'lost' ||
        card.status == 'replaced') {
      throw Exception('Esta tarjeta no está disponible para vincular.');
    }
    if (card.ownerUserId == user.id) {
      throw Exception('Esta tarjeta ya está vinculada a tu cuenta.');
    }
    if (card.status == 'claimed' ||
        card.ownerUserId != null ||
        card.activeProfileId != null) {
      throw Exception('Esta tarjeta ya fue vinculada a otra cuenta.');
    }

    final profile = profileId == null
        ? await ProfileRepository.createProfileForUser(
            user,
            displayName: card.printedName,
          )
        : await ProfileRepository.fetchProfileById(profileId);

    if (profile == null || profile.ownerUserId != user.id) {
      throw Exception('No pudimos preparar tu perfil. Intenta de nuevo.');
    }

    final now = nowIso();

    try {
      final updatedCardRow = await _db
          .from('physical_cards')
          .update({
            'owner_user_id': user.id,
            'active_profile_id': profile.id,
            'status': 'claimed',
            'claimed_at': now,
            'activation_completed_at': now,
            'updated_at': now,
          })
          .eq('id', card.id)
          .filter('owner_user_id', 'is', null)
          .filter('active_profile_id', 'is', null)
          .filter('status', 'not.in', '(claimed,disabled,lost,replaced)')
          .select('id')
          .maybeSingle();

      if (updatedCardRow == null) {
        throw Exception('Esta tarjeta ya fue vinculada a otra cuenta.');
      }

      await _db
          .from('profile_access_points')
          .update({
            'profile_id': profile.id,
            'target_type': 'profile',
            'updated_at': now,
          })
          .eq('physical_card_id', card.id);

      await _saveActivationHistory(
        card: card,
        profile: profile,
        user: user,
        accessPoint: accessPoint,
      );

      return ActivationResultModel(
        success: true,
        profileId: profile.id,
        physicalCardId: card.id,
        publicSlug: profile.publicSlug,
        channel: accessPoint.channel,
        message: 'Tarjeta vinculada',
      );
    } catch (error) {
      debugPrint(
        '[TaploeCardLink] No se pudo activar directamente en Supabase. '
        'Revisa policies de physical_cards, profile_access_points, '
        'physical_card_assignments y analytics_events.',
      );
      safePrintError(error);
      rethrow;
    }
  }

  static Future<void> _saveActivationHistory({
    required PhysicalCardModel card,
    required DigitalProfileModel profile,
    required AppUserModel user,
    required ProfileAccessPointModel accessPoint,
  }) async {
    try {
      await _db.from('physical_card_assignments').insert({
        'physical_card_id': card.id,
        'user_id': user.id,
        'from_profile_id': null,
        'to_profile_id': profile.id,
        'action_type': 'claimed',
        'reason': 'qr_activation',
        'created_by_user_id': user.id,
        'metadata': {
          'channel': accessPoint.channel,
          'access_point_id': accessPoint.id,
        },
      });
    } catch (error) {
      debugPrint(
        '[TaploeCardLink] La tarjeta fue vinculada, pero no se pudo guardar '
        'physical_card_assignments.',
      );
      safePrintError(error);
    }

    try {
      await _db.from('analytics_events').insert({
        'profile_id': profile.id,
        'physical_card_id': card.id,
        'access_point_id': accessPoint.id,
        'event_type': 'card_claimed',
        'access_channel': accessPoint.channel,
        'metadata': {'source': 'dashboard_qr_scan'},
      });
    } catch (error) {
      debugPrint(
        '[TaploeCardLink] La tarjeta fue vinculada, pero no se pudo guardar '
        'analytics_events.',
      );
      safePrintError(error);
    }
  }

  static Future<void> handlePostLoginPendingActivation() async {
    final token = await getPendingActivation();
    if (token == null || token.isEmpty) return;
    await savePendingActivation(token);
  }
}

class AnalyticsRepository {
  static Future<void> insertEvent({
    String? profileId,
    String? physicalCardId,
    String? accessPointId,
    String? linkId,
    String? formId,
    String? formSubmissionId,
    String? leadId,
    required String eventType,
    required String channel,
    Map<String, dynamic>? metadata,
  }) async {
    final attribution = await SessionStorage.getVisitorAttribution();
    final visitorId = attribution['visitorSessionId'];
    final resolvedLeadId =
        leadId ??
        await _resolveLeadIdForVisitor(
          profileId: profileId,
          visitorId: visitorId,
        );
    final location = await DeviceLocationService.snapshot();
    final enrichedMetadata = <String, dynamic>{
      ...?metadata,
      if (location?.hasLocation == true)
        'device_location': location!.toMetadata(),
    };
    final payload = <String, dynamic>{
      'profile_id': profileId,
      'physical_card_id': physicalCardId,
      'access_point_id': accessPointId,
      'link_id': linkId,
      'form_id': formId,
      'form_submission_id': formSubmissionId,
      'lead_id': resolvedLeadId,
      'event_type': eventType,
      'access_channel': channel,
      'visitor_id': visitorId,
      'session_id': visitorId,
      if (location?.city?.isNotEmpty == true) 'city': location!.city,
      if (location?.region?.isNotEmpty == true) 'region': location!.region,
      if (location?.country?.isNotEmpty == true) 'country': location!.country,
      if (location?.latitude != null) 'latitude': location!.latitude,
      if (location?.longitude != null) 'longitude': location!.longitude,
      if (location?.accuracy != null)
        'location_accuracy_meters': location!.accuracy,
      'metadata': enrichedMetadata,
      'occurred_at': nowIso(),
    };
    await _db.from('analytics_events').insert(payload);
  }

  static Future<String?> _resolveLeadIdForVisitor({
    required String? profileId,
    required String? visitorId,
  }) async {
    if (profileId == null || visitorId == null || visitorId.isEmpty) {
      return null;
    }
    try {
      final value = await _db.rpc(
        'resolve_lead_id_for_visitor',
        params: {'p_profile_id': profileId, 'p_visitor_id': visitorId},
      );
      final text = value?.toString();
      return text == null || text.isEmpty ? null : text;
    } catch (error) {
      debugPrint('[TaploeAnalytics] No se pudo resolver lead del visitante.');
      safePrintError(error);
      return null;
    }
  }

  static Future<void> recordProfileViewFromAccessPoint(
    ProfileAccessPointModel accessPoint,
  ) async {
    await SessionStorage.saveVisitorAttribution(
      accessPointId: accessPoint.id,
      physicalCardId: accessPoint.physicalCardId,
      channel: accessPoint.channel,
      profileId: accessPoint.profileId,
    );

    await insertEvent(
      profileId: accessPoint.profileId,
      physicalCardId: accessPoint.physicalCardId,
      accessPointId: accessPoint.id,
      eventType: 'profile_view',
      channel: accessPoint.channel,
      metadata: {'source': 'access_resolver'},
    );
  }

  static Future<void> recordCardClaimed({
    required String profileId,
    required String physicalCardId,
    required String accessPointId,
    required String channel,
  }) {
    return insertEvent(
      profileId: profileId,
      physicalCardId: physicalCardId,
      accessPointId: accessPointId,
      eventType: 'card_claimed',
      channel: channel,
      metadata: {'activation_mode': 'token'},
    );
  }

  static Future<void> recordLinkClick({
    required String profileId,
    String? accessPointId,
    String? linkId,
    required String channel,
    Map<String, dynamic>? metadata,
  }) {
    return insertEvent(
      profileId: profileId,
      accessPointId: accessPointId,
      linkId: linkId,
      eventType: 'link_click',
      channel: channel,
      metadata: metadata,
    );
  }

  static Future<void> recordContactSave({
    required String profileId,
    String? accessPointId,
    required String channel,
  }) {
    return insertEvent(
      profileId: profileId,
      accessPointId: accessPointId,
      eventType: 'contact_save',
      channel: channel,
    );
  }

  static Future<AnalyticsSummaryModel> fetchSummary(String profileId) async {
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();
    final rows = await _db
        .from('analytics_events')
        .select('*, profile_links(label)')
        .eq('profile_id', profileId)
        .gte('occurred_at', since)
        .order('occurred_at');

    int views = 0,
        nfc = 0,
        qr = 0,
        direct = 0,
        clicks = 0,
        saves = 0,
        forms = 0;
    final byDay = List<int>.filled(7, 0);
    final clickLabels = <String, int>{};
    final now = DateTime.now();

    for (final raw in rows as List) {
      final e = Map<String, dynamic>.from(raw as Map);
      final type = e['event_type'] as String? ?? '';
      final channel = e['access_channel'] as String? ?? 'direct';
      final occurred = DateTime.tryParse('${e['occurred_at']}')?.toLocal();

      if (type == 'profile_view') {
        views++;
        if (channel == 'nfc') nfc++;
        if (channel == 'qr') qr++;
        if (channel == 'direct') direct++;
        if (occurred != null) {
          final diff = now.difference(occurred).inDays;
          if (diff >= 0 && diff < 7) byDay[6 - diff]++;
        }
      }
      if (type == 'link_click' || type == 'calendar_click') {
        clicks++;
        final link = e['profile_links'];
        final label = link is Map ? '${link['label'] ?? 'Link'}' : 'Link';
        clickLabels[label] = (clickLabels[label] ?? 0) + 1;
      }
      if (type == 'contact_save') saves++;
      if (type == 'form_submit') forms++;
    }

    return AnalyticsSummaryModel(
      profileViews: views,
      nfcViews: nfc,
      qrViews: qr,
      directViews: direct,
      linkClicks: clicks,
      contactsSaved: saves,
      formSubmits: forms,
      viewsByDay: byDay,
      clicksByLabel: clickLabels,
    );
  }

  static Future<AnalyticsSummaryModel> fetchSummaryForProfiles(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty) {
      return const AnalyticsSummaryModel(
        profileViews: 0,
        nfcViews: 0,
        qrViews: 0,
        directViews: 0,
        linkClicks: 0,
        contactsSaved: 0,
        formSubmits: 0,
        viewsByDay: [0, 0, 0, 0, 0, 0, 0],
        clicksByLabel: {},
      );
    }

    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();
    final rows = await _db
        .from('analytics_events')
        .select('*, profile_links(label)')
        .inFilter('profile_id', profileIds)
        .gte('occurred_at', since)
        .order('occurred_at');

    return _summaryFromRows(rows as List);
  }

  static AnalyticsSummaryModel _summaryFromRows(List rows) {
    int views = 0,
        nfc = 0,
        qr = 0,
        direct = 0,
        clicks = 0,
        saves = 0,
        forms = 0;
    final byDay = List<int>.filled(7, 0);
    final clickLabels = <String, int>{};
    final now = DateTime.now();

    for (final raw in rows) {
      final e = Map<String, dynamic>.from(raw as Map);
      final type = e['event_type'] as String? ?? '';
      final channel = e['access_channel'] as String? ?? 'direct';
      final occurred = DateTime.tryParse('${e['occurred_at']}')?.toLocal();

      if (type == 'profile_view') {
        views++;
        if (channel == 'nfc') nfc++;
        if (channel == 'qr') qr++;
        if (channel == 'direct') direct++;
        if (occurred != null) {
          final diff = now.difference(occurred).inDays;
          if (diff >= 0 && diff < 7) byDay[6 - diff]++;
        }
      }
      if (type == 'link_click' || type == 'calendar_click') {
        clicks++;
        final link = e['profile_links'];
        final label = link is Map ? '${link['label'] ?? 'Link'}' : 'Link';
        clickLabels[label] = (clickLabels[label] ?? 0) + 1;
      }
      if (type == 'contact_save') saves++;
      if (type == 'form_submit') forms++;
    }

    return AnalyticsSummaryModel(
      profileViews: views,
      nfcViews: nfc,
      qrViews: qr,
      directViews: direct,
      linkClicks: clicks,
      contactsSaved: saves,
      formSubmits: forms,
      viewsByDay: byDay,
      clicksByLabel: clickLabels,
    );
  }

  static Future<List<AnalyticsEventModel>> fetchRecentEvents(
    String profileId, {
    int limit = 8,
  }) async {
    final queryLimit = limit < 20 ? 40 : limit * 2;
    final rows = await _db
        .from('analytics_events')
        .select(
          'id,lead_id,link_id,form_id,form_submission_id,event_type,access_channel,city,region,country,metadata,occurred_at,profile_links(label)',
        )
        .eq('profile_id', profileId)
        .order('occurred_at', ascending: false)
        .limit(queryLimit);
    return (rows as List)
        .map((e) => AnalyticsEventModel.fromJson(Map<String, dynamic>.from(e)))
        .where((event) => !_isLegacyProfileInstallEvent(event.eventType))
        .take(limit)
        .toList();
  }

  static Future<List<AnalyticsEventModel>> fetchRecentEventsForProfiles(
    List<String> profileIds, {
    int limit = 8,
  }) async {
    if (profileIds.isEmpty) return const [];
    final queryLimit = limit < 20 ? 40 : limit * 2;
    final rows = await _db
        .from('analytics_events')
        .select(
          'id,lead_id,link_id,form_id,form_submission_id,event_type,access_channel,city,region,country,metadata,occurred_at,profile_links(label)',
        )
        .inFilter('profile_id', profileIds)
        .order('occurred_at', ascending: false)
        .limit(queryLimit);
    return (rows as List)
        .map((e) => AnalyticsEventModel.fromJson(Map<String, dynamic>.from(e)))
        .where((event) => !_isLegacyProfileInstallEvent(event.eventType))
        .take(limit)
        .toList();
  }

  static Future<List<AnalyticsEventModel>> fetchEventsForProfile(
    String profileId, {
    int limit = 80,
  }) async {
    final rows = await _db
        .from('analytics_events')
        .select(
          'id,event_type,access_channel,city,region,country,metadata,occurred_at',
        )
        .eq('profile_id', profileId)
        .order('occurred_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => AnalyticsEventModel.fromJson(Map<String, dynamic>.from(e)))
        .where((event) => !_isLegacyProfileInstallEvent(event.eventType))
        .toList();
  }

  static Future<List<AnalyticsEventModel>> fetchTimelineForLead(
    String leadId, {
    int limit = 80,
  }) async {
    final rows = await _db
        .from('analytics_events')
        .select(
          'id,lead_id,link_id,form_id,form_submission_id,event_type,access_channel,city,region,country,metadata,occurred_at,profile_links(label)',
        )
        .eq('lead_id', leadId)
        .order('occurred_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .map((e) => AnalyticsEventModel.fromJson(Map<String, dynamic>.from(e)))
        .where((event) => !_isLegacyProfileInstallEvent(event.eventType))
        .toList();
  }

  static bool _isLegacyProfileInstallEvent(String type) {
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

  static Future<void> attachVisitorEventsToLead({
    required String profileId,
    required String leadId,
  }) async {
    final attribution = await SessionStorage.getVisitorAttribution();
    final visitorId = attribution['visitorSessionId'];
    if (visitorId == null || visitorId.isEmpty) return;

    try {
      await _db.rpc(
        'attach_visitor_events_to_lead',
        params: {
          'p_profile_id': profileId,
          'p_lead_id': leadId,
          'p_visitor_id': visitorId,
        },
      );
    } catch (error) {
      debugPrint('[TaploeAnalytics] No se pudo enlazar timeline al lead.');
      safePrintError(error);
    }
  }
}

class LeadRepository {
  static Future<List<LeadModel>> fetchForProfile(String profileId) async {
    final rows = await _db
        .from('leads')
        .select()
        .eq('profile_id', profileId)
        .order('last_seen_at', ascending: false);
    return (rows as List)
        .map((e) => LeadModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<LeadModel>> fetchForProfiles(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty) return const [];
    final rows = await _db
        .from('leads')
        .select()
        .inFilter('profile_id', profileIds)
        .order('last_seen_at', ascending: false);
    return (rows as List)
        .map((e) => LeadModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<LeadModel> upsertLeadFromForm({
    required DigitalProfileModel profile,
    required Map<String, dynamic> data,
    required String channel,
  }) async {
    final email = (data['email'] ?? data['correo'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final phone = (data['phone'] ?? data['telefono'] ?? '').toString().trim();
    final name = (data['name'] ?? data['nombre'] ?? data['full_name'] ?? '')
        .toString()
        .trim();

    Map<String, dynamic>? existing;
    if (email.isNotEmpty) {
      existing = await _db
          .from('leads')
          .select()
          .eq('profile_id', profile.id)
          .eq('email', email)
          .maybeSingle();
    }

    if (existing != null) {
      final row = await _db
          .from('leads')
          .update({
            'full_name': name.isNotEmpty ? name : existing['full_name'],
            'phone': phone.isNotEmpty ? phone : existing['phone'],
            'company':
                data['company'] ?? data['empresa'] ?? existing['company'],
            'last_seen_at': nowIso(),
            'score': (existing['score'] as num? ?? 0).toInt() + 70,
            'updated_at': nowIso(),
          })
          .eq('id', existing['id'])
          .select()
          .single();
      return LeadModel.fromJson(Map<String, dynamic>.from(row));
    }

    final row = await _db
        .from('leads')
        .insert({
          'profile_id': profile.id,
          'org_id': profile.orgId,
          'owner_user_id': profile.ownerUserId,
          'full_name': name.isNotEmpty ? name : null,
          'email': email.isNotEmpty ? email : null,
          'phone': phone.isNotEmpty ? phone : null,
          'company': data['company'] ?? data['empresa'],
          'status': 'new',
          'score': 70,
          'source_channel': channel,
          'first_seen_at': nowIso(),
          'last_seen_at': nowIso(),
          'metadata': {'source': 'smart_form'},
        })
        .select()
        .single();
    final lead = LeadModel.fromJson(Map<String, dynamic>.from(row));
    await _createLeadNotification(profile: profile, lead: lead);
    return lead;
  }

  static Future<void> _createLeadNotification({
    required DigitalProfileModel profile,
    required LeadModel lead,
  }) async {
    if (profile.ownerUserId.isEmpty) return;
    final leadName = lead.displayName.trim();
    try {
      await _db.from('app_notifications').insert({
        'user_id': profile.ownerUserId,
        'profile_id': profile.id,
        'lead_id': lead.id,
        'notification_type': 'lead_created',
        'title': 'Nuevo lead',
        'body': leadName.isEmpty
            ? 'Recibiste un nuevo lead desde tu perfil.'
            : '$leadName dejó sus datos en tu perfil.',
        'action_url': '/leads',
        'metadata': {
          'source_channel': lead.sourceChannel,
          'profile_name': profile.displayName,
        },
      });
    } catch (error) {
      debugPrint('[TaploeNotifications] No se pudo crear aviso de lead.');
      safePrintError(error);
    }
  }

  static Future<void> updateStatus(String leadId, String status) async {
    await _db
        .from('leads')
        .update({'status': status, 'updated_at': nowIso()})
        .eq('id', leadId);
  }

  static Future<void> deleteLead(String leadId) async {
    await _db.rpc(
      'delete_lead_for_current_user',
      params: {'p_lead_id': leadId},
    );
  }

  static Future<List<LeadEventModel>> fetchEvents(String leadId) async {
    final rows = await _db
        .from('lead_events')
        .select()
        .eq('lead_id', leadId)
        .order('occurred_at', ascending: false);
    return (rows as List)
        .map((e) => LeadEventModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<FormSubmissionModel>> fetchSubmissions(
    String leadId,
  ) async {
    final rows = await _db
        .from('form_submissions')
        .select()
        .eq('lead_id', leadId)
        .order('submitted_at', ascending: false);
    return (rows as List)
        .map((e) => FormSubmissionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<FormSubmissionModel?> fetchSubmissionById(String id) async {
    final row = await _db
        .from('form_submissions')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null
        ? null
        : FormSubmissionModel.fromJson(Map<String, dynamic>.from(row));
  }
}

class SmartFormRepository {
  static Future<List<SmartFormModel>> fetchActiveForms(String profileId) async {
    final rows = await _db
        .from('smart_forms')
        .select()
        .eq('profile_id', profileId)
        .eq('is_active', true)
        .order('created_at');
    return (rows as List)
        .map((e) => SmartFormModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<SmartFormModel>> fetchForms(String profileId) async {
    final rows = await _db
        .from('smart_forms')
        .select()
        .eq('profile_id', profileId)
        .order('created_at');
    return (rows as List)
        .map((e) => SmartFormModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<SmartFormModel> upsertForm({
    String? id,
    required String profileId,
    required String formKey,
    required String name,
    String? description,
    bool isActive = true,
    String? successMessage,
    List<String> notifyEmails = const [],
  }) async {
    final payload = {
      'profile_id': profileId,
      'form_key': formKey,
      'name': name,
      'description': description,
      'is_active': isActive,
      'success_message': successMessage,
      'notify_emails': notifyEmails,
      'updated_at': nowIso(),
    };
    final row = id == null
        ? await _db.from('smart_forms').insert(payload).select().single()
        : await _db
              .from('smart_forms')
              .update(payload)
              .eq('id', id)
              .select()
              .single();
    return SmartFormModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<List<SmartFormFieldModel>> fetchFields(String formId) async {
    final rows = await _db
        .from('smart_form_fields')
        .select()
        .eq('form_id', formId)
        .order('sort_order');
    return (rows as List)
        .map((e) => SmartFormFieldModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<SmartFormFieldModel> upsertField({
    String? id,
    required String formId,
    required String fieldKey,
    required String fieldType,
    required String label,
    String? placeholder,
    String? helpText,
    bool isRequired = false,
    int sortOrder = 0,
  }) async {
    final payload = {
      'form_id': formId,
      'field_key': fieldKey,
      'field_type': fieldType,
      'label': label,
      'placeholder': placeholder,
      'help_text': helpText,
      'is_required': isRequired,
      'sort_order': sortOrder,
      'validation_rules': <String, dynamic>{},
    };
    final row = id == null
        ? await _db.from('smart_form_fields').insert(payload).select().single()
        : await _db
              .from('smart_form_fields')
              .update(payload)
              .eq('id', id)
              .select()
              .single();
    return SmartFormFieldModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<void> deleteField(String id) async {
    await _db.from('smart_form_fields').delete().eq('id', id);
  }

  static Future<void> submit({
    required SmartFormModel form,
    required DigitalProfileModel profile,
    required Map<String, dynamic> data,
    String? accessPointId,
    String channel = 'direct',
  }) async {
    final lead = await LeadRepository.upsertLeadFromForm(
      profile: profile,
      data: data,
      channel: channel,
    );
    await AnalyticsRepository.attachVisitorEventsToLead(
      profileId: profile.id,
      leadId: lead.id,
    );

    final submission = await _db
        .from('form_submissions')
        .insert({
          'form_id': form.id,
          'profile_id': profile.id,
          'lead_id': lead.id,
          'access_point_id': accessPointId,
          'data': data,
          'submitted_at': nowIso(),
        })
        .select()
        .single();

    await _db.from('lead_events').insert({
      'lead_id': lead.id,
      'profile_id': profile.id,
      'event_type': 'form_submit',
      'points': 70,
      'metadata': {'form_key': form.formKey},
      'occurred_at': nowIso(),
    });

    await AnalyticsRepository.insertEvent(
      profileId: profile.id,
      accessPointId: accessPointId,
      formId: form.id,
      formSubmissionId: submission['id'] as String?,
      leadId: lead.id,
      eventType: 'form_submit',
      channel: channel,
    );
  }
}

class IntegrationRepository {
  static Future<List<ProfileIntegrationModel>> fetchForProfile({
    required String profileId,
  }) async {
    final rows = await _db
        .from('profile_integrations')
        .select('*, user_integrations(*)')
        .eq('profile_id', profileId)
        .order('sort_order');
    return (rows as List)
        .map(
          (e) => ProfileIntegrationModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  static Future<ProfileIntegrationModel> upsertProfileIntegration({
    String? profileIntegrationId,
    String? integrationId,
    required String userId,
    required String profileId,
    required String integrationType,
    required String provider,
    required String publicUrl,
    required String displayLabel,
    bool isEnabled = true,
    int sortOrder = 0,
  }) async {
    final integrationPayload = {
      'user_id': userId,
      'integration_type': integrationType,
      'provider': provider,
      'public_url': publicUrl,
      'status': isEnabled ? 'active' : 'inactive',
      'updated_at': nowIso(),
    };

    final integrationRow = integrationId == null
        ? await _db
              .from('user_integrations')
              .insert(integrationPayload)
              .select()
              .single()
        : await _db
              .from('user_integrations')
              .update(integrationPayload)
              .eq('id', integrationId)
              .select()
              .single();

    final savedIntegrationId = integrationRow['id'] as String;
    final profilePayload = {
      'profile_id': profileId,
      'integration_id': savedIntegrationId,
      'is_enabled': isEnabled,
      'display_label': displayLabel,
      'sort_order': sortOrder,
    };

    final profileRow = profileIntegrationId == null
        ? await _db
              .from('profile_integrations')
              .insert(profilePayload)
              .select('*, user_integrations(*)')
              .single()
        : await _db
              .from('profile_integrations')
              .update(profilePayload)
              .eq('id', profileIntegrationId)
              .select('*, user_integrations(*)')
              .single();

    return ProfileIntegrationModel.fromJson(
      Map<String, dynamic>.from(profileRow),
    );
  }
}

class TeamRepository {
  static Future<AppUserModel?> findUserByEmailOrUsername(String value) async {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return null;
    try {
      final rows = await _db.rpc(
        'find_invitable_app_user',
        params: {'p_lookup': query},
      );
      if (rows is List && rows.isNotEmpty) {
        return AppUserModel.fromJson(Map<String, dynamic>.from(rows.first));
      }
    } catch (error) {
      debugPrint('[TaploeTeam] No se pudo usar find_invitable_app_user.');
      safePrintError(error);
    }

    try {
      final column = query.contains('@') ? 'email' : 'username';
      final normalized = column == 'username'
          ? UserRepository.normalizeUsername(query)
          : query;
      final row = await _db
          .from('app_users')
          .select()
          .ilike(column, normalized)
          .maybeSingle();
      if (row == null) return null;
      return AppUserModel.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('[TaploeTeam] No se pudo buscar usuario para invitación.');
      safePrintError(error);
      return null;
    }
  }

  static Future<void> inviteMember({
    required OrganizationModel org,
    required AppUserModel invitedBy,
    required String emailOrUsername,
    String role = 'member',
  }) async {
    final inviterMembership = await _db
        .from('organization_members')
        .select('role,status')
        .eq('org_id', org.id)
        .eq('user_id', invitedBy.id)
        .eq('status', 'active')
        .maybeSingle();
    final inviterRole = inviterMembership?['role'] as String?;
    if (inviterRole != 'owner' && inviterRole != 'admin') {
      throw const TeamInviteException('not_allowed');
    }

    final invitedUser = await findUserByEmailOrUsername(emailOrUsername);
    if (invitedUser == null) {
      throw const TeamInviteException('user_not_found');
    }
    if (invitedUser.id == invitedBy.id) {
      throw const TeamInviteException('cannot_invite_self');
    }

    final activeMembership = await _db
        .from('organization_members')
        .select('id')
        .eq('org_id', org.id)
        .eq('user_id', invitedUser.id)
        .eq('status', 'active')
        .maybeSingle();
    if (activeMembership != null) {
      throw const TeamInviteException('already_member');
    }

    final existingInvite = await _db
        .from('organization_invitations')
        .select('id,status')
        .eq('org_id', org.id)
        .eq('invited_user_id', invitedUser.id)
        .eq('status', 'pending')
        .maybeSingle();
    if (existingInvite != null) {
      throw const TeamInviteException('already_invited');
    }

    final invitation = await _db
        .from('organization_invitations')
        .insert({
          'org_id': org.id,
          'invited_user_id': invitedUser.id,
          'invited_by_user_id': invitedBy.id,
          'role': role,
          'status': 'pending',
        })
        .select()
        .single();

    await _db.from('app_notifications').insert({
      'user_id': invitedUser.id,
      'notification_type': 'team_invitation',
      'title': 'Invitación a ${org.name}',
      'body': '${invitedBy.username} te invitó a unirte a su equipo.',
      'action_url': '/team',
      'metadata': {
        'invitation_id': invitation['id'],
        'org_id': org.id,
        'org_name': org.name,
        'invited_by_user_id': invitedBy.id,
        'invited_by_name': invitedBy.username,
        'role': role,
        'status': 'pending',
      },
    });
  }

  static Future<TeamInvitationModel?> fetchInvitation(
    String invitationId,
  ) async {
    final row = await _db
        .from('organization_invitations')
        .select()
        .eq('id', invitationId)
        .maybeSingle();
    if (row == null) return null;
    return TeamInvitationModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<void> respondToInvitation({
    required String invitationId,
    required AppUserModel user,
    required bool accept,
  }) async {
    final invitation = await fetchInvitation(invitationId);
    if (invitation == null || invitation.invitedUserId != user.id) {
      throw const TeamInviteException('invitation_not_found');
    }
    if (invitation.status != 'pending') {
      throw const TeamInviteException('invitation_resolved');
    }

    if (accept) {
      await _db.from('organization_members').upsert({
        'org_id': invitation.orgId,
        'user_id': user.id,
        'role': invitation.role,
        'status': 'active',
        'invited_by_user_id': invitation.invitedByUserId,
        'joined_at': nowIso(),
      }, onConflict: 'org_id,user_id');

      await _db
          .from('digital_profiles')
          .update({'org_id': invitation.orgId, 'updated_at': nowIso()})
          .eq('owner_user_id', user.id)
          .isFilter('org_id', null);
    }

    await _db
        .from('organization_invitations')
        .update({
          'status': accept ? 'accepted' : 'declined',
          'responded_at': nowIso(),
        })
        .eq('id', invitationId);

    await _db
        .from('app_notifications')
        .update({
          'read_at': nowIso(),
          'metadata': {
            'invitation_id': invitationId,
            'org_id': invitation.orgId,
            'role': invitation.role,
            'status': accept ? 'accepted' : 'declined',
          },
        })
        .eq('user_id', user.id)
        .eq('notification_type', 'team_invitation')
        .contains('metadata', {'invitation_id': invitationId});
  }

  static Future<List<String>> fetchProfileIdsForOrg(
    String orgId, {
    String? ownerUserId,
  }) async {
    var query = _db
        .from('digital_profiles')
        .select('id')
        .eq('org_id', orgId)
        .neq('status', 'deleted');
    if (ownerUserId != null) query = query.eq('owner_user_id', ownerUserId);
    final rows = await query;
    return (rows as List)
        .map((row) => (row as Map)['id'])
        .whereType<String>()
        .toList();
  }

  static Future<List<TeamActivityModel>> fetchRecentActivity(
    String orgId, {
    String? ownerUserId,
    int limit = 8,
  }) async {
    try {
      final rows = await _db.rpc(
        'list_org_team_activity',
        params: {
          'p_org_id': orgId,
          'p_owner_user_id': ownerUserId,
          'p_limit': limit * 2,
        },
      );
      if (rows is List) {
        return rows
            .map((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              return TeamActivityModel(
                event: AnalyticsEventModel.fromJson(row),
                memberName: row['member_name'] as String? ?? 'Miembro',
                profileName: row['profile_name'] as String? ?? 'perfil',
              );
            })
            .where(
              (activity) => !AnalyticsRepository._isLegacyProfileInstallEvent(
                activity.event.eventType,
              ),
            )
            .take(limit)
            .toList();
      }
    } catch (error) {
      debugPrint(
        '[TaploeTeam] No se pudo cargar actividad del equipo por RPC.',
      );
      safePrintError(error);
    }

    var profilesQuery = _db
        .from('digital_profiles')
        .select('id,owner_user_id,display_name,profile_name')
        .eq('org_id', orgId)
        .neq('status', 'deleted');
    if (ownerUserId != null) {
      profilesQuery = profilesQuery.eq('owner_user_id', ownerUserId);
    }
    final profiles = await profilesQuery;
    final profileRows = (profiles as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final profileIds = profileRows
        .map((row) => row['id'])
        .whereType<String>()
        .toList();
    if (profileIds.isEmpty) return const [];

    final users = await _db
        .from('app_users')
        .select('id,username,email')
        .inFilter(
          'id',
          profileRows
              .map((row) => row['owner_user_id'])
              .whereType<String>()
              .toSet()
              .toList(),
        );
    final usersById = {
      for (final raw in users as List)
        (raw as Map)['id'] as String: Map<String, dynamic>.from(raw),
    };
    final profilesById = {
      for (final row in profileRows) row['id'] as String: row,
    };

    final rows = await _db
        .from('analytics_events')
        .select(
          'id,profile_id,lead_id,link_id,form_id,form_submission_id,event_type,access_channel,city,region,country,metadata,occurred_at,profile_links(label)',
        )
        .inFilter('profile_id', profileIds)
        .order('occurred_at', ascending: false)
        .limit(limit * 2);

    return (rows as List)
        .map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          final profile = profilesById[row['profile_id']];
          final ownerId = profile?['owner_user_id'] as String?;
          final user = ownerId == null ? null : usersById[ownerId];
          return TeamActivityModel(
            event: AnalyticsEventModel.fromJson(row),
            memberName:
                user?['username'] as String? ??
                user?['email'] as String? ??
                'Miembro',
            profileName:
                profile?['display_name'] as String? ??
                profile?['profile_name'] as String? ??
                'perfil',
          );
        })
        .where(
          (activity) => !AnalyticsRepository._isLegacyProfileInstallEvent(
            activity.event.eventType,
          ),
        )
        .take(limit)
        .toList();
  }

  static Future<List<TeamMemberModel>> fetchTeam(String orgId) async {
    var memberRows = <Map<String, dynamic>>[];
    try {
      final rows = await _db.rpc(
        'list_org_team_members',
        params: {'p_org_id': orgId},
      );
      if (rows is List) {
        memberRows = rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      }
    } catch (error) {
      debugPrint('[TaploeTeam] No se pudo cargar directorio del equipo.');
      safePrintError(error);
    }

    if (memberRows.isEmpty) {
      final memberships = await _db
          .from('organization_members')
          .select()
          .eq('org_id', orgId)
          .eq('status', 'active');

      final fallbackUserIds = (memberships as List)
          .map((e) => (e as Map)['user_id'])
          .whereType<String>()
          .toList();

      if (fallbackUserIds.isNotEmpty) {
        final users = await _db
            .from('app_users')
            .select()
            .inFilter('id', fallbackUserIds);
        memberRows = (users as List).map((raw) {
          final user = Map<String, dynamic>.from(raw as Map);
          final id = user['id'] as String;
          final membership =
              memberships.firstWhere(
                    (m) => (m as Map)['user_id'] == id,
                    orElse: () => {'role': 'member', 'status': 'active'},
                  )
                  as Map;
          return {
            ...user,
            'role': membership['role'] as String? ?? 'member',
            'status': membership['status'] as String? ?? 'active',
          };
        }).toList();
      }
    }

    final userIds = memberRows.map((e) => e['id']).whereType<String>().toList();

    if (userIds.isEmpty) return [];
    if (memberRows.first.containsKey('profiles')) {
      final activeMembers = memberRows.map((user) {
        return TeamMemberModel(
          id: user['id'] as String,
          name:
              user['username'] as String? ?? user['full_name'] as String? ?? '',
          email: user['email'] as String? ?? '',
          role: user['role'] as String? ?? 'member',
          status: user['status'] as String? ?? 'active',
          avatarUrl:
              user['profile_avatar_url'] as String? ??
              user['avatar_url'] as String?,
          profiles: _teamCount(user['profiles']),
          views: _teamCount(user['views']),
          nfc: _teamCount(user['nfc']),
          qr: _teamCount(user['qr']),
          clicks: _teamCount(user['clicks']),
          cards: _teamCount(user['cards']),
          leads: _teamCount(user['leads']),
        );
      }).toList();
      final pendingMembers = await _fetchPendingMembers(orgId, userIds);
      return [...activeMembers, ...pendingMembers];
    }

    final profiles = await _db
        .from('digital_profiles')
        .select('id, owner_user_id, profile_photo_url, is_default, created_at')
        .eq('org_id', orgId);

    final profileIds = (profiles as List)
        .map((e) => (e as Map)['id'])
        .whereType<String>()
        .toList();

    final events = profileIds.isEmpty
        ? []
        : await _db
              .from('analytics_events')
              .select('profile_id,event_type,access_channel')
              .inFilter('profile_id', profileIds);

    final leads = await _db
        .from('leads')
        .select('owner_user_id')
        .eq('org_id', orgId);

    final cards = userIds.isEmpty
        ? <dynamic>[]
        : await _db
              .from('physical_cards')
              .select('owner_user_id,status')
              .inFilter('owner_user_id', userIds);

    final activeMembers = memberRows.map((user) {
      final id = user['id'] as String;
      final pIds = (profiles as List)
          .where((p) => (p as Map)['owner_user_id'] == id)
          .map((p) => (p as Map)['id'])
          .whereType<String>()
          .toSet();
      final memberProfiles =
          (profiles)
              .where((p) => (p as Map)['owner_user_id'] == id)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList()
            ..sort((a, b) {
              final aDefault = a['is_default'] == true ? 0 : 1;
              final bDefault = b['is_default'] == true ? 0 : 1;
              if (aDefault != bDefault) return aDefault.compareTo(bDefault);
              return '${a['created_at'] ?? ''}'.compareTo(
                '${b['created_at'] ?? ''}',
              );
            });
      String? profileAvatar;
      for (final profile in memberProfiles) {
        final url = profile['profile_photo_url'] as String?;
        if (url?.trim().isNotEmpty == true) {
          profileAvatar = url;
          break;
        }
      }
      final views = events
          .where(
            (e) =>
                pIds.contains((e as Map)['profile_id']) &&
                e['event_type'] == 'profile_view',
          )
          .length;
      final nfc = events
          .where(
            (e) =>
                pIds.contains((e as Map)['profile_id']) &&
                e['access_channel'] == 'nfc',
          )
          .length;
      final qr = events
          .where(
            (e) =>
                pIds.contains((e as Map)['profile_id']) &&
                e['access_channel'] == 'qr',
          )
          .length;
      final clicks = events
          .where(
            (e) =>
                pIds.contains((e as Map)['profile_id']) &&
                ((e['event_type'] == 'link_click') ||
                    (e['event_type'] == 'calendar_click')),
          )
          .length;
      final leadCount = (leads as List)
          .where((l) => (l as Map)['owner_user_id'] == id)
          .length;
      final cardCount = cards
          .where(
            (card) =>
                (card as Map)['owner_user_id'] == id &&
                card['status'] == 'claimed',
          )
          .length;
      return TeamMemberModel(
        id: id,
        name: user['username'] as String? ?? user['full_name'] as String? ?? '',
        email: user['email'] as String? ?? '',
        role: user['role'] as String? ?? 'member',
        status: user['status'] as String? ?? 'active',
        avatarUrl: profileAvatar ?? user['avatar_url'] as String?,
        profiles: pIds.length,
        views: views,
        nfc: nfc,
        qr: qr,
        clicks: clicks,
        cards: cardCount,
        leads: leadCount,
      );
    }).toList();

    final pendingMembers = await _fetchPendingMembers(orgId, userIds);

    return [...activeMembers, ...pendingMembers];
  }

  static int _teamCount(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static Future<List<TeamMemberModel>> _fetchPendingMembers(
    String orgId,
    List<String> userIds,
  ) async {
    final pendingMembers = <TeamMemberModel>[];
    try {
      final rows = await _db.rpc(
        'list_org_pending_invitations',
        params: {'p_org_id': orgId},
      );
      if (rows is List) {
        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw as Map);
          final userId = row['invited_user_id'] as String? ?? '';
          if (userId.isEmpty || userIds.contains(userId)) continue;
          pendingMembers.add(
            TeamMemberModel(
              id: userId,
              name: row['username'] as String? ?? 'Usuario invitado',
              email: row['email'] as String? ?? '',
              role: row['role'] as String? ?? 'member',
              status: 'pending',
              invitationId: row['invitation_id'] as String?,
              avatarUrl: row['avatar_url'] as String?,
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('[TaploeTeam] No se pudieron cargar invitaciones pendientes.');
      safePrintError(error);
    }
    return pendingMembers;
  }

  static Future<void> cancelInvitation(String invitationId) async {
    await _db
        .from('organization_invitations')
        .update({'status': 'cancelled', 'responded_at': nowIso()})
        .eq('id', invitationId)
        .eq('status', 'pending');
  }

  static Future<void> removeMember({
    required String orgId,
    required String userId,
  }) async {
    await _db.rpc(
      'remove_org_team_member',
      params: {'p_org_id': orgId, 'p_user_id': userId},
    );
  }
}
