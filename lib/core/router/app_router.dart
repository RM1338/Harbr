import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/screens/onboarding_screen.dart';
import '../../presentation/screens/auth/sign_in_screen.dart';
import '../../presentation/screens/auth/sign_up_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/reservation/reservation_screen.dart';
import '../../presentation/screens/bookings/my_bookings_screen.dart';
import '../../presentation/screens/updates/live_updates_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/widgets/shell_scaffold.dart';

// Route paths
class AppRoutes {
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const reservation = '/reservation';
  static const bookings = '/bookings';
  static const updates = '/updates';
  static const profile = '/profile';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.signIn ||
          state.matchedLocation == AppRoutes.signUp ||
          state.matchedLocation == AppRoutes.onboarding;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.onboarding;
      if (isLoggedIn && isAuthRoute) return AppRoutes.home;
      return null;
    },
    routes: [
      // Onboarding / Auth
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (ctx, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (ctx, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (ctx, state) => const SignUpScreen(),
      ),
      // Main Shell with bottom navigation
      ShellRoute(
        builder: (ctx, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (ctx, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.reservation,
            builder: (ctx, state) {
              final slotId = state.uri.queryParameters['slotId'];
              return ReservationScreen(preSelectedSlotId: slotId);
            },
          ),
          GoRoute(
            path: AppRoutes.bookings,
            builder: (ctx, state) => const MyBookingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.updates,
            builder: (ctx, state) => const LiveUpdatesScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (ctx, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
