import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../localization.dart';
import '../plan_capabilities.dart';
import '../profile_public_card.dart';
import '../repositories.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../vcard_launcher.dart';
import '../widgets.dart';

class PublicProfileView extends StatefulWidget {
  final String slug;

  const PublicProfileView({super.key, required this.slug});

  @override
  State<PublicProfileView> createState() => _PublicProfileViewState();
}

class _PublicProfileViewState extends State<PublicProfileView> {
  DigitalProfileModel? profile;
  List<SmartFormModel> forms = [];
  Map<String, List<SmartFormFieldModel>> fieldsByFormId = {};
  List<ProfileIntegrationModel> integrations = [];
  TaploePlanCapabilities capabilities = const TaploePlanCapabilities(
    TaploePlan.free,
  );
  bool loading = true;
  bool loggedDirectView = false;

  String? get channel => Uri.base.queryParameters['channel'];
  String? get accessPointId => Uri.base.queryParameters['ap'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    DigitalProfileModel? p;
    try {
      p = await ProfileRepository.fetchProfileBySlug(widget.slug);
    } catch (error) {
      safePrintError(error);
    }
    if (p != null) {
      if (!mounted) return;
      setState(() {
        profile = p;
        loading = false;
      });
      unawaited(_loadSecondaryProfileData(p));
      unawaited(_logDirectProfileView(p.id));
      return;
    }
    if (!mounted) return;
    setState(() {
      profile = null;
      loading = false;
    });
  }

  Future<void> _loadSecondaryProfileData(DigitalProfileModel p) async {
    var profileCapabilities = const TaploePlanCapabilities(TaploePlan.free);
    var nextForms = <SmartFormModel>[];
    var nextFieldsByFormId = <String, List<SmartFormFieldModel>>{};
    var nextIntegrations = <ProfileIntegrationModel>[];

    try {
      profileCapabilities =
          await ProfileRepository.fetchPublicCapabilitiesForProfile(p);
    } catch (error) {
      safePrintError(error);
    }

    try {
      nextForms = await SmartFormRepository.fetchPublicActiveForms(p.id);
      final formFields = await Future.wait(
        nextForms.map((form) async {
          try {
            return await SmartFormRepository.fetchPublicFields(form.id);
          } catch (error) {
            safePrintError(error);
            return <SmartFormFieldModel>[];
          }
        }),
      );
      nextFieldsByFormId = {
        for (var i = 0; i < nextForms.length; i++)
          nextForms[i].id: formFields[i],
      };
    } catch (error) {
      safePrintError(error);
    }

    try {
      nextIntegrations = await IntegrationRepository.fetchPublicForProfile(
        profileId: p.id,
      );
    } catch (error) {
      safePrintError(error);
    }

    if (!mounted || profile?.id != p.id) return;
    setState(() {
      capabilities = profileCapabilities;
      forms = nextForms;
      fieldsByFormId = nextFieldsByFormId;
      integrations = nextIntegrations;
    });
  }

  Future<void> _logDirectProfileView(String profileId) async {
    if (channel != null || loggedDirectView) return;
    loggedDirectView = true;
    await SessionStorage.saveVisitorAttribution(
      accessPointId: 'direct',
      channel: 'direct',
      profileId: profileId,
    );
    try {
      await AnalyticsRepository.insertEvent(
        profileId: profileId,
        eventType: 'profile_view',
        channel: 'direct',
      );
    } catch (error) {
      safePrintError(error);
    }
  }

  Future<void> _openLink(ProfileLinkModel link) async {
    final p = profile;
    if (p == null) return;
    final uri = _uriForProfileLink(link);
    if (uri == null) {
      taploeToast(
        context,
        'Este enlace no tiene información válida.',
        error: true,
      );
      return;
    }
    unawaited(
      AnalyticsRepository.insertEvent(
        profileId: p.id,
        accessPointId: accessPointId,
        linkId: link.id,
        eventType: link.linkType == 'calendar'
            ? 'calendar_click'
            : 'link_click',
        channel: channel ?? 'direct',
        metadata: {'label': link.label, 'type': link.linkType},
      ).catchError(safePrintError),
    );
    if (!await _launchProfileUri(uri)) {
      if (!mounted) return;
      taploeToast(context, 'No se pudo abrir este enlace.', error: true);
    }
  }

