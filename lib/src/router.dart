import 'package:go_router/go_router.dart';

import 'state.dart';
import 'views/access_resolver_view.dart';
import 'views/activation_view.dart';
import 'views/auth_views.dart';
import 'views/dashboard_view.dart';
import 'views/public_profile_view.dart';

final taploeRouter = GoRouter(
  refreshListenable: taploeState,
  initialLocation: '/',
  redirect: (context, state) {
    final path = state.uri.path;
    final public =
        path.startsWith('/p/') ||
        path.startsWith('/a/') ||
        path.startsWith('/activate/') ||
        path == '/login' ||
        path == '/otp';

    if (taploeState.bootstrapping) return null;
    if (path == '/signup') {
      final token = state.uri.queryParameters['token'];
      return token == null ? '/login' : '/login?token=$token';
    }
    if (!taploeState.signedIn && !public) return '/login';
    if (taploeState.signedIn && path == '/login') {
      final token = state.uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        return '/a/$token';
      }
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardView()),
    GoRoute(
      path: '/profile',
      builder: (context, state) {
        return DashboardView(
          initialSection: DashboardSection.profile,
          initialProfileStep: _profileStepFromQuery(
            state.uri.queryParameters['step'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/cards',
      builder: (context, state) =>
          const DashboardView(initialSection: DashboardSection.cards),
    ),
    GoRoute(
      path: '/share',
      builder: (context, state) =>
          const DashboardView(initialSection: DashboardSection.share),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) =>
          const DashboardView(initialSection: DashboardSection.analytics),
    ),
    GoRoute(
      path: '/leads',
      builder: (context, state) =>
          const DashboardView(initialSection: DashboardSection.leads),
    ),
    GoRoute(
      path: '/team',
      builder: (context, state) =>
          const DashboardView(initialSection: DashboardSection.team),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) =>
          const DashboardView(initialSection: DashboardSection.admin),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) =>
          const DashboardView(initialSection: DashboardSection.settings),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        return LoginView(pendingToken: token);
      },
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        return OtpView(
          email: state.uri.queryParameters['email'] ?? '',
          name: state.uri.queryParameters['name'],
          pendingToken: state.uri.queryParameters['token'],
        );
      },
    ),
    GoRoute(
      path: '/a/:token',
      builder: (_, state) {
        return AccessResolverView(token: state.pathParameters['token']!);
      },
    ),
    GoRoute(
      path: '/activate/:token',
      builder: (_, state) {
        return ActivationView(token: state.pathParameters['token']!);
      },
    ),
    GoRoute(
      path: '/p/:slug',
      builder: (_, state) {
        return PublicProfileView(slug: state.pathParameters['slug']!);
      },
    ),
  ],
);

int _profileStepFromQuery(String? value) {
  switch (value?.toLowerCase()) {
    case 'contacto':
    case 'contact':
      return 1;
    case 'enlaces':
    case 'links':
      return 2;
    case 'design':
    case 'diseno':
    case 'diseño':
      return 3;
    case 'formularios':
    case 'forms':
      return 4;
    case 'integraciones':
    case 'integrations':
      return 5;
    default:
      return 0;
  }
}
