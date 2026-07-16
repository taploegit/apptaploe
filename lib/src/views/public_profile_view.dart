import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../localization.dart';
import '../plan_capabilities.dart';
import '../profile_public_card.dart';
import '../repositories.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
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
    final p = await ProfileRepository.fetchProfileBySlug(widget.slug);
    if (p != null) {
      final profileCapabilities =
          await ProfileRepository.fetchCapabilitiesForProfile(p);
      final results = await Future.wait<Object>([
        profileCapabilities.canUseForms
            ? SmartFormRepository.fetchActiveForms(p.id)
            : Future<List<SmartFormModel>>.value(const []),
        profileCapabilities.canUseIntegrations
            ? IntegrationRepository.fetchForProfile(profileId: p.id)
            : Future<List<ProfileIntegrationModel>>.value(const []),
      ]);
      forms = results[0] as List<SmartFormModel>;
      integrations = results[1] as List<ProfileIntegrationModel>;
      final formFields = await Future.wait(
        forms.map((form) => SmartFormRepository.fetchFields(form.id)),
      );
      fieldsByFormId = {
        for (var i = 0; i < forms.length; i++) forms[i].id: formFields[i],
      };
      capabilities = profileCapabilities;
      if (channel == null && !loggedDirectView) {
        loggedDirectView = true;
        await SessionStorage.saveVisitorAttribution(
          accessPointId: 'direct',
          channel: 'direct',
          profileId: p.id,
        );
        await AnalyticsRepository.insertEvent(
          profileId: p.id,
          eventType: 'profile_view',
          channel: 'direct',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      profile = p;
      loading = false;
    });
  }

  Future<void> _openLink(ProfileLinkModel link) async {
    final p = profile;
    if (p == null) return;
    await AnalyticsRepository.insertEvent(
      profileId: p.id,
      accessPointId: accessPointId,
      linkId: link.id,
      eventType: link.linkType == 'calendar' ? 'calendar_click' : 'link_click',
      channel: channel ?? 'direct',
      metadata: {'label': link.label, 'type': link.linkType},
    );
    final raw = link.url ?? link.value;
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openIntegration(ProfileIntegrationModel integration) async {
    final p = profile;
    if (p == null) return;
    final raw = integration.integration?.publicUrl;
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null) return;
    await AnalyticsRepository.insertEvent(
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
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _saveContact() async {
    final p = profile;
    if (p == null) return;
    final vcf = (p.vcard ?? ProfileVcardModel(profileId: p.id)).toVcf(
      displayName: p.displayName,
      profilePhotoUrl: p.profilePhotoUrl,
    );
    await Clipboard.setData(ClipboardData(text: vcf));
    await AnalyticsRepository.insertEvent(
      profileId: p.id,
      accessPointId: accessPointId,
      eventType: 'contact_save',
      channel: channel ?? 'direct',
    );
    final t = TaploeTextCatalog(
      TaploeLocaleConfig.fromLocaleParam(p.publicLocale),
    );
    if (mounted) taploeToast(context, t.vcardCopied);
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
                allowCustomDesign: capabilities.canUseDesign,
                allowForms: capabilities.canUseForms,
                allowIntegrations: capabilities.canUseIntegrations,
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
    if (widget.fields.isNotEmpty) {
      return [...widget.fields]..sort(_compareFormFields);
    }
    return [
      SmartFormFieldModel(
        id: 'fallback-name',
        formId: widget.form.id,
        fieldKey: 'name',
        fieldType: 'text',
        label: 'Nombre',
        placeholder: 'Nombre',
        isRequired: true,
        sortOrder: 1,
      ),
      SmartFormFieldModel(
        id: 'fallback-email',
        formId: widget.form.id,
        fieldKey: 'email',
        fieldType: 'email',
        label: 'Correo',
        placeholder: 'Correo',
        isRequired: true,
        sortOrder: 2,
      ),
      SmartFormFieldModel(
        id: 'fallback-phone',
        formId: widget.form.id,
        fieldKey: 'phone',
        fieldType: 'phone',
        label: 'Teléfono',
        placeholder: 'Teléfono',
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
      taploeToast(context, 'Completa los campos requeridos.', error: true);
      return;
    }
    final hasAnyContact = fields.any(
      (field) => controllerFor(field).text.trim().isNotEmpty,
    );
    if (!hasAnyContact) {
      taploeToast(context, 'Agrega al menos un dato de contacto.', error: true);
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
      taploeToast(context, 'Información enviada.');
      for (final controller in controllers.values) {
        controller.clear();
      }
    } catch (error) {
      safePrintError(error);
      if (mounted) {
        taploeToast(
          context,
          'No pudimos enviar la información. Intenta de nuevo.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in fields) ...[
          TextField(
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
              hintText: _fieldPlaceholder(field),
              labelText: field.isRequired ? '${field.label} *' : field.label,
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        TaploeButton(label: 'Enviar', loading: loading, onPressed: submit),
      ],
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