  Future<void> _openIntegration(ProfileIntegrationModel integration) async {
    final p = profile;
    if (p == null) return;
    final raw = integration.integration?.publicUrl;
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null) return;
    unawaited(
      AnalyticsRepository.insertEvent(
        profileId: p.id,
        accessPointId: accessPointId,
        eventType: integration.integration?.integrationType == 'calendar'
            ? 'calendar_click'
            : 'integration_click',
        channel: channel ?? 'direct',
        metadata: {
          'label': integration.displayLabel,
          'provider': integration.integration?.provider,
          'type': integration.integration?.integrationType,
        },
      ).catchError(safePrintError),
    );
    if (!await _launchProfileUri(uri)) {
      if (!mounted) return;
      taploeToast(context, 'No se pudo abrir esta integración.', error: true);
    }
  }

  Future<void> _saveContact() async {
    final p = profile;
    if (p == null) return;
    final vcf = (p.vcard ?? ProfileVcardModel(profileId: p.id)).toVcf(
      displayName: p.displayName,
      profilePhotoUrl: p.profilePhotoUrl,
    );
    unawaited(
      AnalyticsRepository.insertEvent(
        profileId: p.id,
        accessPointId: accessPointId,
        eventType: 'contact_save',
        channel: channel ?? 'direct',
      ).catchError(safePrintError),
    );
    final opened = await openVcardFile(
      contents: vcf,
      displayName: p.displayName,
    );
    final t = TaploeTextCatalog(
      TaploeLocaleConfig.fromLocaleParam(p.publicLocale),
    );
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: vcf));
    if (mounted) {
      taploeToast(context, '${t.vcardCopied} No se pudo abrir el archivo.');
    }
  }

  Future<void> _shareProfile() async {
    await Clipboard.setData(ClipboardData(text: Uri.base.toString()));
    final p = profile;
    final t = TaploeTextCatalog(
      TaploeLocaleConfig.fromLocaleParam(p?.publicLocale),
    );
    if (mounted) taploeToast(context, t.linkCopied);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = profile;
    if (p == null) {
      final t = taploeState.t;
      return Scaffold(
        body: Center(
          child: TaploeEmpty(
            title: t.profileUnavailable,
            message: t.profileUnavailableMessage,
          ),
        ),
      );
    }
    final links = p.links.where((link) => link.isVisible).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final hasStoredIdentity =
        p.logoUrl?.trim().isNotEmpty == true ||
        p.coverPhotoUrl?.trim().isNotEmpty == true ||
        p.theme != null;
    final canShowPublicForms = capabilities.canUseForms || forms.isNotEmpty;
    final canShowPublicIntegrations =
        capabilities.canUseIntegrations || integrations.isNotEmpty;

    return Scaffold(
      backgroundColor: TaploeColors.page,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: TaploePublicProfileCard(
                profile: p,
                links: links,
                forms: forms,
                integrations: integrations,
                framed: false,
                allowVerifiedBadge: capabilities.canShowVerifiedBadge,
                allowCustomDesign:
                    capabilities.canUseDesign || hasStoredIdentity,
                allowForms: canShowPublicForms,
                allowIntegrations: canShowPublicIntegrations,
                showTaploeWatermark: !capabilities.canRemoveTaploeWatermark,
                onSaveContact: _saveContact,
                onShare: _shareProfile,
                onOpenLink: _openLink,
                onOpenIntegration: _openIntegration,
                formBuilder: (form) => _InlineSmartForm(
                  form: form,
                  fields: fieldsByFormId[form.id] ?? const [],
                  profile: p,
                  channel: channel ?? 'direct',
                  accessPointId: accessPointId,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _launchProfileUri(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return true;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    safePrintError(error);
    return false;
  }
}

Uri? _uriForProfileLink(ProfileLinkModel link) {
  final raw = (link.url?.trim().isNotEmpty == true ? link.url : link.value)
      ?.trim();
  if (raw == null || raw.isEmpty) return null;

  final normalized = switch (link.linkType) {
    'phone' => raw.startsWith('tel:') ? raw : 'tel:${_cleanPhone(raw)}',
    'email' => raw.startsWith('mailto:') ? raw : 'mailto:$raw',
    'whatsapp' => _whatsappUrl(raw),
    'maps' => _mapsUrl(raw),
    'instagram' => _socialUrl(raw, 'https://instagram.com/'),
    'facebook' => _socialUrl(raw, 'https://facebook.com/'),
    'linkedin' => _socialUrl(raw, 'https://linkedin.com/in/'),
    'tiktok' =>
      raw.startsWith('http')
          ? raw
          : 'https://tiktok.com/@${raw.replaceAll('@', '')}',
    'youtube' => _socialUrl(raw, 'https://youtube.com/'),
    'x' => _socialUrl(raw, 'https://x.com/'),
    _ => _ensureWebUrl(raw),
  };
  if (normalized.isEmpty) return null;
  return Uri.tryParse(normalized);
}

String _cleanPhone(String value) => value.replaceAll(RegExp(r'[^0-9+]'), '');

String _ensureWebUrl(String value) {
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

String _whatsappUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http')) return trimmed;
  final phone = _cleanPhone(trimmed).replaceAll('+', '');
  return phone.isEmpty ? '' : 'https://wa.me/$phone';
}

String _mapsUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http')) return trimmed;
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(trimmed)}';
}

String _socialUrl(String value, String baseUrl) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http')) return trimmed;
  return '$baseUrl${trimmed.replaceAll('@', '')}';
}

