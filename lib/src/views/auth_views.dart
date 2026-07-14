import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
                horizontal: desktop ? 48 : 20,
                vertical: desktop ? 54 : 22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: desktop ? 760 : 560),
                  child: _AuthPanel(child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  final Widget child;

  const _AuthPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return TaploePanel(
      padding: EdgeInsets.symmetric(
        horizontal: context.isMobile ? 22 : 42,
        vertical: context.isMobile ? 26 : 46,
      ),
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          const SizedBox(height: 26),
          const Divider(),
          const SizedBox(height: 20),
          Text(
            '¿Recibiste una tarjeta Taploe?',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
  String? oauthLoading;
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

  Future<void> continueWithOAuth(
    OAuthProvider provider,
    String providerName,
  ) async {
    setState(() {
      oauthLoading = providerName;
      error = null;
    });

    try {
      final pending = widget.pendingToken?.trim();
      if (pending != null && pending.isNotEmpty) {
        await taploeState.savePendingActivationToken(pending);
      }
      await AuthRepository.signInWithOAuth(provider);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => error = _friendlyAuthError(e.message));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => error = 'No se pudo abrir $providerName. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => oauthLoading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const TaploeLogo(size: 48, centered: true),
          const SizedBox(height: 62),
          Text(
            'Inicia sesión o crea tu cuenta en segundos',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: context.isMobile ? 36 : 48,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.05,
              color: TaploeColors.black,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Usa tu correo o continúa con otro servicio. Revisaremos si ya tienes cuenta o te ayudaremos a crear una.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: TaploeColors.muted,
              fontSize: context.isMobile ? 16 : 20,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          TaploeTextField(
            label: 'Correo electrónico',
            hint: 'Email',
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
            label: 'Continuar',
            icon: Icons.arrow_forward_rounded,
            loading: loading,
            expanded: true,
            onPressed: send,
          ),
          const SizedBox(height: 26),
          const _AuthDivider(label: 'o'),
          const SizedBox(height: 22),
          _OAuthButton(
            label: 'Continuar con Google',
            icon: SvgPicture.asset(
              'assets/images/icons/google-icon.svg',
              width: 22,
              height: 22,
            ),
            loading: oauthLoading == 'Google',
            onPressed: loading || oauthLoading != null
                ? null
                : () => continueWithOAuth(OAuthProvider.google, 'Google'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Text(
              'Al continuar aceptas recibir un código temporal de acceso.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: TaploeColors.disabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  final String label;

  const _AuthDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: TaploeColors.muted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool loading;
  final VoidCallback? onPressed;

  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: TaploeColors.black,
          side: const BorderSide(color: TaploeColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TaploeRadius.input),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 26, child: Center(child: icon)),
            ),
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: TaploeColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
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
              fontWeight: FontWeight.w600,
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
              fontWeight: FontWeight.w600,
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

class AuthLoadingView extends StatelessWidget {
  const AuthLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaploeLogo(size: 48, centered: true),
          SizedBox(height: 64),
          Text(
            'Preparando tu perfil',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TaploeColors.black,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          SizedBox(height: 42),
          _AuthLoadingDots(),
        ],
      ),
    );
  }
}

class _AuthLoadingDots extends StatefulWidget {
  const _AuthLoadingDots();

  @override
  State<_AuthLoadingDots> createState() => _AuthLoadingDotsState();
}

class _AuthLoadingDotsState extends State<_AuthLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final phase = (controller.value + (index * .18)) % 1;
            final scale = phase < .5 ? 1 + (phase * .55) : 1.55 - (phase * .55);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: TaploeColors.black,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
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
