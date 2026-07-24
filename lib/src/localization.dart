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

  String phrase(String es, [String? enText]) {
    if (!en) return es;
    if (enText != null) return enText;
    return taploeTranslateToEnglish(es);
  }

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
  String get submitForm => text('Enviar', 'Send');
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

String taploeTranslateToEnglish(String value) {
  final translated = _taploeEnglishPhrases[value];
  if (translated != null) return translated;
  for (final entry in _taploeEnglishPatterns) {
    final match = entry.pattern.firstMatch(value);
    if (match != null) return entry.replace(match);
  }
  return value;
}

String _taploeEnglishPlanName(String value) =>
    value.trim().toLowerCase() == 'empresa'
    ? 'Business'
    : taploeTranslateToEnglish(value);

class _TaploeEnglishPattern {
  final RegExp pattern;
  final String Function(RegExpMatch match) replace;

  const _TaploeEnglishPattern(this.pattern, this.replace);
}

final List<_TaploeEnglishPattern> _taploeEnglishPatterns = [
  _TaploeEnglishPattern(
    RegExp(r'^Hola, (.+)\. Elige la ruta pública de tu perfil digital\.$'),
    (match) => 'Hi, ${match.group(1)}. Choose your digital profile public URL.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Hola, (.+)$'),
    (match) => 'Hi, ${match.group(1)}',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Disponible en el plan (.+)\.$'),
    (match) =>
        'Available on the ${_taploeEnglishPlanName(match.group(1) ?? '')} plan.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Plan (.+)$'),
    (match) => '${_taploeEnglishPlanName(match.group(1) ?? '')} plan',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Prueba gratis de ([0-9]+) días, cancela cuando quieras\.$'),
    (match) => '${match.group(1)}-day free trial. Cancel anytime.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Puedes reenviar el código en ([0-9]+)s$'),
    (match) => 'You can resend the code in ${match.group(1)}s',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Ingresa el código enviado a (.+)\.$'),
    (match) => 'Enter the code sent to ${match.group(1)}.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Esta tarjeta quedará conectada al perfil (.+)\.$'),
    (match) => 'This card will be connected to the ${match.group(1)} profile.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^Vas a desvincular de la empresa (.+) a (.+)\. Su cuenta ya no pertenecerá a la empresa\.$',
    ),
    (match) =>
        'You are about to remove ${match.group(2)} from ${match.group(1)}. Their account will no longer belong to the company.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^(.+) fue desvinculado de (.+)\.$'),
    (match) => '${match.group(1)} was removed from ${match.group(2)}.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^app\.taploe\.com/(.+) ya está en uso\. Elige otra ruta\.$'),
    (match) =>
        'app.taploe.com/${match.group(1)} is already in use. Choose another URL.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^¿Quieres eliminar a (.+)\? Esta acción no se puede deshacer\.$'),
    (match) =>
        'Do you want to delete ${match.group(1)}? This action cannot be undone.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Mínimo ([0-9]+)\. Se cobrará por perfil\.$'),
    (match) => 'Minimum ${match.group(1)}. Billing is per profile.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^([0-9]+) perfiles$'),
    (match) => '${match.group(1)} profiles',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^([0-9]+) envíos$'),
    (match) => '${match.group(1)} submissions',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^(.+)\nMiembro$'),
    (match) => '${match.group(1)}\nMember',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^([0-9]+) activos de ([0-9]+)\. Se mostrará en los perfiles administrados\.$',
    ),
    (match) =>
        '${match.group(1)} active of ${match.group(2)}. It will appear on managed profiles.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^([0-9]+) activas de ([0-9]+)\. Se usarán en los perfiles administrados\.$',
    ),
    (match) =>
        '${match.group(1)} active of ${match.group(2)}. They will be used on managed profiles.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^Tu plan efectivo es (.+)\. Si esperabas Premium o Empresa, falta crear o sincronizar la suscripción\.$',
    ),
    (match) =>
        'Your effective plan is ${_taploeEnglishPlanName(match.group(1) ?? '')}. If you expected Premium or Business, the subscription still needs to be created or synced.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^La organización (.+) otorga beneficios (.+) mientras la suscripción esté vigente\.$',
    ),
    (match) =>
        'The ${match.group(1)} organization grants ${_taploeEnglishPlanName(match.group(2) ?? '')} benefits while the subscription is active.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^Tu cuenta tiene beneficios (.+) mientras la suscripción esté vigente\.$',
    ),
    (match) =>
        'Your account has ${_taploeEnglishPlanName(match.group(1) ?? '')} benefits while the subscription is active.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^El pago está pendiente\. Si supera (.+), el sistema quitará beneficios automáticamente sin borrar tus datos\.$',
    ),
    (match) =>
        'Payment is pending. If it passes ${match.group(1)}, the system will automatically remove benefits without deleting your data.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^(.+) por perfil al año$'),
    (match) => '${match.group(1)} per profile per year',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^(.+) al año$'),
    (match) => '${match.group(1)} per year',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Llegó desde (.+)$'),
    (match) => 'Came from ${match.group(1)}',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^No pudimos actualizar la tarjeta\. (.+)$'),
    (match) =>
        'We could not update the card. ${taploeTranslateToEnglish(match.group(1) ?? '')}',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^No se pudo abrir (.+)\. Intenta de nuevo\.$'),
    (match) => '${match.group(1)} could not be opened. Try again.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^(.+) dejó sus datos en tu perfil\.$'),
    (match) => '${match.group(1)} submitted their information on your profile.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Invitación a (.+)$'),
    (match) => 'Invitation to ${match.group(1)}',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^(.+) te invitó a unirte a su equipo\.$'),
    (match) => '${match.group(1)} invited you to join their team.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^(.+) te invitó a unirte a (.+)\. Al aceptar podrás ver la analítica y actividad del equipo\.$',
    ),
    (match) =>
        '${match.group(1)} invited you to join ${match.group(2)}. When you accept, you will be able to view team analytics and activity.',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Formulario enviado (.+)$'),
    (match) => 'Form submitted ${match.group(1)}',
  ),
  _TaploeEnglishPattern(
    RegExp(r'^Ver todos los eventos \(([0-9]+)\)$'),
    (match) => 'View all events (${match.group(1)})',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^(.+) ya está listo\. Puedes conectar una tarjeta NFC o QR físico ahora, o hacerlo después desde Tarjetas\.$',
    ),
    (match) =>
        '${match.group(1)} is ready. You can connect an NFC card or physical QR now, or do it later from Cards.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^No se pudo leer profile_access_points desde el cliente\. Se intentará validar durante la vinculación directa\.$',
    ),
    (match) =>
        'profile_access_points could not be read from the client. Validation will be attempted during direct linking.',
  ),
  _TaploeEnglishPattern(
    RegExp(
      r'^No se pudo leer physical_cards desde el cliente\. Se intentará validar durante la vinculación directa\.$',
    ),
    (match) =>
        'physical_cards could not be read from the client. Validation will be attempted during direct linking.',
  ),
];