class _InlineSmartForm extends StatefulWidget {
  final SmartFormModel form;
  final List<SmartFormFieldModel> fields;
  final DigitalProfileModel profile;
  final String channel;
  final String? accessPointId;

  const _InlineSmartForm({
    required this.form,
    required this.fields,
    required this.profile,
    required this.channel,
    this.accessPointId,
  });

  @override
  State<_InlineSmartForm> createState() => _InlineSmartFormState();
}

class _InlineSmartFormState extends State<_InlineSmartForm> {
  final Map<String, TextEditingController> controllers = {};
  bool loading = false;

  List<SmartFormFieldModel> get fields {
    final t = TaploeTextCatalog(
      TaploeLocaleConfig.fromLocaleParam(widget.profile.publicLocale),
    );
    if (widget.fields.isNotEmpty) {
      return [...widget.fields]..sort(_compareFormFields);
    }
    return [
      SmartFormFieldModel(
        id: 'fallback-name',
        formId: widget.form.id,
        fieldKey: 'name',
        fieldType: 'text',
        label: t.text('Nombre', 'Name'),
        placeholder: t.text('Nombre', 'Name'),
        isRequired: true,
        sortOrder: 1,
      ),
      SmartFormFieldModel(
        id: 'fallback-email',
        formId: widget.form.id,
        fieldKey: 'email',
        fieldType: 'email',
        label: t.text('Correo', 'Email'),
        placeholder: t.text('Correo', 'Email'),
        isRequired: true,
        sortOrder: 2,
      ),
      SmartFormFieldModel(
        id: 'fallback-phone',
        formId: widget.form.id,
        fieldKey: 'phone',
        fieldType: 'phone',
        label: t.text('Teléfono', 'Phone'),
        placeholder: t.text('Teléfono', 'Phone'),
        sortOrder: 3,
      ),
    ];
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController controllerFor(SmartFormFieldModel field) {
    return controllers.putIfAbsent(field.fieldKey, TextEditingController.new);
  }

  Future<void> submit() async {
    final t = TaploeTextCatalog(
      TaploeLocaleConfig.fromLocaleParam(widget.profile.publicLocale),
    );
    final values = <String, dynamic>{
      for (final field in fields)
        field.fieldKey: controllerFor(field).text.trim(),
      'form_key': widget.form.formKey,
    };
    final missingRequired = fields.any(
      (field) =>
          field.isRequired &&
          (values[field.fieldKey]?.toString().trim().isEmpty ?? true),
    );
    if (missingRequired) {
      taploeToast(
        context,
        t.text(
          'Completa los campos requeridos.',
          'Complete the required fields.',
        ),
        error: true,
      );
      return;
    }
    final hasAnyContact = fields.any(
      (field) => controllerFor(field).text.trim().isNotEmpty,
    );
    if (!hasAnyContact) {
      taploeToast(
        context,
        t.text(
          'Agrega al menos un dato de contacto.',
          'Add at least one contact detail.',
        ),
        error: true,
      );
      return;
    }
    setState(() => loading = true);
    try {
      await SmartFormRepository.submit(
        form: widget.form,
        profile: widget.profile,
        data: values,
        channel: widget.channel,
        accessPointId: widget.accessPointId,
      );
      if (!mounted) return;
      taploeToast(context, t.text('Información enviada.', 'Information sent.'));
      for (final controller in controllers.values) {
        controller.clear();
      }
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          t.text(
            'No pudimos enviar la información. Intenta de nuevo.',
            'We could not send the information. Try again.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TaploeTextCatalog(
      TaploeLocaleConfig.fromLocaleParam(widget.profile.publicLocale),
    );
    final submitStyle = _PublicSubmitButtonStyle.fromProfile(widget.profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in fields) ...[
          Builder(
            builder: (context) {
              final label = _localizedFieldLabel(field, t);
              return TextField(
                controller: controllerFor(field),
                keyboardType: _keyboardTypeFor(field.fieldType),
                textInputAction: field.fieldType == 'textarea'
                    ? TextInputAction.newline
                    : TextInputAction.next,
                minLines: field.fieldType == 'textarea' ? 3 : 1,
                maxLines: field.fieldType == 'textarea' ? 5 : 1,
                onSubmitted: (_) {
                  if (!loading) submit();
                },
                decoration: InputDecoration(
                  hintText: _localizedFieldPlaceholder(field, t),
                  labelText: field.isRequired ? '$label *' : label,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        _PublicFormSubmitButton(
          label: t.submitForm,
          loading: loading,
          style: submitStyle,
          onPressed: submit,
        ),
      ],
    );
  }
}

class _PublicFormSubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final _PublicSubmitButtonStyle style;
  final VoidCallback? onPressed;

  const _PublicFormSubmitButton({
    required this.label,
    required this.loading,
    required this.style,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final background = loading
        ? style.background.withValues(alpha: .64)
        : style.background;
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(background),
          foregroundColor: WidgetStatePropertyAll(style.foreground),
          side: WidgetStatePropertyAll(BorderSide(color: style.background)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(style.radius),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18),
          ),
          textStyle: WidgetStatePropertyAll(
            _publicSubmitFont(
              style.fontFamily,
              color: style.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: style.foreground,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_rounded, size: 19, color: style.foreground),
                  const SizedBox(width: 9),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, maxLines: 1),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PublicSubmitButtonStyle {
  final Color background;
  final Color foreground;
  final double radius;
  final String fontFamily;

  const _PublicSubmitButtonStyle({
    required this.background,
    required this.foreground,
    required this.radius,
    required this.fontFamily,
  });

  factory _PublicSubmitButtonStyle.fromProfile(DigitalProfileModel profile) {
    final theme = profile.theme ?? ProfileThemeModel(profileId: profile.id);
    final primaryColor = _publicColorFromHex(
      theme.primaryColor,
      fallback: TaploeColors.blue,
    );
    final accentColor = _publicColorFromHex(
      theme.accentColor,
      fallback: primaryColor,
    );
    final backgroundColor = _publicColorFromHex(
      theme.backgroundColorStart,
      fallback: TaploeColors.white,
    );
    final actionColor = _bestPublicActionColor(
      primaryColor: primaryColor,
      accentColor: accentColor,
      backgroundColor: backgroundColor,
    );
    final foreground = actionColor.computeLuminance() > .62
        ? TaploeColors.black
        : TaploeColors.white;
    final radius = switch (theme.buttonStyle) {
      'square' => 10.0,
      'rounded' => 18.0,
      _ => 999.0,
    };

    return _PublicSubmitButtonStyle(
      background: actionColor,
      foreground: foreground,
      radius: radius,
      fontFamily: theme.fontFamily,
    );
  }
}

const _publicFormFieldOrder = {
  'name': 0,
  'email': 1,
  'phone': 2,
  'company': 3,
  'message': 4,
  'budget': 5,
  'date': 6,
};

int _compareFormFields(SmartFormFieldModel a, SmartFormFieldModel b) {
  final aOrder = a.sortOrder > 0
      ? a.sortOrder
      : (_publicFormFieldOrder[a.fieldKey] ?? 999);
  final bOrder = b.sortOrder > 0
      ? b.sortOrder
      : (_publicFormFieldOrder[b.fieldKey] ?? 999);
  final order = aOrder.compareTo(bOrder);
  if (order != 0) return order;
  return a.label.compareTo(b.label);
}

TextInputType _keyboardTypeFor(String type) {
  switch (type) {
    case 'email':
      return TextInputType.emailAddress;
    case 'phone':
      return TextInputType.phone;
    case 'number':
      return TextInputType.number;
    case 'textarea':
      return TextInputType.multiline;
    case 'date':
      return TextInputType.datetime;
    default:
      return TextInputType.text;
  }
}

String _fieldPlaceholder(SmartFormFieldModel field) {
  final placeholder = field.placeholder?.trim();
  if (placeholder != null && placeholder.isNotEmpty) return placeholder;
  return field.label;
}

String _localizedFieldLabel(SmartFormFieldModel field, TaploeTextCatalog t) {
  final known = _knownPublicField(field);
  if (known == null) return field.label;
  return _publicFieldLabel(known, t);
}

String _localizedFieldPlaceholder(
  SmartFormFieldModel field,
  TaploeTextCatalog t,
) {
  final known = _knownPublicField(field);
  if (known == null) return _fieldPlaceholder(field);
  return _publicFieldPlaceholder(known, t);
}

String? _knownPublicField(SmartFormFieldModel field) {
  final key = _normalizePublicFieldText(field.fieldKey);
  final label = _normalizePublicFieldText(field.label);
  final type = _normalizePublicFieldText(field.fieldType);

  if (key == 'name' ||
      key == 'nombre' ||
      key == 'full_name' ||
      key == 'fullname' ||
      label == 'nombre' ||
      label == 'nombre_completo') {
    return 'name';
  }
  if (key == 'email' ||
      key == 'correo' ||
      key == 'correo_electronico' ||
      label == 'email' ||
      label == 'correo' ||
      label == 'correo_electronico' ||
      type == 'email') {
    return 'email';
  }
  if (key == 'phone' ||
      key == 'telefono' ||
      key == 'tel' ||
      label == 'telefono' ||
      type == 'phone') {
    return 'phone';
  }
  if (key == 'company' ||
      key == 'empresa' ||
      label == 'empresa' ||
      label == 'nombre_de_tu_empresa') {
    return 'company';
  }
  if (key == 'message' || key == 'mensaje' || label == 'mensaje') {
    return 'message';
  }
  if (key == 'budget' || key == 'presupuesto' || label == 'presupuesto') {
    return 'budget';
  }
  if (key == 'date' || key == 'fecha' || label == 'fecha' || type == 'date') {
    return 'date';
  }
  return null;
}

String _publicFieldLabel(String key, TaploeTextCatalog t) {
  switch (key) {
    case 'name':
      return t.text('Nombre', 'Name');
    case 'email':
      return t.text('Correo', 'Email');
    case 'phone':
      return t.text('Teléfono', 'Phone');
    case 'company':
      return t.text('Empresa', 'Company');
    case 'message':
      return t.text('Mensaje', 'Message');
    case 'budget':
      return t.text('Presupuesto', 'Budget');
    case 'date':
      return t.text('Fecha', 'Date');
    default:
      return key;
  }
}

String _publicFieldPlaceholder(String key, TaploeTextCatalog t) {
  switch (key) {
    case 'name':
      return t.text('Tu nombre', 'Your name');
    case 'email':
      return t.text('tu@ejemplo.com', 'you@example.com');
    case 'phone':
      return t.text('+52 664 123 4567', '+1 555 123 4567');
    case 'company':
      return t.text('Nombre de tu empresa', 'Company name');
    case 'message':
      return t.text(
        'Cuéntanos en qué podemos ayudarte',
        'Tell us how we can help',
      );
    case 'budget':
      return t.text('Ej. \$10,000 MXN', 'E.g. \$1,000 USD');
    case 'date':
      return t.text('Selecciona una fecha', 'Select a date');
    default:
      return key;
  }
}

String _normalizePublicFieldText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

Color _publicColorFromHex(String value, {required Color fallback}) {
  final clean = value.replaceAll('#', '').trim();
  if (clean.length != 6) return fallback;
  final parsed = int.tryParse('FF$clean', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

Color _bestPublicActionColor({
  required Color primaryColor,
  required Color accentColor,
  required Color backgroundColor,
}) {
  if (_publicContrastRatio(primaryColor, backgroundColor) >= 3) {
    return primaryColor;
  }
  if (_publicContrastRatio(accentColor, backgroundColor) >= 3) {
    return accentColor;
  }
  return backgroundColor.computeLuminance() > .5
      ? TaploeColors.black
      : TaploeColors.white;
}

double _publicContrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + .05) / (darker + .05);
}

TextStyle _publicSubmitFont(
  String family, {
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
}) {
  switch (family) {
    case 'poppins':
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    case 'montserrat':
      return GoogleFonts.montserrat(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    default:
      return fontWeight.value >= FontWeight.w600.value
          ? GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            )
          : GoogleFonts.dmSans(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            );
  }
}
