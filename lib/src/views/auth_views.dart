import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories.dart';
import '../state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

class AuthLayout extends StatelessWidget {
  final Widget child;

  const AuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaploeColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 64 : 20,
                vertical: desktop ? 36 : 22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: desktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(flex: 11, child: _AuthIntro()),
                            const SizedBox(width: 64),
                            Expanded(flex: 8, child: _AuthPanel(child: child)),
                          ],
                        )
                      : _AuthPanel(showLogo: true, child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthIntro extends StatelessWidget {
  static const String _assetPath = 'assets/images/taploe-auth.png';

  const _AuthIntro();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TaploeLogo(size: 48),
          const SizedBox(height: 46),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Comparte tu contacto\nen un solo toque'),
                TextSpan(
                  text: '.',
                  style: GoogleFonts.outfit(color: TaploeColors.blue),
                ),
              ],
            ),
            style: GoogleFonts.outfit(
              fontSize: 58,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: .98,
              color: TaploeColors.black,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Accede a tu perfil, administra tus tarjetas y revisa tus interacciones desde un solo lugar.',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              color: TaploeColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 26),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Benefit(label: 'Perfil digital editable'),
              _Benefit(label: 'Activación por QR y NFC'),
              _Benefit(label: 'Métricas de interacción'),
            ],
          ),
          const SizedBox(height: 34),
          Image.asset(
            _assetPath,
            width: 610,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const _AuthIllustrationFallback(),
          ),
        ],
      ),
    );
  }
}