const Map<String, String> _taploeEnglishPhrases = {
  'Inicio': 'Home',
  'Perfil': 'Profile',
  'Perfiles': 'Profiles',
  'Perfil digital': 'Digital profile',
  'Perfil público': 'Public profile',
  'Perfil personal': 'Personal profile',
  'Perfil incompleto': 'Incomplete profile',
  'Sin perfil': 'No profile',
  'Sin perfil activo': 'No active profile',
  'Sin perfil seleccionado': 'No profile selected',
  'Sin usuario': 'No user',
  'Tarjetas': 'Cards',
  'Tarjeta': 'Card',
  'Vincular tarjeta': 'Link card',
  'Cambiar perfil': 'Change profile',
  'Crear nuevo perfil': 'Create new profile',
  'Nuevo perfil': 'New profile',
  'Crear perfil': 'Create profile',
  'Crear perfil digital': 'Create digital profile',
  'Completar mi perfil': 'Complete my profile',
  'Editar perfil': 'Edit profile',
  'Ver mi perfil': 'View my profile',
  'Ver perfil': 'View profile',
  'Verificado': 'Verified',
  'Compartir': 'Share',
  'Compartir perfil': 'Share profile',
  'Compartir contacto': 'Share contact',
  'Compartir acceso': 'Share access',
  'Analítica': 'Analytics',
  'Métricas': 'Metrics',
  'Leads': 'Leads',
  'Equipo': 'Team',
  'Otros': 'Other',
  'Administración': 'Administration',
  'Administrador': 'Administrator',
  'Configuración': 'Settings',
  'Facturación': 'Billing',
  'Cuenta': 'Account',
  'Seguridad': 'Security',
  'Preferencias': 'Preferences',
  'MENÚ': 'MENU',
  'Crear': 'Create',
  'Guardar': 'Save',
  'Guardar cambios': 'Save changes',
  'Cancelar': 'Cancel',
  'Cerrar': 'Close',
  'Continuar': 'Continue',
  'Continuar gratis': 'Continue free',
  'Volver': 'Back',
  'Ir al inicio': 'Go home',
  'Omitir': 'Skip',
  'Omitir por ahora': 'Skip for now',
  'Entendido': 'Got it',
  'Aceptar': 'Accept',
  'Declinar': 'Decline',
  'Eliminar': 'Delete',
  'Editar': 'Edit',
  'Ver': 'View',
  'Copiar': 'Copy',
  'Abrir/descargar': 'Open/download',
  'Abrir enlace': 'Open link',
  'Aplicar': 'Apply',
  'Enviar': 'Send',
  'Enviar solicitud': 'Send request',
  'Enviar invitación': 'Send invitation',
  'Cancelar invitación': 'Cancel invitation',
  'Invitación cancelada.': 'Invitation canceled.',
  'Invitación enviada.': 'Invitation sent.',
  'Invitación declinada.': 'Invitation declined.',
  'Invitación no disponible': 'Invitation unavailable',
  'No pudimos responder esta invitación.':
      'We could not respond to this invitation.',
  'No puedes invitarte a ti mismo.': 'You cannot invite yourself.',
  'Este usuario ya pertenece a la empresa.':
      'This user already belongs to the company.',
  'Tu rol no permite invitar miembros.':
      'Your role does not allow inviting members.',
  'Cerrar sesión': 'Sign out',
  'Correo': 'Email',
  'Email': 'Email',
  'Correo electrónico': 'Email address',
  'Correo electrónico *': 'Email address *',
  'Correo o nombre de usuario': 'Email or username',
  'Teléfono': 'Phone',
  'Zona horaria': 'Time zone',
  'Teléfono opcional': 'Optional phone',
  'Nombre': 'Name',
  'Nombre completo': 'Full name',
  'Nombre completo *': 'Full name *',
  'Nombre de usuario': 'Username',
  'Nombre del perfil': 'Profile name',
  'Nombre de empresa *': 'Company name *',
  'Nombre del formulario': 'Form name',
  'Empresa': 'Company',
  'Empresa opcional': 'Optional company',
  'Empresas': 'Companies',
  'Gratis': 'Free',
  'Cargo / rol': 'Title / role',
  'Bio': 'Bio',
  'Dirección': 'Address',
  'Dirección línea 2': 'Address line 2',
  'Ciudad': 'City',
  'Estado': 'State',
  'País': 'Country',
  'Código postal': 'Postal code',
  'Nota de contacto': 'Contact note',
  'Sitio web': 'Website',
  'WhatsApp': 'WhatsApp',
  'LinkedIn': 'LinkedIn',
  'Instagram': 'Instagram',
  'Facebook': 'Facebook',
  'TikTok': 'TikTok',
  'YouTube': 'YouTube',
  'Google Maps': 'Google Maps',
  'Calendario': 'Calendar',
  'Ubicación': 'Location',
  'Catálogo': 'Catalog',
  'Archivo': 'File',
  'Pago': 'Payment',
  'Personalizado': 'Custom',
  'Presupuesto': 'Budget',
  'Fecha': 'Date',
  'Mensaje': 'Message',
  'Descripción': 'Description',
  'Etiqueta': 'Label',
  'Etiqueta visible': 'Visible label',
  'Clave': 'Key',
  'Placeholder': 'Placeholder',
  'Texto de ayuda': 'Help text',
  'Tipo de campo': 'Field type',
  'Proveedor': 'Provider',
  'URL pública': 'Public URL',
  'Actual': 'Current',
  'Nuevo': 'New',
  'Activos': 'Active',
  'Activas': 'Active',
  'Activadas': 'Activated',
  'Inactivos': 'Inactive',
  'Activo': 'Active',
  'Inactivo': 'Inactive',
  'Pausado': 'Paused',
  'Pendiente': 'Pending',
  'Todos': 'All',
  'Más recientes': 'Newest',
  'Más antiguos': 'Oldest',
  'Estado: Todos': 'Status: All',
  'Todos los estados': 'All statuses',
  'Fuente: Todas': 'Source: All',
  'Ordenar por: Más recientes': 'Sort by: Newest',
  'Fuente': 'Source',
  'Nuevos': 'New',
  'Contactados': 'Contacted',
  'Rol': 'Role',
  'Roles y permisos': 'Roles and permissions',
  'Miembro': 'Member',
  'Miembro activo': 'Active member',
  'Última actividad': 'Last activity',
  'Tarjetas conectadas': 'Connected cards',
  'Perfiles conectados': 'Connected profiles',
  'Gestionar tarjetas': 'Manage cards',
  'Comprar ahora': 'Buy now',
  '¿Aún no tienes tu tarjeta?': 'Do you not have your card yet?',
  'Notificaciones': 'Notifications',
  'Marcar leídas': 'Mark as read',
  'Paso anterior': 'Previous step',
  'Siguiente paso': 'Next step',
  'Quitar destacado': 'Remove highlight',
  'Destacar': 'Highlight',
  'No pudimos continuar': 'We could not continue',
  'No pudimos cargar la información.': 'We could not load the information.',
  'No se pudo abrir la acción.': 'The action could not be opened.',
  'No se pudo abrir el enlace.': 'The link could not be opened.',
  'Stripe devolvió una URL inválida.': 'Stripe returned an invalid URL.',
  'No se pudo abrir Stripe.': 'Stripe could not be opened.',
  'No fue posible enviar el correo de acceso.':
      'The access email could not be sent.',
  'No se pudo completar la solicitud. Intenta de nuevo.':
      'The request could not be completed. Try again.',
  'Revisa tu correo': 'Check your email',
  'Acceso no encontrado': 'Access not found',
  'Acceso inactivo': 'Inactive access',
  'Validando tarjeta': 'Validating card',
  'Vinculando tarjeta': 'Linking card',
  'Tarjeta vinculada': 'Card linked',
  'Escaneo QR': 'QR scan',
  'Toque NFC': 'NFC tap',
  'Manual': 'Manual',
  'Acceso directo': 'Direct access',
  'Esta tarjeta ya fue vinculada': 'This card has already been linked',
  'Esta tarjeta no está disponible para vincular.':
      'This card is not available to link.',
  'Esta tarjeta ya está vinculada a tu cuenta.':
      'This card is already linked to your account.',
  'Esta tarjeta todavía no está conectada. Inicia sesión para vincularla y crear tu perfil digital.':
      'This card is not connected yet. Sign in to link it and create your digital profile.',
  'Este enlace no pertenece a una tarjeta Taploe activa.':
      'This link does not belong to an active Taploe card.',
  'Este acceso fue desactivado o reemplazado.':
      'This access was disabled or replaced.',
  'Elige el perfil que se abrirá cuando alguien escanee o acerque esta tarjeta.':
      'Choose the profile that will open when someone scans or taps this card.',
  '¿A qué perfil quieres vincular esta tarjeta?':
      'Which profile do you want to link this card to?',
  'Se creará al vincularla': 'It will be created when linked',
  'Proceso seguro': 'Secure process',
  'Solo tú puedes confirmarlo': 'Only you can confirm it',
  'Se creará ahora': 'It will be created now',
  'Al compartir': 'When sharing',
  'Abrirá tu perfil digital': 'It will open your digital profile',
  'Accesos físicos': 'Physical access points',
  'QR y NFC listos': 'QR and NFC ready',
  'QR y NFC activos': 'QR and NFC active',
  'Tu tarjeta Taploe ya está lista para compartir tu perfil.':
      'Your Taploe card is ready to share your profile.',
  'Inicia sesión para crear tu perfil.': 'Sign in to create your profile.',
  'Crea tu perfil digital': 'Create your digital profile',
  'La ruta debe tener al menos 3 letras o números.':
      'The URL must have at least 3 letters or numbers.',
  'El nombre genera un enlace público inválido. Usa letras, números o espacios.':
      'The name creates an invalid public link. Use letters, numbers, or spaces.',
  'Tu sesión no tiene permiso para crear perfiles. Cierra sesión, vuelve a entrar e intenta de nuevo.':
      'Your session does not have permission to create profiles. Sign out, sign back in, and try again.',
  'No pudimos asociar el perfil con tu usuario. Vuelve a iniciar sesión e intenta de nuevo.':
      'We could not associate the profile with your user. Sign in again and try once more.',
  'No pudimos conectarnos con el servidor. Revisa tu conexión e intenta de nuevo.':
      'We could not connect to the server. Check your connection and try again.',
  'No pudimos crear el perfil por un error inesperado. Intenta de nuevo.':
      'We could not create the profile because of an unexpected error. Try again.',
  'Inicia sesión para editar tu configuración.':
      'Sign in to edit your settings.',
  'No hay perfil para editar.': 'There is no profile to edit.',
  'Crea o selecciona un perfil para empezar.':
      'Create or select a profile to get started.',
  'Selecciona o crea un perfil para ver analítica.':
      'Select or create a profile to view analytics.',
  'Sin enlaces': 'No links',
  'Sin leads': 'No leads',
  'Sin resultados': 'No results',
  'Sin actividad reciente.': 'No recent activity.',
  'Sin clicks todavía.': 'No clicks yet.',
  'Aún no hay interacciones asociadas.':
      'There are no associated interactions yet.',
  'El formulario no contiene datos visibles.': 'The form has no visible data.',
  'Cuando alguien llene un formulario aparecerá aquí.':
      'When someone fills out a form, it will appear here.',
  'Ajusta la búsqueda o los filtros para ver leads.':
      'Adjust the search or filters to view leads.',
  'Bandeja de leads': 'Lead inbox',
  'Eliminar lead': 'Delete lead',
  'Buscar leads por nombre, empresa o correo...':
      'Search leads by name, company, or email...',
  'Buscar leads...': 'Search leads...',
  'Fuente de leads': 'Lead sources',
  'Visita': 'Visit',
  'Clic en botón': 'Button click',
  'Visita al perfil': 'Profile view',
  'Ciudad de México, MX': 'Mexico City, MX',
  'Visitas y enlaces con más interés':
      'Visits and links with the most interest',
  'Formulario enviado': 'Form submitted',
  'Contacto guardado': 'Contact saved',
  'Invitación de equipo': 'Team invitation',
  'Recibiste una invitación': 'You received an invitation',
  'Recibiste una notificación': 'You received a notification',
  'Guardó el contacto': 'Saved the contact',
  'Registró sus datos': 'Submitted their information',
  'Llegó desde tarjeta NFC': 'Came from NFC card',
  'Llegó desde código QR': 'Came from QR code',
  'Llegó desde enlace público': 'Came from public link',
  'Contacto directo': 'Direct contact',
  'Ubicación no disponible': 'Location unavailable',
  'Todas las fechas': 'All dates',
  'Embudo de conversión': 'Conversion funnel',
  'Conversión': 'Conversion',
  'Actividad reciente': 'Recent activity',
  'Actividad del equipo': 'Team activity',
  'Directorio del equipo': 'Team directory',
  'Vista previa de Equipo Empresa': 'Business Team preview',
  'Vista previa de Administración Empresa': 'Business Administration preview',
  'Vista previa de Analítica Premium': 'Premium Analytics preview',
  'Rendimiento reciente': 'Recent performance',
  'Rendimiento por día': 'Performance by day',
  'Perfiles con más interacción': 'Profiles with the most engagement',
  'Canales de origen': 'Source channels',
  'Código QR': 'QR code',
  'Código QR ejecutivo': 'Executive QR code',
  'QR scans': 'QR scans',
  'Escaneos QR': 'QR scans',
  'Taps NFC': 'NFC taps',
  'Clicks': 'Clicks',
  'Clicks totales': 'Total clicks',
  'Visitas': 'Views',
  'Vistas': 'Views',
  'Visitas totales': 'Total views',
  'Leads generados': 'Generated leads',
  'Esta semana': 'This week',
  'Hoy': 'Today',
  'Últimos 7 días': 'Last 7 days',
  'Últimas interacciones con tu perfil':
      'Latest interactions with your profile',
  'vs período anterior': 'vs previous period',
  'Visitas por día': 'Visits by day',
  'Links más clickeados': 'Most clicked links',
  'Sin perfil para compartir': 'No profile to share',
  'Centro de distribución': 'Distribution center',
  'Canales de envío': 'Send channels',
  'Fuentes de leads': 'Lead sources',
  'Enlace público': 'Public link',
  'Copiar enlace público': 'Copy public link',
  'Enlace público copiado.': 'Public link copied.',
  'Presenta tu perfil y compártelo desde un solo lugar.':
      'Present your profile and share it from one place.',
  'Administra el enlace principal y distribúyelo desde aquí.':
      'Manage the main link and distribute it from here.',
  'Distribuye tu perfil digital, QR y contacto desde un centro único.':
      'Distribute your digital profile, QR, and contact from one hub.',
  'Comparte tu enlace público': 'Share your public link',
  'Revisa cómo ven tu perfil los demás': 'Review how others see your profile',
  'Administra tus tarjetas NFC y QR': 'Manage your NFC and QR cards',
  'Mira el rendimiento detallado': 'View detailed performance',
  'Enviar enlace por WhatsApp.': 'Send link by WhatsApp.',
  'Preparar correo con tu enlace.': 'Prepare an email with your link.',
  'Copiar contacto en formato VCF.': 'Copy contact in VCF format.',
  'QR generado con tu enlace público.': 'QR generated with your public link.',
  'Descargar vCard': 'Download vCard',
  'Copiar vCard': 'Copy vCard',
  'Guardar contacto': 'Save contact',
  'Contacto': 'Contact',
  'Datos de contacto': 'Contact details',
  'Enlaces visibles': 'Visible links',
  'Tarjeta conectada': 'Connected card',
  'Salud del perfil': 'Profile health',
  'Información de contacto': 'Contact information',
  'Tu correo electrónico principal': 'Your main email address',
  'Número de contacto principal': 'Main contact number',
  'Chat directo con mensaje listo': 'Direct chat with a ready message',
  'Tu página o sitio oficial': 'Your page or official website',
  'Dirección de tu negocio': 'Your business address',
  'Ciudad o localidad': 'City or locality',
  'Estado o provincia': 'State or province',
  'Enviar correo': 'Send email',
  'Enviar WhatsApp': 'Send WhatsApp',
  'Llamar': 'Call',
  'Visitar sitio web': 'Visit website',
  'Cómo llegar': 'Get directions',
  'Enlaces principales': 'Main links',
  'Añadir enlace': 'Add link',
  'Visible en perfil público': 'Visible on public profile',
  'Los visitantes podrán ver este enlace.':
      'Visitors will be able to see this link.',
  'Administra los enlaces que aparecerán en tu perfil. Ordena, edita y destaca los más importantes.':
      'Manage the links that will appear on your profile. Sort, edit, and highlight the most important ones.',
  'Arrastra para reordenar. Los enlaces destacados se muestran con mayor prioridad en la vista pública.':
      'Drag to reorder. Featured links appear with higher priority on the public view.',
  'Diseño': 'Design',
  'Diseño personalizado': 'Custom design',
  'Diseño global': 'Global design',
  'Diseño corporativo': 'Corporate design',
  'Diseño compartido': 'Shared design',
  'Diseño de tu perfil': 'Your profile design',
  'Diseño administrado por tu empresa': 'Design managed by your company',
  'Formularios': 'Forms',
  'Formulario': 'Form',
  'Crear formulario': 'Create form',
  'Formulario activo': 'Active form',
  'Formulario compartido': 'Shared form',
  'Formulario para el equipo': 'Team form',
  'Formularios administrados por tu empresa': 'Forms managed by your company',
  'Integración': 'Integration',
  'Integraciones': 'Integrations',
  'Agregar integración': 'Add integration',
  'Editar integración': 'Edit integration',
  'Integración compartida': 'Shared integration',
  'Integraciones para el equipo': 'Team integrations',
  'Integraciones administradas por tu empresa':
      'Integrations managed by your company',
  'Herramientas externas': 'External tools',
  'Servicios externos': 'External services',
  'Agenda reuniones': 'Schedule meetings',
  'Gestiona contactos': 'Manage contacts',
  'Automatiza eventos': 'Automate events',
  'Agenda una reunión': 'Schedule a meeting',
  'Enviar información': 'Send information',
  'Mostrar en perfil': 'Show on profile',
  'Activa para que esta integración aparezca en tu tarjeta.':
      'Enable so this integration appears on your card.',
  'Mensaje de éxito': 'Success message',
  'Gracias, recibimos tu información.':
      'Thank you, we received your information.',
  'Ej. Gracias, recibimos tu información.':
      'E.g. Thank you, we received your information.',
  'Activa o desactiva la recepción de respuestas.':
      'Enable or disable receiving responses.',
  'Selecciona los datos que tendrá tu formulario.':
      'Select the data your form will include.',
  'Agregar campo': 'Add field',
  'Campo requerido': 'Required field',
  'Cuéntanos en qué podemos ayudarte': 'Tell us how we can help',
  'Describe el propósito de este formulario':
      'Describe the purpose of this form',
  'Ej. Contacto, Cotización, Agenda demo': 'E.g. Contact, Quote, Demo booking',
  'Contacto rápido': 'Quick contact',
  'Cotización': 'Quote',
  'Agenda': 'Schedule',
  'Envíos': 'Submissions',
  'envíos': 'submissions',
  'Paleta de marca': 'Brand palette',
  'Portada': 'Cover',
  'Portada pública': 'Public cover',
  'Logo': 'Logo',
  'Estilos rápidos': 'Quick styles',
  'Personaliza tu diseño': 'Customize your design',
  'Color principal': 'Primary color',
  'Color de acento': 'Accent color',
  'Estilo de botones': 'Button style',
  'Tipografía': 'Typography',
  'Fondo': 'Background',
  'Fondo y portada sin imagen': 'Background and cover without image',
  'Vista previa': 'Preview',
  'Vista previa completa': 'Full preview',
  'Vista previa en el perfil público': 'Preview on the public profile',
  'Consejos de diseño': 'Design tips',
  'Tamaño': 'Size',
  'Posición': 'Position',
  'Arriba': 'Top',
  'Centro': 'Center',
  'Abajo': 'Bottom',
  'Izquierda': 'Left',
  'Derecha': 'Right',
  'Clara': 'Light',
  'Limpia y profesional': 'Clean and professional',
  'Oscura': 'Dark',
  'Moderna y sofisticada': 'Modern and sophisticated',
  'Azul': 'Blue',
  'Fresca y corporativa': 'Fresh and corporate',
  'Gradient': 'Gradient',
  'Llamativa y moderna': 'Bold and modern',
  'Premium': 'Premium',
  'Elegante y exclusiva': 'Elegant and exclusive',
  'Insignia y marca': 'Badge and brand',
  'Copiar color': 'Copy color',
  'Previsualiza el encuadre antes de guardarlo en tu perfil público.':
      'Preview the framing before saving it to your public profile.',
  'No pudimos guardar el ajuste del logo. Revisa que el SQL de diseño esté aplicado.':
      'We could not save the logo setting. Check that the design SQL has been applied.',
  'Solo puedes cargar imágenes JPG, PNG, WEBP, HEIC, HEIF o SVG.':
      'You can only upload JPG, PNG, WEBP, HEIC, HEIF, or SVG images.',
  'Suelta tu logo aquí': 'Drop your logo here',
  'Arrastra tu logo o selecciónalo': 'Drag your logo or select it',
  'PNG, JPG o WebP · máximo 5 MB': 'PNG, JPG, or WebP - max 5 MB',
  'Cambiar logo': 'Change logo',
  'Quitar logo': 'Remove logo',
  'Cambiar foto de perfil': 'Change profile photo',
  'Cargar foto de perfil': 'Upload profile photo',
  'Plan actual': 'Current plan',
  'Cambiar plan': 'Change plan',
  'Administrar suscripción': 'Manage subscription',
  'Historial de pagos': 'Payment history',
  'Sin suscripción': 'No subscription',
  'Sin suscripción registrada': 'No subscription recorded',
  'Suscripción activa': 'Active subscription',
  'Cancelación programada': 'Cancellation scheduled',
  'Próximo pago': 'Next payment',
  'Renovación automática': 'Auto-renewal',
  'Abrir factura': 'Open invoice',
  'Tipo de plan': 'Plan type',
  'Responsable': 'Owner',
  'Ciclo': 'Cycle',
  'Tus pagos se procesan de forma segura a través de Stripe.':
      'Your payments are processed securely through Stripe.',
  'No hay una suscripción registrada en billing_subscriptions. La app no otorgará beneficios de pago hasta que exista una suscripción vigente.':
      'There is no subscription recorded in billing_subscriptions. The app will not grant paid benefits until there is an active subscription.',
  'Solo el owner que contrató la suscripción puede cambiar pago, cancelar o reanudar.':
      'Only the owner who purchased the subscription can change payment, cancel, or resume.',
  'Las acciones de cobro se activan cuando Stripe sincronice esta suscripción.':
      'Billing actions activate when Stripe syncs this subscription.',
  'La organización conserva miembros e historial, pero no otorga beneficios de pago hasta renovar.':
      'The organization keeps members and history, but paid benefits are not granted until renewal.',
  'La cuenta vuelve a Gratis hasta que se reactive una suscripción vigente.':
      'The account returns to Free until an active subscription is reactivated.',
  'Cambiar enlace público': 'Change public link',
  'Cambiar enlace': 'Change link',
  'tu-nombre': 'your-name',
  'Si cambias tu nombre de usuario, también cambiará el enlace público de tu perfil.':
      'If you change your username, your profile public link will also change.',
  'El nombre de usuario debe tener al menos 3 letras o números.':
      'The username must have at least 3 letters or numbers.',
  'Ese nombre de usuario ya está en uso.': 'That username is already in use.',
  'Ese enlace público ya está en uso.': 'That public link is already in use.',
  'No pudimos guardar la configuración. Intenta de nuevo.':
      'We could not save the settings. Try again.',
  'Configuración actualizada.': 'Settings updated.',
  'Cuenta, preferencias, organización, seguridad y plan.':
      'Account, preferences, organization, security, and plan.',
  'Idioma y mercado': 'Language and market',
  'Idioma de la plataforma': 'Platform language',
  'Mercado y moneda': 'Market and currency',
  'Español / México / MXN': 'Spanish / Mexico / MXN',
  'Inglés / Estados Unidos / USD': 'English / United States / USD',
  'Organización': 'Organization',
  'Esta cuenta todavía no pertenece a una organización.':
      'This account does not belong to an organization yet.',
  'Tu sesión usa autenticación OTP por correo. Puedes cerrarla desde aquí.':
      'Your session uses email OTP authentication. You can sign out from here.',
  'Las preferencias de notificaciones se conectarán cuando exista una tabla de preferencias o integración de email/webhook.':
      'Notification preferences will connect when there is a preferences table or email/webhook integration.',
  'Premium requerido': 'Premium required',
  'Función premium': 'Premium feature',
  'Esta función está disponible al actualizar tu plan.':
      'This feature is available when you upgrade your plan.',
  'Activa Premium': 'Activate Premium',
  'Activa Empresa': 'Activate Business',
  'Elegir plan ideal': 'Choose ideal plan',
  'Ver planes': 'View plans',
  'Explorar planes': 'Explore plans',
  'Probar 7 días gratis': 'Try 7 days free',
  'Comenzar prueba gratis': 'Start free trial',
  'Iniciar prueba gratis de 7 días': 'Start 7-day free trial',
  'Se te recordará antes de que termine tu prueba.':
      'You will be reminded before your trial ends.',
  'Después del trial': 'After trial',
  'Termina prueba': 'Trial ends',
  'Elige tu periodo de facturación': 'Choose your billing period',
  'Controla marca, diseño, formularios, integraciones y perfiles administrados por empresa.':
      'Control brand, design, forms, integrations, and company-managed profiles.',
  'Controla marca, diseño, formularios, integraciones y perfiles de empresa.':
      'Control brand, design, forms, integrations, and company profiles.',
  'Centraliza a tu equipo, controla accesos y mantén todos los perfiles alineados con tu marca.':
      'Centralize your team, control access, and keep every profile aligned with your brand.',
  'Centraliza la gestión de tu equipo, su identidad y su operación desde un solo lugar.':
      'Centralize team management, identity, and operations from one place.',
  'Centraliza miembros, perfiles, tarjetas y resultados desde Taploe Business. Para activar esta experiencia necesitas solicitar una cotización con el equipo de Taploe.':
      'Centralize members, profiles, cards, and results from Taploe Business. To activate this experience, request a quote from the Taploe team.',
  'Desbloquea estadísticas avanzadas, clics, visitas y rendimiento de tus perfiles con Premium.':
      'Unlock advanced stats, clicks, visits, and profile performance with Premium.',
  'Desbloquea el centro de administración para mantener una experiencia consistente en todos los perfiles.':
      'Unlock the administration center to keep a consistent experience across every profile.',
  'Obtén información valiosa para tomar mejores decisiones y hacer crecer tu red de contactos.':
      'Get valuable insights to make better decisions and grow your contact network.',
  'Obtén el máximo valor de tus contactos. Organiza, da seguimiento y convierte más oportunidades desde un solo lugar.':
      'Get the most value from your contacts. Organize, follow up, and convert more opportunities from one place.',
  'Más personalización y herramientas para vender mejor.':
      'More customization and tools to sell better.',
  'Control, consistencia y medición para equipos.':
      'Control, consistency, and measurement for teams.',
  'Solución personalizada para equipos grandes.':
      'Custom solution for large teams.',
  'Más personalización para que tu perfil se vea profesional y listo para compartir.':
      'More customization so your profile looks professional and ready to share.',
  'Refuerza tu marca en cada interacción.':
      'Strengthen your brand in every interaction.',
  'Conoce visitas y enlaces con más interés.':
      'Understand visits and your most interesting links.',
  'Actualiza tu información sin reimprimir tarjetas.':
      'Update your information without reprinting cards.',
  'Imagen más profesional al hacer networking.':
      'A more professional image while networking.',
  '¿Qué define mejor cómo usarás Taploe?':
      'What best describes how you will use Taploe?',
  'Te mostraremos la opción más útil para empezar.':
      'We will show you the most useful option to get started.',
  'Usar Taploe para mí': 'Use Taploe for myself',
  'Utilizar Taploe para mi equipo': 'Use Taploe for my team',
  'Aún no estoy seguro': 'I am not sure yet',
  'Conecta una tarjeta NFC o QR físico a tu perfil digital.':
      'Connect an NFC card or physical QR to your digital profile.',
  'Compra tu tarjeta NFC en taploe.com y vincúlala a tu perfil digital.':
      'Buy your NFC card at taploe.com and link it to your digital profile.',
  'URL para compartir contacto': 'URL to share contact',
  'Más opciones': 'More options',
  'Acciones de miembro': 'Member actions',
  'Desvincular': 'Remove',
  'Crea tu empresa para invitar miembros y ver analítica de equipo.':
      'Create your company to invite members and view team analytics.',
  'Crear empresa': 'Create company',
  'Gestiona tu equipo y visualiza el rendimiento en conjunto.':
      'Manage your team and view shared performance.',
  'Tu usuario quedará como administrador principal de esta empresa.':
      'Your user will become the main administrator of this company.',
  'Completa nombre, correo electrónico y cantidad aproximada.':
      'Complete name, email address, and approximate quantity.',
  'Cuéntanos qué necesita tu equipo y Taploe te ayuda con una cotización.':
      'Tell us what your team needs and Taploe will help with a quote.',
  'Cantidad aproximada *': 'Approximate quantity *',
  'Tipo de solución *': 'Solution type *',
  'Cuéntanos brevemente qué tienes en mente opcional':
      'Briefly tell us what you have in mind optional',
  'Solicitar plan para equipo': 'Request team plan',
  'Envía una invitación a un usuario existente por correo o username.':
      'Send an invitation to an existing user by email or username.',
  'Este usuario ya tiene una invitación pendiente.':
      'This user already has a pending invitation.',
  'No pudimos enviar la invitación.': 'We could not send the invitation.',
  'No pudimos cancelar la invitación.': 'We could not cancel the invitation.',
  'Aún no hay miembros activos en esta empresa.':
      'There are no active members in this company yet.',
  'Últimas interacciones registradas.': 'Latest recorded interactions.',
  'Falta aplicar las políticas RLS para crear empresas.':
      'RLS policies must be applied to create companies.',
  'Diseño compartido aplicado al equipo.': 'Shared design applied to the team.',
  'Los miembros pueden diseñar sus perfiles.':
      'Members can design their profiles.',
  'No pudimos guardar el diseño del equipo.':
      'We could not save the team design.',
  'Permisos del equipo actualizados.': 'Team permissions updated.',
  'No pudimos guardar los permisos.': 'We could not save permissions.',
  'Imagen compartida cargada.': 'Shared image uploaded.',
  'No pudimos cargar la imagen.': 'We could not upload the image.',
  'Logo de empresa actualizado.': 'Company logo updated.',
  'Logo de empresa removido.': 'Company logo removed.',
  'No pudimos actualizar el logo.': 'We could not update the logo.',
  'No pudimos quitar el logo.': 'We could not remove the logo.',
  'No pudimos actualizar el perfil.': 'We could not update the profile.',
  'Revisa la función change_card_active_profile.':
      'Check the change_card_active_profile function.',
  'Revisa la policy UPDATE de physical_cards.':
      'Check the physical_cards UPDATE policy.',
  'Revisa la policy UPDATE de profile_access_points.':
      'Check the profile_access_points UPDATE policy.',
  'Revisa la policy INSERT de physical_card_assignments.':
      'Check the physical_card_assignments INSERT policy.',
  'El cambio no se reflejó al refrescar.':
      'The change did not appear after refresh.',
  'Intenta de nuevo.': 'Try again.',
  'Identidad visual compartida': 'Shared visual identity',
  'Define qué elementos se mantienen iguales para todos los perfiles y cuáles puede personalizar cada miembro.':
      'Define which elements stay the same for all profiles and which each member can customize.',
  'Aún no hay perfiles dentro de esta empresa.':
      'There are no profiles in this company yet.',
  'Gestionar equipo': 'Manage team',
  'Invitar miembro': 'Invite member',
  'Anfitrión': 'Host',
  'Owner': 'Owner',
  'Admin': 'Admin',
  'Viewer': 'Viewer',
  'Control total': 'Full control',
  'Equipo y perfiles': 'Team and profiles',
  'Solo lectura': 'Read only',
  'Forzar diseño': 'Enforce design',
  'Forzar formularios': 'Enforce forms',
  'Forzar integraciones': 'Enforce integrations',
  'Aplica diseño global a perfiles': 'Apply global design to profiles',
  'Controles globales': 'Global controls',
  'Perfiles administrados': 'Managed profiles',
  'Formularios administrados': 'Managed forms',
  'Integraciones administradas': 'Managed integrations',
  'Correo electrónico válido.': 'Valid email address.',
  'Ingresa un correo electrónico válido.': 'Enter a valid email address.',
  'Ingresa el código completo.': 'Enter the full code.',
  'Código reenviado.': 'Code resent.',
  'No se pudo reenviar el código.': 'The code could not be resent.',
  'No se pudo enviar el código. Intenta de nuevo.':
      'The code could not be sent. Try again.',
  'No se pudo completar el acceso. Intenta de nuevo.':
      'Access could not be completed. Try again.',
  'No pudimos validar tu sesión. Vuelve a iniciar sesión e intenta de nuevo.':
      'We could not validate your session. Sign in again and try once more.',
  'Tu sesión expiró. Vuelve a iniciar sesión e intenta de nuevo.':
      'Your session expired. Sign in again and try once more.',
  'No pudimos conectar con Taploe. Revisa tu conexión e intenta de nuevo.':
      'We could not connect to Taploe. Check your connection and try again.',
  'El código fue aceptado, pero no se pudo cargar tu cuenta.':
      'The code was accepted, but your account could not be loaded.',
  'El código es incorrecto o ya expiró.':
      'The code is incorrect or has expired.',
  'Verificar código': 'Verify code',
  'Reenviar código': 'Resend code',
  'Usar otro correo': 'Use another email',
  'Continuar con Google': 'Continue with Google',
  '¿Recibiste una tarjeta Taploe?': 'Did you receive a Taploe card?',
  'Inicia sesión y vincúlala a tu perfil digital.':
      'Sign in and link it to your digital profile.',
  'Inicia sesión o crea tu cuenta en segundos':
      'Sign in or create your account in seconds',
  'Usa tu correo o continúa con otro servicio. Revisaremos si ya tienes cuenta o te ayudaremos a crear una.':
      'Use your email or continue with another service. We will check whether you already have an account or help you create one.',
  'Al continuar aceptas recibir un código temporal de acceso.':
      'By continuing, you agree to receive a temporary access code.',
  'Espera un momento antes de solicitar otro código.':
      'Wait a moment before requesting another code.',
  'La conexión de autenticación no está configurada correctamente.':
      'Authentication is not configured correctly.',
  'Escanear QR': 'Scan QR',
  'Continuar con escaneo': 'Continue scanning',
  'El escaneo con cámara está disponible desde el navegador.':
      'Camera scanning is available from the browser.',
  'Permite el acceso a la cámara para escanear tu tarjeta.':
      'Allow camera access to scan your card.',
  'Cámara activa con lector compatible.':
      'Camera active with compatible reader.',
  'Lectura automática activa.': 'Automatic reading active.',
  'Puedes cerrar e intentarlo de nuevo después de habilitar cámara.':
      'You can close and try again after enabling the camera.',
  'Solicitar permiso': 'Request permission',
  'No se pudo abrir este enlace.': 'This link could not be opened.',
  'No se pudo abrir esta integración.': 'This integration could not be opened.',
  'Este enlace no tiene información válida.':
      'This link has no valid information.',
  'Información enviada.': 'Information sent.',
  'No pudimos enviar la información. Intenta de nuevo.':
      'We could not send the information. Try again.',
  'No se pudo abrir el archivo.': 'The file could not be opened.',
  'Perfil actualizado.': 'Profile updated.',
  'Imagen cargada.': 'Image uploaded.',
  'URL copiada.': 'URL copied.',
  'Color copiado.': 'Color copied.',
  'Agrega un valor antes de mostrarlo.': 'Add a value before showing it.',
  'vCard copiada.': 'vCard copied.',
  'Completa los campos del enlace.': 'Complete the link fields.',
  'Agrega nombre del formulario.': 'Add a form name.',
  'Agrega etiqueta del campo.': 'Add a field label.',
  'Completa proveedor y URL.': 'Complete provider and URL.',
  'Tarjeta actualizada.': 'Card updated.',
  'Lead eliminado.': 'Lead deleted.',
  'No pudimos eliminar el lead.': 'We could not delete the lead.',
  'Solicitud enviada. Te contactaremos pronto.':
      'Request sent. We will contact you soon.',
  'Empresa creada.': 'Company created.',
  'Inicia sesión para crear un perfil.': 'Sign in to create a profile.',
  'Ya tienes una suscripción activa. Adminístrala desde Facturación.':
      'You already have an active subscription. Manage it from Billing.',
  'Falta configuración de Stripe en el servidor. Revisa los secrets de Supabase.':
      'Stripe configuration is missing on the server. Check the Supabase secrets.',
  'El plan seleccionado no es válido. Recarga la página e intenta de nuevo.':
      'The selected plan is invalid. Reload the page and try again.',
  'No pudimos vincular esta tarjeta. Intenta de nuevo.':
      'We could not link this card. Try again.',
  'No pudimos reconocer este QR como una tarjeta Taploe.':
      'We could not recognize this QR as a Taploe card.',
  'Esta tarjeta ya fue vinculada a otra cuenta.':
      'This card has already been linked to another account.',
  'Tarjeta NFC + perfil digital': 'NFC card + digital profile',
  'Pagada': 'Paid',
  'Abierta': 'Open',
  'Fallida': 'Failed',
  'Anulada': 'Voided',
  'Incobrable': 'Uncollectible',
  'Borrador': 'Draft',
  'No definido': 'Not set',
  'Tu perfil ya se está ejecutando como aplicación.':
      'Your profile is already running as an app.',
  'Instala este perfil en tu teléfono para abrirlo rápido desde la pantalla de inicio.':
      'Install this profile on your phone to open it quickly from the home screen.',
  'Instalar en mi teléfono': 'Install on my phone',
  'Instalado': 'Installed',
  'Instalación rápida disponible.': 'Quick installation available.',
  'Te guiamos según tu navegador.': 'We will guide you based on your browser.',
  'Toca el menú ⋮ del navegador': 'Tap the browser ⋮ menu',
  'Tu nombre': 'Your name',
  'Director comercial': 'Sales director',
  'Ayudo a equipos a compartir contactos con NFC y QR.':
      'I help teams share contacts with NFC and QR.',
  'Av. Paseo de los Héroes 123': '123 Heroes Avenue',
  'México': 'Mexico',
  'Horario de atención o referencia.': 'Business hours or reference.',
  'da@ejemplo.com': 'you@example.com',
  'Ej. Ventas Norte': 'E.g. North Sales',
  'Piso 4, oficina 402': '4th floor, office 402',
  'Usaremos este correo para contactarte.':
      'We will use this email to contact you.',
  'Notificación': 'Notification',
  'No hay sesión activa.': 'There is no active session.',
  'No se pudo cargar el usuario.': 'The user could not be loaded.',
  'No pudimos preparar tu perfil. Intenta de nuevo.':
      'We could not prepare your profile. Try again.',
  'No pudimos resolver este acceso. Intenta de nuevo.':
      'We could not resolve this access. Try again.',
  'No se pudo crear un perfil nuevo.': 'A new profile could not be created.',
  'Intenta de nuevo en unos segundos.': 'Try again in a few seconds.',
  'Formulario web': 'Web form',
  'Miembros': 'Members',
  'Miembro del equipo': 'Team member',
  'Facturación transparente': 'Transparent billing',
  'Enlaces básicos': 'Basic links',
  'QR público incluido': 'Public QR included',
  'No pudimos iniciar Checkout. Intenta de nuevo.':
      'We could not start Checkout. Try again.',
  'No pudimos actualizar el verificado.':
      'We could not update the verification badge.',
  'No pudimos abrir el portal de facturación.':
      'We could not open the billing portal.',
  'Todo está leído': 'Everything is read',
  'Cuando lleguen nuevos leads aparecerán aquí.':
      'New leads will appear here when they arrive.',
  'Inicia sesión para vincular tu tarjeta.': 'Sign in to link your card.',
  'Tu equipo ya tiene un plan activo. Solo el owner puede administrar la suscripción.':
      'Your team already has an active plan. Only the owner can manage the subscription.',
  'Crea un perfil adicional para compartir otra identidad, área o contacto.':
      'Create an additional profile to share another identity, area, or contact.',
  'Crea un perfil y vincúlalo a esta tarjeta.':
      'Create a profile and link it to this card.',
  'Después podrás vincular una tarjeta Taploe si quieres usar NFC o QR físico.':
      'Later you can link a Taploe card if you want to use NFC or physical QR.',
  'Intentar nuevamente': 'Try again',
  'Consulta vistas, clics, CTR y formularios enviados con Premium o Empresa.':
      'Review views, clicks, CTR, and form submissions with Premium or Business.',
  'Revisa eventos recientes de visitas, clics y conversiones con Premium o Empresa.':
      'Review recent visit, click, and conversion events with Premium or Business.',
  'Completa tus datos y decide cuáles aparecerán como acciones en tu perfil público.':
      'Complete your details and decide which ones will appear as actions on your public profile.',
  'Mostrar marca de verificado junto a tu nombre público.':
      'Show a verified badge next to your public name.',
  'Tu empresa usa el mismo diseño para todos los perfiles. Solo un owner o admin puede modificarlo desde Administración.':
      'Your company uses the same design for all profiles. Only an owner or admin can change it from Administration.',
  'Los formularios de este perfil se controlan desde Administración.':
      'This profile\'s forms are controlled from Administration.',
  'Las integraciones de este perfil se controlan desde Administración.':
      'This profile\'s integrations are controlled from Administration.',
  'Personaliza logo, portada, colores, estilos y apariencia pública con Premium o Empresa.':
      'Customize logo, cover, colors, styles, and public appearance with Premium or Business.',
  'Crea formularios de contacto, cotización o agenda para capturar leads con Premium o Empresa.':
      'Create contact, quote, or scheduling forms to capture leads with Premium or Business.',
  'Conecta calendario, servicios externos y herramientas comerciales con Premium o Empresa.':
      'Connect calendar, external services, and business tools with Premium or Business.',
  'Formularios de captura': 'Capture forms',
  'Aún no hay formulario compartido.': 'There is no shared form yet.',
  'Aún no hay integración compartida.': 'There is no shared integration yet.',
  'Crea un formulario de contacto, cotización o agenda para capturar leads.':
      'Create a contact, quote, or scheduling form to capture leads.',
  'Número de WhatsApp': 'WhatsApp number',
  'Número telefónico': 'Phone number',
  'URL de ubicación': 'Location URL',
  'URL del catálogo': 'Catalog URL',
  'Así se genera el contacto que verá el usuario al guardar tu perfil.':
      'This is how the contact users see when saving your profile is generated.',
  'Conecta tus canales y herramientas para que otros puedan contactarte fácilmente.':
      'Connect your channels and tools so others can contact you easily.',
  'Formulario breve para primer contacto.': 'Short form for first contact.',
  'Enviar a CRM': 'Send to CRM',
  'Abrir herramienta': 'Open tool',
  'No pudimos confirmar el cambio de perfil de la tarjeta.':
      'We could not confirm the card profile change.',
  'No pudimos guardar los cambios. Intenta de nuevo.':
      'We could not save the changes. Try again.',
  'No pudimos convertir el SVG a imagen. Revisa el archivo.':
      'We could not convert the SVG to an image. Check the file.',
  'No pudimos cargar la imagen. Revisa Storage.':
      'We could not upload the image. Check Storage.',
  'No se pudo convertir el SVG.': 'The SVG could not be converted.',
  'No se pudo procesar la imagen.': 'The image could not be processed.',
  'No pudimos preparar la imagen. Si es HEIC, intenta desde Safari/iOS o usa JPG.':
      'We could not prepare the image. If it is HEIC, try from Safari/iOS or use JPG.',
  'Guardando...': 'Saving...',
  'Usar imagen': 'Use image',
  'Agregar enlace': 'Add link',
  'Editar enlace': 'Edit link',
  'No pudimos guardar el enlace. Intenta de nuevo.':
      'We could not save the link. Try again.',
  'Todas las fuentes': 'All sources',
  'Ver menos': 'View less',
  'Ver info': 'View info',
  'No pudimos enviar la solicitud. Revisa permisos de quote_requests.':
      'We could not send the request. Check quote_requests permissions.',
  'No pudimos desvincular este miembro.': 'We could not remove this member.',
  'No pudimos crear la empresa.': 'We could not create the company.',
  'No existe un usuario con ese correo o nombre de usuario.':
      'No user exists with that email or username.',
  'Tienes rol de miembro. No puedes invitar a nuevos miembros.':
      'You have a member role. You cannot invite new members.',
  'Empresa / equipo': 'Business / team',
  'Selecciona Agregar a pantalla de inicio': 'Select Add to Home Screen',
  'Confirma con Agregar': 'Confirm with Add',
  'Elige Agregar a pantalla principal': 'Choose Add to Home Screen',
  'Administra colaboradores, perfiles y tarjetas de tu empresa con el plan Empresa.':
      'Manage employees, profiles, and cards for your company with the Business plan.',
  'Analítica avanzada': 'Advanced analytics',
  'Localiza el QR impreso en tu tarjeta Taploe. En el siguiente paso activaremos la cámara para escanearlo.':
      'Find the QR printed on your Taploe card. In the next step we will activate the camera to scan it.',
  'El QR está en la tarjeta física. Colócalo frente a la cámara para vincularla.':
      'The QR is on the physical card. Place it in front of the camera to link it.',
  'Aquí tienes un resumen de tu actividad y rendimiento.':
      'Here is a summary of your activity and performance.',
  'Enlace público listo': 'Public link ready',
  'Enlace compartido': 'Shared link',
  'Enlace copiado.': 'Link copied.',
  'Acciones rápidas': 'Quick actions',
  'Acciones': 'Actions',
  'Cuando tengas actividad, aparecerá aquí.':
      'When you have activity, it will appear here.',
  '¿Necesitas más?': 'Need more?',
  'Ver analítica': 'View analytics',
  'Abrió el perfil desde NFC': 'Opened the profile from NFC',
  'Abrió el perfil desde QR': 'Opened the profile from QR',
  'Abrió el perfil digital': 'Opened the digital profile',
  'Información registrada': 'Information recorded',
  'El diseño corporativo está administrado desde Administración.':
      'Corporate design is managed from Administration.',
  'Edita tu perfil, contacto, diseño y flujos de captura desde un mismo lugar.':
      'Edit your profile, contact details, design, and capture flows from one place.',
  'Así se verá tu perfil público en Taploe.':
      'This is how your public profile will look on Taploe.',
  'Editar formulario': 'Edit form',
  'Administra tarjetas físicas, QR, NFC y perfil vinculado.':
      'Manage physical cards, QR, NFC, and linked profile.',
  'Administra miembros, perfiles, tarjetas y resultados desde Taploe Business. Para activar esta experiencia necesitas solicitar una cotización con el equipo de Taploe.':
      'Manage members, profiles, cards, and results from Taploe Business. To activate this experience, request a quote from the Taploe team.',
  'Agregar logo': 'Add logo',
  'Cargo / Empresa': 'Role / Company',
  'No se pudo leer el archivo.': 'The file could not be read.',
  'metálica': 'metal',
};
