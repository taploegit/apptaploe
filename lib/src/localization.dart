import 'package:flutter/widgets.dart';

enum TaploeMarket { mx, us }

class TaploeLocaleConfig {
  final String languageCode;
  final TaploeMarket market;

  const TaploeLocaleConfig._({
    required this.languageCode,
    required this.market,
  });

  static const esMx = TaploeLocaleConfig._(
    languageCode: 'es',
    market: TaploeMarket.mx,
  );
  static const enUs = TaploeLocaleConfig._(
    languageCode: 'en',
    market: TaploeMarket.us,
  );

  static TaploeLocaleConfig fromParts({String? language, String? market}) {
    final lang = language?.trim().toLowerCase();
    final mkt = market?.trim().toLowerCase();
    if (mkt == 'us') return enUs;
    if (mkt == 'mx') return esMx;
    if (lang == 'en') return enUs;
    return esMx;
  }

  static TaploeLocaleConfig fromLocaleParam(String? raw) {
    final value = raw?.trim().toLowerCase();
    return switch (value) {
      'en-us' || 'en_us' || 'us' || 'en' => enUs,
      'es-mx' || 'es_mx' || 'mx' || 'es' => esMx,
      _ => esMx,
    };
  }

  String get marketCode => market == TaploeMarket.us ? 'us' : 'mx';
  String get localeCode => market == TaploeMarket.us ? 'en-US' : 'es-MX';
  String get currencyCode => market == TaploeMarket.us ? 'USD' : 'MXN';
  Locale get flutterLocale => Locale(languageCode, marketCode.toUpperCase());
  bool get isEnglish => languageCode == 'en';
}

class TaploeTextCatalog {
  final TaploeLocaleConfig locale;

  const TaploeTextCatalog(this.locale);

  bool get en => locale.isEnglish;
  String get code => locale.localeCode;
  String get languageLabel => en ? 'English' : 'Español';
  String get marketLabel => en ? 'United States' : 'México';
  String get currencyCode => locale.currencyCode;

  String text(String es, String enText) => en ? enText : es;

  String get home => text('Inicio', 'Home');
  String get digitalProfile => text('Perfil digital', 'Digital profile');
  String get cards => text('Tarjetas', 'Cards');
  String get share => text('Compartir', 'Share');
  String get analytics => text('Analítica', 'Analytics');
  String get leads => text('Leads', 'Leads');
  String get team => text('Equipo', 'Team');
  String get administration => text('Administración', 'Administration');
  String get settings => text('Configuración', 'Settings');
  String get create => text('Crear', 'Create');
  String get saveChanges => text('Guardar cambios', 'Save changes');
  String get save => text('Guardar', 'Save');
  String get currentPlan => text('Plan actual', 'Current plan');
  String get billing => text('Facturación', 'Billing');
  String get changePlan => text('Cambiar plan', 'Change plan');
  String get manageSubscription =>
      text('Administrar suscripción', 'Manage subscription');
  String get cancel => text('Cancelar', 'Cancel');
  String get resume => text('Reanudar', 'Resume');
  String get paymentHistory => text('Historial de pagos', 'Payment history');
  String get noInvoices => text(
    'Aún no hay pagos o facturas registradas.',
    'No payments or invoices yet.',
  );
  String get choosePlan => text('Elige tu plan', 'Choose your plan');
  String get continueToStripe =>
      text('Continuar a Stripe', 'Continue to Stripe');
  String get openingStripe => text('Abriendo Stripe...', 'Opening Stripe...');
  String get monthly => text('Mensual', 'Monthly');
  String get annual => text('Anual', 'Annual');
  String get perMonth => text('al mes', 'per month');
  String get perYear => text('al año', 'per year');
  String get perProfilePerMonth =>
      text('por perfil al mes', 'per profile per month');
  String get perProfilePerYear =>
      text('por perfil al año', 'per profile per year');
  String get localeAndMarket => text('Idioma y mercado', 'Language and market');
  String get interfaceLanguage =>
      text('Idioma de la plataforma', 'Platform language');
  String get marketAndCurrency =>
      text('Mercado y moneda', 'Market and currency');
  String get spanishMexico =>
      text('Español / México / MXN', 'Spanish / Mexico / MXN');
  String get englishUs =>
      text('Inglés / Estados Unidos / USD', 'English / United States / USD');
  String get saveContact => text('Guardar contacto', 'Save contact');
  String get sendMail => text('Enviar correo', 'Send mail');
  String get connectWithMe => text('Conecta conmigo', 'Connect with me');
  String get contact => text('Contacto', 'Contact');
  String get scheduleMeeting => text('Agendar reunión', 'Schedule meeting');
  String get tools => text('Herramientas', 'Tools');
  String get contactForm => text('Formulario de contacto', 'Contact form');
  String get profileUnavailable =>
      text('Perfil no disponible', 'Profile unavailable');
  String get profileUnavailableMessage => text(
    'El perfil no existe o fue desactivado.',
    'This profile does not exist or was disabled.',
  );
  String get linkCopied => text('Enlace copiado.', 'Link copied.');
  String get vcardCopied =>
      text('Contacto copiado en formato vCard.', 'Contact copied as vCard.');
  String get checkoutCurrencyNotice => text(
    'Los precios se mostrarán y cobrarán en MXN para México.',
    'Prices will be shown and charged in USD for the United States.',
  );
  String get stripeTruthNotice => text(
    'Stripe administra el método de pago, prueba de 7 días, renovaciones, facturas, reintentos y cancelaciones. Taploe activa beneficios solo cuando el webhook sincroniza la suscripción.',
    'Stripe manages payment methods, the 7-day trial, renewals, invoices, retries, and cancellations. Taploe enables benefits only after the webhook syncs the subscription.',
  );
  String get premiumDescription => text(
    'Plan para profesionales que buscan una identidad digital más completa. Incluye personalización avanzada, analíticas, perfiles sin marca Taploe y hasta 5 perfiles digitales dentro de la misma cuenta.',
    'A plan for professionals seeking a more complete digital identity. Includes advanced customization, analytics, Taploe-free branding, and up to five digital profiles within the same account.',
  );
  String get businessDescription => text(
    'Plan por perfil para equipos de 5 o más integrantes. Centraliza la administración de colaboradores, identidad visual, tarjetas, métricas y leads de toda la empresa.',
    'Per-profile plan for teams of 5 or more members. Centralize employee management, brand identity, cards, analytics, and company-wide leads.',
  );
}

String taploeLocaleFromParts(String language, String market) =>
    TaploeLocaleConfig.fromParts(language: language, market: market).localeCode;