class _AuthIllustrationFallback extends StatelessWidget {
  const _AuthIllustrationFallback();

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      padding: const EdgeInsets.all(30),
      color: TaploeColors.soft,
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: .58,
              child: Container(
                decoration: BoxDecoration(
                  color: TaploeColors.black,
                  borderRadius: BorderRadius.circular(34),
                ),
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: TaploeColors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TaploeLogo(size: 22, centered: true),
                      SizedBox(height: 18),
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: TaploeColors.blueSoft,
                        child: Icon(Icons.person_rounded),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Tu perfil Taploe',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 26),
          const Expanded(
            flex: 2,
            child: Column(
              children: [
                _MiniFeature(
                  icon: Icons.contact_page_outlined,
                  title: 'Perfil digital',
                ),
                SizedBox(height: 12),
                _MiniFeature(
                  icon: Icons.credit_card_rounded,
                  title: 'Tarjetas activas',
                ),
                SizedBox(height: 12),
                _MiniFeature(
                  icon: Icons.insights_rounded,
                  title: 'Analítica real',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  final IconData icon;
  final String title;

  const _MiniFeature({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Row(
        children: [
          Icon(icon, color: TaploeColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final String label;

  const _Benefit({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(TaploeRadius.pill),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 17,
            color: TaploeColors.blue,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: TaploeColors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  final Widget child;
  final bool showLogo;

  const _AuthPanel({required this.child, this.showLogo = false});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      padding: EdgeInsets.all(context.isMobile ? 24 : 34),
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLogo) ...[
            const TaploeLogo(size: 39, centered: true),
            const SizedBox(height: 30),
          ],
          child,
          const SizedBox(height: 26),
          const Divider(),
          const SizedBox(height: 20),
          Text(
            '¿Recibiste una tarjeta Taploe?',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: TaploeColors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Inicia sesión y vincúlala a tu perfil digital.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: TaploeColors.muted),
          ),
        ],
      ),
    );
  }
}

class LoginView extends StatefulWidget {
  final String? pendingToken;

  const LoginView({super.key, this.pendingToken});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final email = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final pending = widget.pendingToken?.trim();
    if (pending == null || pending.isEmpty) {
      unawaited(taploeState.clearPendingActivationToken());
    }
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final normalized = email.text.trim().toLowerCase();
    if (!_validEmail(normalized)) {
      setState(() => error = 'Ingresa un correo electrónico válido.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final pending = widget.pendingToken?.trim();
      if (pending != null && pending.isNotEmpty) {
        await taploeState.savePendingActivationToken(pending);
      }

      await AuthRepository.sendOtp(normalized);

      if (!mounted) return;
      final params = <String, String>{'email': normalized};
      if (pending != null && pending.isNotEmpty) params['token'] = pending;
      context.go(Uri(path: '/otp', queryParameters: params).toString());
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => error = _friendlyAuthError(e.message));
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'No se pudo enviar el código. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Iniciar sesión',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              color: TaploeColors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Entra con tu correo. Te enviaremos un código para continuar.',
            style: GoogleFonts.dmSans(
              color: TaploeColors.muted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          TaploeTextField(
            label: 'Correo electrónico',
            hint: 'tu@empresa.com',
            controller: email,
            keyboardType: TextInputType.emailAddress,
            errorText: error,
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            onSubmitted: (_) {
              if (!loading) send();
            },
          ),
          const SizedBox(height: 20),
          TaploeButton(
            label: 'Enviar código',
            icon: Icons.arrow_forward_rounded,
            loading: loading,
            expanded: true,
            onPressed: send,
          ),
          const SizedBox(height: 14),
          Text(
            'Al continuar aceptas recibir un código temporal de acceso.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: TaploeColors.disabled,
            ),
          ),
        ],
      ),
    );
  }
}

class OtpView extends StatefulWidget {
  final String email;
  final String? name;
  final String? pendingToken;

  const OtpView({super.key, required this.email, this.name, this.pendingToken});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final code = TextEditingController();
  Timer? timer;
  int seconds = 60;
  bool loading = false;
  bool resending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    timer?.cancel();
    if (mounted) setState(() => seconds = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (seconds <= 0) {
        timer?.cancel();
      } else {
        setState(() => seconds--);
      }
    });
  }

  Future<void> verify() async {
    if (loading) return;

    final token = code.text.trim();
    if (token.length != 6 && token.length != 8) {
      setState(() => error = 'Ingresa el código completo.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await AuthRepository.verifyOtp(
        email: widget.email,
        token: token,
        fullName: widget.name,
      );

      await taploeState.bootstrap();
      await CardActivationService.handlePostLoginPendingActivation();

      final pending = widget.pendingToken?.trim();
      if (pending == null || pending.isEmpty) {
        await taploeState.clearPendingActivationToken();
      }

      if (!mounted) return;
      context.go(
        pending == null || pending.isEmpty
            ? '/'
            : '/a/${Uri.encodeComponent(pending)}',
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => error = safeAuthErrorMessage(e));
      }
    } on PostgrestException catch (e) {
      debugPrint(
        'PostgrestException after OTP: '
        'message=${e.message}, code=${e.code}, '
        'details=${e.details}, hint=${e.hint}',
      );
      if (mounted) {
        setState(() => error = safeAuthErrorMessage(e));
      }
    } catch (e) {
      debugPrint('OTP error: ${safeAuthErrorMessage(e)}');
      if (mounted) {
        setState(() => error = safeAuthErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resend() async {
    if (seconds > 0 || resending) return;

    setState(() {
      resending = true;
      error = null;
    });

    try {
      await AuthRepository.sendOtp(widget.email);
      code.clear();
      _startCountdown();
      if (mounted) taploeToast(context, 'Código reenviado.');
    } on AuthException catch (e) {
      if (mounted) setState(() => error = _friendlyAuthError(e.message));
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo reenviar el código.');
      }
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }

  String get maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return widget.email;
    final local = parts.first;
    final visible = local.length == 1 ? local : local.substring(0, 2);
    return '$visible***@${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revisa tu correo',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              color: TaploeColors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ingresa el código enviado a $maskedEmail.',
            style: GoogleFonts.dmSans(
              color: TaploeColors.muted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => verify(),
            onChanged: (value) {
              if (error != null) setState(() => error = null);
              if (value.length == 8) verify();
            },
            style: GoogleFonts.outfit(
              fontSize: context.isMobile ? 26 : 32,
              fontWeight: FontWeight.w800,
              letterSpacing: context.isMobile ? 7 : 11,
              color: TaploeColors.black,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '00000000',
              errorText: error,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 22,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TaploeButton(
            label: 'Verificar código',
            icon: Icons.check_circle_outline_rounded,
            loading: loading,
            expanded: true,
            onPressed: verify,
          ),
          const SizedBox(height: 18),
          Center(
            child: seconds > 0
                ? Text(
                    'Puedes reenviar el código en ${seconds}s',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: TaploeColors.muted,
                    ),
                  )
                : TextButton.icon(
                    onPressed: resending ? null : resend,
                    icon: resending
                        ? const SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reenviar código'),
                  ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await taploeState.clearPendingActivationToken();
              if (!context.mounted) return;
              context.go('/login');
            },
            child: const Text('Usar otro correo'),
          ),
        ],
      ),
    );
  }
}

class SignupView extends StatelessWidget {
  final String? pendingToken;

  const SignupView({super.key, this.pendingToken});

  @override
  Widget build(BuildContext context) {
    return LoginView(pendingToken: pendingToken);
  }
}

bool _validEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

String _friendlyAuthError(String raw) {
  final message = raw.toLowerCase();

  if (message.contains('rate limit') ||
      message.contains('too many') ||
      message.contains('security purposes')) {
    return 'Espera un momento antes de solicitar otro código.';
  }
  if (message.contains('invalid api key') || message.contains('401')) {
    return 'La conexión de autenticación no está configurada correctamente.';
  }
  if (message.contains('email')) {
    return 'No fue posible enviar el correo de acceso.';
  }
  return 'No se pudo completar la solicitud. Intenta de nuevo.';
}
