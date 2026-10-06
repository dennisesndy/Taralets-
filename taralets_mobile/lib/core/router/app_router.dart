import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';

import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/itinerary/presentation/screens/itinerary_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/preference_screen.dart'; // Idagdag sa itaas
import '../../features/trip/presentation/screens/create_trip_screen.dart';
import '../../features/trip/presentation/screens/group_prefs_screen.dart';
import '../../features/trip/presentation/screens/join_trip_screen.dart';
import '../../features/trip/presentation/screens/my_trips_screen.dart';
import '../../features/trip/presentation/screens/trip_created_screen.dart';
import '../../repositories/trip_repository.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Soft fade + slight upward slide, used for the splash and auth screens.
CustomTransitionPage<void> _fadeSlide(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurveTween(curve: Curves.easeOutCubic).animate(animation);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      // Splash: full screen, no bottom bar.
      GoRoute(
        path: AppRoutes.splash,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const SplashScreen()),
      ),
      
      GoRoute(
        path: AppRoutes.preferences,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final email = state.extra as String? ?? "";
          return PreferenceScreen(email: email);
        },
      ),

      // Main app: bottom navigation (Home, Discover, Trips, Itinerary, Profile).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.trips,
                builder: (context, state) => const MyTripsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.itinerary,
                builder: (context, state) => const ItineraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Auth routes: full screen, no bottom bar.
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.otp,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          // The email is passed from Register/Login through `extra`.
          final email = state.extra as String? ?? '';
          return _fadeSlide(state, OtpScreen(email: email));
        },
      ),

      // Full-screen, no bottom bar (matches Figma: hasNav is false for join-trip).
      GoRoute(
        path: AppRoutes.joinTrip,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const JoinTripScreen(),
      ),
      GoRoute(
        path: AppRoutes.createTrip,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateTripScreen(),
      ),
      GoRoute(
        path: AppRoutes.tripCreated,
        parentNavigatorKey: _rootNavigatorKey,
        // If the app was restarted on this route there is no trip to show.
        redirect: (context, state) =>
            state.extra is Trip ? null : AppRoutes.home,
        builder: (context, state) =>
            TripCreatedScreen(trip: state.extra! as Trip),
      ),
      GoRoute(
        path: AppRoutes.groupPrefs,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GroupPrefsScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});