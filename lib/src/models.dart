import 'config.dart';
import 'localization.dart';

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class AppUserModel {
  final String id;
  final String? authUserId;
  final String username;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String status;
  final String timezone;
  final String planType;
  final String preferredLanguage;
  final String preferredMarket;

  const AppUserModel({
    required this.id,
    this.authUserId,
    required this.username,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.status = 'active',
    this.timezone = 'America/Tijuana',
    this.planType = 'free',
    this.preferredLanguage = 'es',
    this.preferredMarket = 'mx',
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) => AppUserModel(
    id: json['id'] as String,
    authUserId: json['auth_user_id'] as String?,
    username: json['username'] as String? ?? json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    status: json['status'] as String? ?? 'active',
    timezone: json['timezone'] as String? ?? 'America/Tijuana',
    planType: json['plan_type'] as String? ?? 'free',
    preferredLanguage: json['preferred_language'] as String? ?? 'es',
    preferredMarket: json['preferred_market'] as String? ?? 'mx',
  );

  TaploeLocaleConfig get localeConfig => TaploeLocaleConfig.fromParts(
    language: preferredLanguage,
    market: preferredMarket,
  );

  Map<String, dynamic> toUpsert() => {
    'auth_user_id': authUserId,
    'username': username,
    'email': email,
    if (phone != null) 'phone': phone,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    'status': status,
    'timezone': timezone,
    'plan_type': planType,
    'preferred_language': preferredLanguage,
    'preferred_market': preferredMarket,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class AppNotificationModel {
  final String id;
  final String userId;
  final String? profileId;
  final String? leadId;
  final String notificationType;
  final String title;
  final String body;
  final String? actionUrl;
  final Map<String, dynamic> metadata;
  final DateTime? readAt;
  final DateTime? createdAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    this.profileId,
    this.leadId,
    required this.notificationType,
    required this.title,
    required this.body,
    this.actionUrl,
    this.metadata = const {},
    this.readAt,
    this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) =>
      AppNotificationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String? ?? '',
        profileId: json['profile_id'] as String?,
        leadId: json['lead_id'] as String?,
        notificationType: json['notification_type'] as String? ?? 'info',
        title: json['title'] as String? ?? 'Notificación',
        body: json['body'] as String? ?? '',
        actionUrl: json['action_url'] as String?,
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
        readAt: _dt(json['read_at']),
        createdAt: _dt(json['created_at']),
      );
}

class TeamInvitationModel {
  final String id;
  final String orgId;
  final String invitedUserId;
  final String invitedByUserId;
  final String role;
  final String status;
  final DateTime? respondedAt;
  final DateTime? createdAt;

  const TeamInvitationModel({
    required this.id,
    required this.orgId,
    required this.invitedUserId,
    required this.invitedByUserId,
    required this.role,
    required this.status,
    this.respondedAt,
    this.createdAt,
  });

  factory TeamInvitationModel.fromJson(Map<String, dynamic> json) =>
      TeamInvitationModel(
        id: json['id'] as String,
        orgId: json['org_id'] as String? ?? '',
        invitedUserId: json['invited_user_id'] as String? ?? '',
        invitedByUserId: json['invited_by_user_id'] as String? ?? '',
        role: json['role'] as String? ?? 'member',
        status: json['status'] as String? ?? 'pending',
        respondedAt: _dt(json['responded_at']),
        createdAt: _dt(json['created_at']),
      );
}

class OrganizationModel {
  final String id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final String? websiteUrl;
  final String? phone;
  final String? email;
  final String planType;
  final bool enforceTeamProfileTheme;
  final bool enforceTeamProfileForms;
  final bool enforceTeamProfileIntegrations;
  final ProfileThemeModel? teamProfileTheme;
  final String? teamProfileLogoUrl;
  final String? teamProfileCoverPhotoUrl;

  const OrganizationModel({
    required this.id,
    required this.name,
    this.slug,
    this.logoUrl,
    this.websiteUrl,
    this.phone,
    this.email,
    this.planType = 'free',
    this.enforceTeamProfileTheme = false,
    this.enforceTeamProfileForms = false,
    this.enforceTeamProfileIntegrations = false,
    this.teamProfileTheme,
    this.teamProfileLogoUrl,
    this.teamProfileCoverPhotoUrl,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    final teamTheme = json['team_profile_theme'] is Map
        ? Map<String, dynamic>.from(json['team_profile_theme'] as Map)
        : null;
    return OrganizationModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      logoUrl: json['company_logo_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      phone: json['phone'] as String?,
      email: json['email']?.toString(),
      planType: json['plan_type'] as String? ?? 'free',
      enforceTeamProfileTheme:
          json['enforce_team_profile_theme'] as bool? ?? false,
      enforceTeamProfileForms:
          json['enforce_team_profile_forms'] as bool? ?? false,
      enforceTeamProfileIntegrations:
          json['enforce_team_profile_integrations'] as bool? ?? false,
      teamProfileTheme: teamTheme != null
          ? ProfileThemeModel.fromJson({'profile_id': '', ...teamTheme})
          : null,
      teamProfileLogoUrl: teamTheme?['logo_url'] as String?,
      teamProfileCoverPhotoUrl: teamTheme?['cover_photo_url'] as String?,
    );
  }
}

class OrganizationSummaryModel {
  final int members;
  final int profiles;
  final int cards;
  final int views;
  final int nfc;
  final int qr;
  final int clicks;
  final int leads;

  const OrganizationSummaryModel({
    required this.members,
    required this.profiles,
    required this.cards,
    required this.views,
    required this.nfc,
    required this.qr,
    required this.clicks,
    required this.leads,
  });
}

class BillingSubscriptionModel {
  final String id;
  final String scope;
  final String? userId;
  final String? orgId;
  final String ownerUserId;
  final String planType;
  final String billingInterval;
  final String status;
  final bool cancelAtPeriodEnd;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? graceUntil;
  final DateTime? canceledAt;
  final DateTime? endedAt;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? stripePriceId;
  final String? stripeProductId;
  final int quantity;
  final String? currency;
  final DateTime? lastPaymentAt;
  final DateTime? nextPaymentAt;
  final String? latestInvoiceId;
  final String? latestInvoiceStatus;
  final String? hostedInvoiceUrl;
  final bool paymentIssue;
  final bool paymentActionRequired;
  final DateTime? trialEndingNotifiedAt;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const BillingSubscriptionModel({
    required this.id,
    required this.scope,
    this.userId,
    this.orgId,
    required this.ownerUserId,
    required this.planType,
    required this.billingInterval,
    required this.status,
    this.cancelAtPeriodEnd = false,
    this.trialStart,
    this.trialEnd,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.graceUntil,
    this.canceledAt,
    this.endedAt,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.stripePriceId,
    this.stripeProductId,
    this.quantity = 1,
    this.currency,
    this.lastPaymentAt,
    this.nextPaymentAt,
    this.latestInvoiceId,
    this.latestInvoiceStatus,
    this.hostedInvoiceUrl,
    this.paymentIssue = false,
    this.paymentActionRequired = false,
    this.trialEndingNotifiedAt,
    this.metadata = const {},
    this.createdAt,
  });

  factory BillingSubscriptionModel.fromJson(Map<String, dynamic> json) =>
      BillingSubscriptionModel(
        id: json['id'] as String,
        scope: json['scope'] as String? ?? 'user',
        userId: json['user_id'] as String?,
        orgId: json['org_id'] as String?,
        ownerUserId: json['owner_user_id'] as String? ?? '',
        planType: json['plan_type'] as String? ?? 'premium',
        billingInterval: json['billing_interval'] as String? ?? 'monthly',
        status: json['status'] as String? ?? 'expired',
        cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
        trialStart: _dt(json['trial_start']),
        trialEnd: _dt(json['trial_end']),
        currentPeriodStart: _dt(json['current_period_start']),
        currentPeriodEnd: _dt(json['current_period_end']),
        graceUntil: _dt(json['grace_until']),
        canceledAt: _dt(json['canceled_at']),
        endedAt: _dt(json['ended_at']),
        stripeCustomerId: json['stripe_customer_id'] as String?,
        stripeSubscriptionId: json['stripe_subscription_id'] as String?,
        stripePriceId: json['stripe_price_id'] as String?,
        stripeProductId: json['stripe_product_id'] as String?,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        currency: json['currency'] as String?,
        lastPaymentAt: _dt(json['last_payment_at']),
        nextPaymentAt: _dt(json['next_payment_at']),
        latestInvoiceId: json['latest_invoice_id'] as String?,
        latestInvoiceStatus: json['latest_invoice_status'] as String?,
        hostedInvoiceUrl: json['hosted_invoice_url'] as String?,
        paymentIssue: json['payment_issue'] as bool? ?? false,
        paymentActionRequired:
            json['payment_action_required'] as bool? ?? false,
        trialEndingNotifiedAt: _dt(json['trial_ending_notified_at']),
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
        createdAt: _dt(json['created_at']),
      );

  bool get isUserScope => scope == 'user';
  bool get isOrganizationScope => scope == 'organization';
  bool get isTrialing => status == 'trialing';
  bool get isActive => status == 'active';
  bool get isPastDue => status == 'past_due' || status == 'grace_period';
  bool get isEnded =>
      status == 'expired' || status == 'canceled' || status == 'unpaid';

  DateTime? get effectiveAccessUntil =>
      graceUntil ?? currentPeriodEnd ?? trialEnd;

  DateTime? get nextChargeAt => nextPaymentAt ?? currentPeriodEnd ?? trialEnd;

  bool get grantsAccess {
    if (!(isTrialing || isActive || isPastDue)) return false;
    final accessUntil = effectiveAccessUntil;
    return accessUntil == null || accessUntil.isAfter(DateTime.now());
  }
}

class BillingInvoiceModel {
  final String id;
  final String? subscriptionId;
  final String? userId;
  final String? orgId;
  final String? stripeInvoiceId;
  final String? stripePaymentIntentId;
  final String status;
  final String currency;
  final double amountDue;
  final double amountPaid;
  final double amountRemaining;
  final String? hostedInvoiceUrl;
  final String? invoicePdf;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? paidAt;
  final DateTime? createdAt;

  const BillingInvoiceModel({
    required this.id,
    this.subscriptionId,
    this.userId,
    this.orgId,
    this.stripeInvoiceId,
    this.stripePaymentIntentId,
    required this.status,
    required this.currency,
    required this.amountDue,
    required this.amountPaid,
    required this.amountRemaining,
    this.hostedInvoiceUrl,
    this.invoicePdf,
    this.periodStart,
    this.periodEnd,
    this.paidAt,
    this.createdAt,
  });

  factory BillingInvoiceModel.fromJson(Map<String, dynamic> json) {
    double money(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return BillingInvoiceModel(
      id: json['id'] as String,
      subscriptionId: json['subscription_id'] as String?,
      userId: json['user_id'] as String?,
      orgId: json['org_id'] as String?,
      stripeInvoiceId: json['stripe_invoice_id'] as String?,
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      status: json['status'] as String? ?? 'open',
      currency: json['currency'] as String? ?? 'MXN',
      amountDue: money(json['amount_due']),
      amountPaid: money(json['amount_paid']),
      amountRemaining: money(json['amount_remaining']),
      hostedInvoiceUrl: json['hosted_invoice_url'] as String?,
      invoicePdf: json['invoice_pdf'] as String?,
      periodStart: _dt(json['period_start']),
      periodEnd: _dt(json['period_end']),
      paidAt: _dt(json['paid_at']),
      createdAt: _dt(json['created_at']),
    );
  }
}

class ProfileThemeModel {
  final String? id;
  final String profileId;
  final String themeStyle;
  final String layoutStyle;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String backgroundType;
  final String backgroundColorStart;
  final String? backgroundColorEnd;
  final String? backgroundImageUrl;
  final String buttonStyle;
  final String fontFamily;

  const ProfileThemeModel({
    this.id,
    required this.profileId,
    this.themeStyle = 'light',
    this.layoutStyle = 'centered',
    this.primaryColor = '#1557FF',
    this.secondaryColor = '#FFFFFF',
    this.accentColor = '#1557FF',
    this.backgroundType = 'solid',
    this.backgroundColorStart = '#FFFFFF',
    this.backgroundColorEnd,
    this.backgroundImageUrl,
    this.buttonStyle = 'pill',
    this.fontFamily = 'system',
  });

  factory ProfileThemeModel.fromJson(Map<String, dynamic> json) =>
      ProfileThemeModel(
        id: json['id'] as String?,
        profileId: json['profile_id'] as String? ?? '',
        themeStyle: json['theme_style'] as String? ?? 'light',
        layoutStyle: json['layout_style'] as String? ?? 'centered',
        primaryColor: json['primary_color'] as String? ?? '#1557FF',
        secondaryColor: json['secondary_color'] as String? ?? '#FFFFFF',
        accentColor: json['accent_color'] as String? ?? '#1557FF',
        backgroundType: json['background_type'] as String? ?? 'solid',
        backgroundColorStart:
            json['background_color_start'] as String? ?? '#FFFFFF',
        backgroundColorEnd: json['background_color_end'] as String?,
        backgroundImageUrl: json['background_image_url'] as String?,
        buttonStyle: json['button_style'] as String? ?? 'pill',
        fontFamily: json['font_family'] as String? ?? 'system',
      );

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'theme_style': themeStyle,
    'layout_style': layoutStyle,
    'primary_color': primaryColor,
    'secondary_color': secondaryColor,
    'accent_color': accentColor,
    'background_type': backgroundType,
    'background_color_start': backgroundColorStart,
    'background_color_end': backgroundColorEnd,
    'background_image_url': backgroundImageUrl,
    'button_style': buttonStyle,
    'font_family': fontFamily,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class ProfileVcardModel {
  final String? id;
  final String profileId;
  final String? firstName;
  final String? lastName;
  final String? organization;
  final String? title;
  final String? email;
  final String? phone;
  final String? mobilePhone;
  final String? whatsappPhone;
  final String? websiteUrl;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? note;

  const ProfileVcardModel({
    this.id,
    required this.profileId,
    this.firstName,
    this.lastName,
    this.organization,
    this.title,
    this.email,
    this.phone,
    this.mobilePhone,
    this.whatsappPhone,
    this.websiteUrl,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.note,
  });

  factory ProfileVcardModel.fromJson(Map<String, dynamic> json) =>
      ProfileVcardModel(
        id: json['id'] as String?,
        profileId: json['profile_id'] as String? ?? '',
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        organization: json['organization'] as String?,
        title: json['title'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        mobilePhone: json['mobile_phone'] as String?,
        whatsappPhone: json['whatsapp_phone'] as String?,
        websiteUrl: json['website_url'] as String?,
        addressLine1: json['address_line_1'] as String?,
        addressLine2: json['address_line_2'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        postalCode: json['postal_code'] as String?,
        country: json['country'] as String?,
        note: json['note'] as String?,
      );

  String toVcf({required String displayName, String? profilePhotoUrl}) {
    final fn = displayName.trim().isEmpty ? 'Taploe Contact' : displayName;
    return [
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:$fn',
      if ((firstName ?? lastName) != null)
        'N:${lastName ?? ''};${firstName ?? ''};;;',
      if (organization != null && organization!.isNotEmpty) 'ORG:$organization',
      if (title != null && title!.isNotEmpty) 'TITLE:$title',
      if (email != null && email!.isNotEmpty) 'EMAIL:$email',
      if (phone != null && phone!.isNotEmpty) 'TEL;TYPE=WORK:$phone',
      if (mobilePhone != null && mobilePhone!.isNotEmpty)
        'TEL;TYPE=CELL:$mobilePhone',
      if (whatsappPhone != null && whatsappPhone!.isNotEmpty)
        'TEL;TYPE=WHATSAPP:$whatsappPhone',
      if (websiteUrl != null && websiteUrl!.isNotEmpty) 'URL:$websiteUrl',
      if ([
        addressLine1,
        addressLine2,
        city,
        state,
        postalCode,
        country,
      ].any((part) => part?.isNotEmpty == true))
        'ADR;TYPE=WORK:;;${addressLine1 ?? ''};${city ?? ''};${state ?? ''};${postalCode ?? ''};${country ?? ''}',
      if (note != null && note!.isNotEmpty) 'NOTE:$note',
      'END:VCARD',
    ].join('\n');
  }

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'first_name': firstName,
    'last_name': lastName,
    'organization': organization,
    'title': title,
    'email': email,
    'phone': phone,
    'mobile_phone': mobilePhone,
    'whatsapp_phone': whatsappPhone,
    'website_url': websiteUrl,
    'address_line_1': addressLine1,
    'address_line_2': addressLine2,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'country': country,
    'note': note,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class ProfileLinkModel {
  final String id;
  final String profileId;
  final String linkType;
  final String label;
  final String? value;
  final String? url;
  final String? iconKey;
  final bool isVisible;
  final bool isFeatured;
  final int sortOrder;
  final String openMode;
  final Map<String, dynamic> metadata;

  const ProfileLinkModel({
    required this.id,
    required this.profileId,
    required this.linkType,
    required this.label,
    this.value,
    this.url,
    this.iconKey,
    this.isVisible = true,
    this.isFeatured = false,
    this.sortOrder = 0,
    this.openMode = 'external',
    this.metadata = const {},
  });

  factory ProfileLinkModel.fromJson(Map<String, dynamic> json) =>
      ProfileLinkModel(
        id: json['id'] as String,
        profileId: json['profile_id'] as String? ?? '',
        linkType: json['link_type'] as String? ?? 'custom',
        label: json['label'] as String? ?? '',
        value: json['value'] as String?,
        url: json['url'] as String?,
        iconKey: json['icon_key'] as String?,
        isVisible: json['is_visible'] as bool? ?? true,
        isFeatured: json['is_featured'] as bool? ?? false,
        sortOrder: _int(json['sort_order']),
        openMode: json['open_mode'] as String? ?? 'external',
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );

  Map<String, dynamic> toJson() => {
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
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class DigitalProfileModel {
  final String id;
  final String ownerUserId;
  final String? orgId;
  final String? profileName;
  final String displayName;
  final String? jobTitle;
  final String? companyName;
  final String? bio;
  final String publicSlug;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final String? logoUrl;
  final String status;
  final bool isDefault;
  final bool showVerifiedBadge;
  final String publicLocale;
  final ProfileThemeModel? theme;
  final ProfileVcardModel? vcard;
  final List<ProfileLinkModel> links;

  const DigitalProfileModel({
    required this.id,
    required this.ownerUserId,
    this.orgId,
    this.profileName,
    required this.displayName,
    this.jobTitle,
    this.companyName,
    this.bio,
    required this.publicSlug,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.logoUrl,
    this.status = 'active',
    this.isDefault = false,
    this.showVerifiedBadge = false,
    this.publicLocale = 'es-MX',
    this.theme,
    this.vcard,
    this.links = const [],
  });

  factory DigitalProfileModel.fromJson(Map<String, dynamic> json) {
    final linkRaw = json['profile_links'];
    final links = linkRaw is List
        ? linkRaw
              .whereType<Map>()
              .map(
                (e) => ProfileLinkModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <ProfileLinkModel>[];
    links.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    Map<String, dynamic>? one(dynamic raw) {
      if (raw is List && raw.isNotEmpty && raw.first is Map) {
        return Map<String, dynamic>.from(raw.first as Map);
      }
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    }

    final themeJson = one(json['profile_theme_settings']);
    final vcardJson = one(json['profile_vcard_details']);

    return DigitalProfileModel(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String? ?? '',
      orgId: json['org_id'] as String?,
      profileName: json['profile_name'] as String?,
      displayName: json['display_name'] as String? ?? '',
      jobTitle: json['job_title'] as String?,
      companyName: json['company_name'] as String?,
      bio: json['bio'] as String?,
      publicSlug: json['public_slug'] as String? ?? '',
      profilePhotoUrl: json['profile_photo_url'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      logoUrl: json['logo_url'] as String?,
      status: json['status'] as String? ?? 'active',
      isDefault: json['is_default'] as bool? ?? false,
      showVerifiedBadge: json['show_verified_badge'] as bool? ?? false,
      publicLocale: json['public_locale'] as String? ?? 'es-MX',
      theme: themeJson == null ? null : ProfileThemeModel.fromJson(themeJson),
      vcard: vcardJson == null ? null : ProfileVcardModel.fromJson(vcardJson),
      links: links,
    );
  }

  Map<String, dynamic> toUpdate() => {
    'profile_name': profileName,
    'display_name': displayName,
    'job_title': jobTitle,
    'company_name': companyName,
    'bio': bio,
    'public_slug': publicSlug,
    'profile_photo_url': profilePhotoUrl,
    'cover_photo_url': coverPhotoUrl,
    'logo_url': logoUrl,
    'status': status,
    'is_default': isDefault,
    'show_verified_badge': showVerifiedBadge,
    'public_locale': publicLocale,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  DigitalProfileModel copyWith({
    String? displayName,
    String? jobTitle,
    String? companyName,
    String? bio,
    String? publicSlug,
    String? profilePhotoUrl,
    String? coverPhotoUrl,
    String? logoUrl,
    bool clearLogoUrl = false,
    String? status,
    bool? showVerifiedBadge,
    String? publicLocale,
    ProfileThemeModel? theme,
    ProfileVcardModel? vcard,
    List<ProfileLinkModel>? links,
  }) => DigitalProfileModel(
    id: id,
    ownerUserId: ownerUserId,
    orgId: orgId,
    profileName: profileName,
    displayName: displayName ?? this.displayName,
    jobTitle: jobTitle ?? this.jobTitle,
    companyName: companyName ?? this.companyName,
    bio: bio ?? this.bio,
    publicSlug: publicSlug ?? this.publicSlug,
    profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
    logoUrl: clearLogoUrl ? null : logoUrl ?? this.logoUrl,
    status: status ?? this.status,
    isDefault: isDefault,
    showVerifiedBadge: showVerifiedBadge ?? this.showVerifiedBadge,
    publicLocale: publicLocale ?? this.publicLocale,
    theme: theme ?? this.theme,
    vcard: vcard ?? this.vcard,
    links: links ?? this.links,
  );
}

class ProfileAccessPointModel {
  final String id;
  final String? profileId;
  final String? physicalCardId;
  final String channel;
  final String token;
  final String targetType;
  final String? externalUrl;
  final bool isActive;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileAccessPointModel({
    required this.id,
    this.profileId,
    this.physicalCardId,
    required this.channel,
    required this.token,
    required this.targetType,
    this.externalUrl,
    this.isActive = true,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileAccessPointModel.fromJson(Map<String, dynamic> json) =>
      ProfileAccessPointModel(
        id: json['id'] as String,
        profileId: json['profile_id'] as String?,
        physicalCardId: json['physical_card_id'] as String?,
        channel: json['channel'] as String? ?? 'direct',
        token: json['token'] as String? ?? '',
        targetType: json['target_type'] as String? ?? 'profile',
        externalUrl: json['external_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
        createdAt: _dt(json['created_at']),
        updatedAt: _dt(json['updated_at']),
      );

  String get publicUrl => TaploeConfig.accessUrl(token);

  String get channelLabel {
    switch (channel) {
      case 'qr':
        return 'Escaneo QR';
      case 'nfc':
        return 'Toque NFC';
      case 'manual':
        return 'Manual';
      default:
        return 'Acceso directo';
    }
  }
}

class PhysicalCardModel {
  final String id;
  final String? batchId;
  final String? productTypeId;
  final String? productTypeName;
  final String? productTypeCode;
  final String serialNumber;
  final String? nfcUid;
  final String? printedName;
  final String? printedDesignUrl;
  final String status;
  final String activationMode;
  final String? ownerUserId;
  final String? activeProfileId;
  final DateTime? shippedAt;
  final DateTime? claimedAt;
  final DateTime? activationStartedAt;
  final DateTime? activationCompletedAt;
  final DateTime? disabledAt;
  final String? disabledReason;
  final Map<String, dynamic> metadata;

  const PhysicalCardModel({
    required this.id,
    this.batchId,
    this.productTypeId,
    this.productTypeName,
    this.productTypeCode,
    required this.serialNumber,
    this.nfcUid,
    this.printedName,
    this.printedDesignUrl,
    required this.status,
    this.activationMode = 'token',
    this.ownerUserId,
    this.activeProfileId,
    this.shippedAt,
    this.claimedAt,
    this.activationStartedAt,
    this.activationCompletedAt,
    this.disabledAt,
    this.disabledReason,
    this.metadata = const {},
  });

  factory PhysicalCardModel.fromJson(Map<String, dynamic> json) {
    final productType = json['product_types'] is Map
        ? Map<String, dynamic>.from(json['product_types'] as Map)
        : const <String, dynamic>{};
    return PhysicalCardModel(
      id: json['id'] as String,
      batchId: json['batch_id'] as String?,
      productTypeId: json['product_type_id'] as String?,
      productTypeName: productType['name'] as String?,
      productTypeCode: productType['code'] as String?,
      serialNumber: json['serial_number'] as String? ?? '',
      nfcUid: json['nfc_uid'] as String?,
      printedName: json['printed_name'] as String?,
      printedDesignUrl: json['printed_design_url'] as String?,
      status: json['status'] as String? ?? 'inventory',
      activationMode: json['activation_mode'] as String? ?? 'token',
      ownerUserId: json['owner_user_id'] as String?,
      activeProfileId: json['active_profile_id'] as String?,
      shippedAt: _dt(json['shipped_at']),
      claimedAt: _dt(json['claimed_at']),
      activationStartedAt: _dt(json['activation_started_at']),
      activationCompletedAt: _dt(json['activation_completed_at']),
      disabledAt: _dt(json['disabled_at']),
      disabledReason: json['disabled_reason'] as String?,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  bool get isClaimed => status == 'claimed';
  bool get cannotBeClaimed =>
      status == 'claimed' ||
      status == 'disabled' ||
      status == 'lost' ||
      status == 'replaced';
  String get productLabel =>
      productTypeName ??
      metadata['product_name']?.toString() ??
      metadata['product_type']?.toString() ??
      productTypeCode ??
      'Tarjeta Taploe';
}

enum AccessResolutionAction {
  activate,
  openProfile,
  redirectExternal,
  disabled,
  notFound,
}

class AccessResolutionModel {
  final ProfileAccessPointModel? accessPoint;
  final PhysicalCardModel? physicalCard;
  final DigitalProfileModel? profile;
  final bool requiresAuth;
  final AccessResolutionAction action;

  const AccessResolutionModel({
    this.accessPoint,
    this.physicalCard,
    this.profile,
    this.requiresAuth = false,
    required this.action,
  });
}

class ActivationResultModel {
  final bool success;
  final String? profileId;
  final String? physicalCardId;
  final String? publicSlug;
  final String? channel;
  final String? message;

  const ActivationResultModel({
    required this.success,
    this.profileId,
    this.physicalCardId,
    this.publicSlug,
    this.channel,
    this.message,
  });

  factory ActivationResultModel.fromJson(Map<String, dynamic> json) =>
      ActivationResultModel(
        success: json['success'] as bool? ?? false,
        profileId: json['profile_id'] as String?,
        physicalCardId: json['physical_card_id'] as String?,
        publicSlug: json['public_slug'] as String?,
        channel: json['channel'] as String?,
        message: json['message']?.toString(),
      );
}

class SmartFormModel {
  final String id;
  final String profileId;
  final String formKey;
  final String name;
  final String? description;
  final bool isActive;
  final String? successMessage;
  final List<String> notifyEmails;

  const SmartFormModel({
    required this.id,
    required this.profileId,
    required this.formKey,
    required this.name,
    this.description,
    this.isActive = true,
    this.successMessage,
    this.notifyEmails = const [],
  });

  factory SmartFormModel.fromJson(Map<String, dynamic> json) => SmartFormModel(
    id: json['id'] as String,
    profileId: json['profile_id'] as String? ?? '',
    formKey: json['form_key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    successMessage: json['success_message'] as String?,
    notifyEmails: json['notify_emails'] is List
        ? (json['notify_emails'] as List).map((e) => '$e').toList()
        : const [],
  );

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'form_key': formKey,
    'name': name,
    'description': description,
    'is_active': isActive,
    'success_message': successMessage,
    'notify_emails': notifyEmails,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class SmartFormFieldModel {
  final String id;
  final String formId;
  final String fieldKey;
  final String fieldType;
  final String label;
  final String? placeholder;
  final String? helpText;
  final bool isRequired;
  final int sortOrder;
  final dynamic options;
  final Map<String, dynamic> validationRules;

  const SmartFormFieldModel({
    required this.id,
    required this.formId,
    required this.fieldKey,
    required this.fieldType,
    required this.label,
    this.placeholder,
    this.helpText,
    this.isRequired = false,
    this.sortOrder = 0,
    this.options,
    this.validationRules = const {},
  });

  factory SmartFormFieldModel.fromJson(Map<String, dynamic> json) =>
      SmartFormFieldModel(
        id: json['id'] as String,
        formId: json['form_id'] as String? ?? '',
        fieldKey: json['field_key'] as String? ?? '',
        fieldType: json['field_type'] as String? ?? 'text',
        label: json['label'] as String? ?? '',
        placeholder: json['placeholder'] as String?,
        helpText: json['help_text'] as String?,
        isRequired: json['is_required'] as bool? ?? false,
        sortOrder: _int(json['sort_order']),
        options: json['options'],
        validationRules: json['validation_rules'] is Map
            ? Map<String, dynamic>.from(json['validation_rules'] as Map)
            : const {},
      );
}

class UserIntegrationModel {
  final String id;
  final String userId;
  final String integrationType;
  final String provider;
  final String? publicUrl;
  final String status;

  const UserIntegrationModel({
    required this.id,
    required this.userId,
    required this.integrationType,
    required this.provider,
    this.publicUrl,
    this.status = 'active',
  });

  factory UserIntegrationModel.fromJson(Map<String, dynamic> json) =>
      UserIntegrationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String? ?? '',
        integrationType: json['integration_type'] as String? ?? 'calendar',
        provider: json['provider'] as String? ?? '',
        publicUrl: json['public_url'] as String?,
        status: json['status'] as String? ?? 'active',
      );
}

class ProfileIntegrationModel {
  final String id;
  final String profileId;
  final String integrationId;
  final bool isEnabled;
  final String? displayLabel;
  final int sortOrder;
  final UserIntegrationModel? integration;

  const ProfileIntegrationModel({
    required this.id,
    required this.profileId,
    required this.integrationId,
    this.isEnabled = true,
    this.displayLabel,
    this.sortOrder = 0,
    this.integration,
  });

  factory ProfileIntegrationModel.fromJson(Map<String, dynamic> json) {
    final integrationRaw = json['user_integrations'];
    return ProfileIntegrationModel(
      id: json['id'] as String,
      profileId: json['profile_id'] as String? ?? '',
      integrationId: json['integration_id'] as String? ?? '',
      isEnabled: json['is_enabled'] as bool? ?? true,
      displayLabel: json['display_label'] as String?,
      sortOrder: _int(json['sort_order']),
      integration: integrationRaw is Map
          ? UserIntegrationModel.fromJson(
              Map<String, dynamic>.from(integrationRaw),
            )
          : null,
    );
  }
}

class LeadModel {
  final String id;
  final String profileId;
  final String? orgId;
  final String? ownerUserId;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? company;
  final String status;
  final int score;
  final String? sourceChannel;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

  const LeadModel({
    required this.id,
    required this.profileId,
    this.orgId,
    this.ownerUserId,
    this.fullName,
    this.email,
    this.phone,
    this.company,
    this.status = 'new',
    this.score = 0,
    this.sourceChannel,
    this.firstSeenAt,
    this.lastSeenAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) => LeadModel(
    id: json['id'] as String,
    profileId: json['profile_id'] as String? ?? '',
    orgId: json['org_id'] as String?,
    ownerUserId: json['owner_user_id'] as String?,
    fullName: json['full_name'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    company: json['company'] as String?,
    status: json['status'] as String? ?? 'new',
    score: _int(json['score']),
    sourceChannel: json['source_channel'] as String?,
    firstSeenAt: _dt(json['first_seen_at']),
    lastSeenAt: _dt(json['last_seen_at']),
  );

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty)
      ? fullName!
      : 'Lead sin nombre';
}

class AnalyticsSummaryModel {
  final int profileViews;
  final int nfcViews;
  final int qrViews;
  final int directViews;
  final int linkClicks;
  final int contactsSaved;
  final int formSubmits;
  final List<int> viewsByDay;
  final Map<String, int> clicksByLabel;

  const AnalyticsSummaryModel({
    required this.profileViews,
    required this.nfcViews,
    required this.qrViews,
    required this.directViews,
    required this.linkClicks,
    required this.contactsSaved,
    required this.formSubmits,
    required this.viewsByDay,
    required this.clicksByLabel,
  });
}

class TeamActivityModel {
  final AnalyticsEventModel event;
  final String memberName;
  final String profileName;

  const TeamActivityModel({
    required this.event,
    required this.memberName,
    required this.profileName,
  });
}

class AnalyticsEventModel {
  final String id;
  final String? leadId;
  final String? linkId;
  final String? linkLabel;
  final String? formId;
  final String? formSubmissionId;
  final String eventType;
  final String accessChannel;
  final String? city;
  final String? region;
  final String? country;
  final Map<String, dynamic> metadata;
  final DateTime? occurredAt;

  const AnalyticsEventModel({
    required this.id,
    this.leadId,
    this.linkId,
    this.linkLabel,
    this.formId,
    this.formSubmissionId,
    required this.eventType,
    required this.accessChannel,
    this.city,
    this.region,
    this.country,
    this.metadata = const {},
    this.occurredAt,
  });

  factory AnalyticsEventModel.fromJson(Map<String, dynamic> json) =>
      AnalyticsEventModel(
        id: json['id'] as String,
        leadId: json['lead_id'] as String?,
        linkId: json['link_id'] as String?,
        linkLabel: _joinedLabel(json['profile_links']),
        formId: json['form_id'] as String?,
        formSubmissionId: json['form_submission_id'] as String?,
        eventType: json['event_type'] as String? ?? '',
        accessChannel: json['access_channel'] as String? ?? 'direct',
        city: json['city'] as String?,
        region: json['region'] as String?,
        country: json['country'] as String?,
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
        occurredAt: _dt(json['occurred_at']),
      );
}

String? _joinedLabel(dynamic value) {
  if (value is Map) return value['label'] as String?;
  if (value is List && value.isNotEmpty && value.first is Map) {
    return (value.first as Map)['label'] as String?;
  }
  return null;
}

class LeadEventModel {
  final String id;
  final String leadId;
  final String profileId;
  final String eventType;
  final int points;
  final String? notes;
  final DateTime? occurredAt;

  const LeadEventModel({
    required this.id,
    required this.leadId,
    required this.profileId,
    required this.eventType,
    this.points = 0,
    this.notes,
    this.occurredAt,
  });

  factory LeadEventModel.fromJson(Map<String, dynamic> json) => LeadEventModel(
    id: json['id'] as String,
    leadId: json['lead_id'] as String? ?? '',
    profileId: json['profile_id'] as String? ?? '',
    eventType: json['event_type'] as String? ?? '',
    points: _int(json['points']),
    notes: json['notes'] as String?,
    occurredAt: _dt(json['occurred_at']),
  );
}

class FormSubmissionModel {
  final String id;
  final String formId;
  final String profileId;
  final String? leadId;
  final Map<String, dynamic> data;
  final DateTime? submittedAt;

  const FormSubmissionModel({
    required this.id,
    required this.formId,
    required this.profileId,
    this.leadId,
    this.data = const {},
    this.submittedAt,
  });

  factory FormSubmissionModel.fromJson(Map<String, dynamic> json) =>
      FormSubmissionModel(
        id: json['id'] as String,
        formId: json['form_id'] as String? ?? '',
        profileId: json['profile_id'] as String? ?? '',
        leadId: json['lead_id'] as String?,
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : const {},
        submittedAt: _dt(json['submitted_at']),
      );
}

class TeamMemberModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final String? invitationId;
  final String? avatarUrl;
  final int profiles;
  final int views;
  final int nfc;
  final int qr;
  final int clicks;
  final int cards;
  final int leads;

  const TeamMemberModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status = 'active',
    this.invitationId,
    this.avatarUrl,
    this.profiles = 0,
    this.views = 0,
    this.nfc = 0,
    this.qr = 0,
    this.clicks = 0,
    this.cards = 0,
    this.leads = 0,
  });

  bool get isPending => status == 'pending';
}
