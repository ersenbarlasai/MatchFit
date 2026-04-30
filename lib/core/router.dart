import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/profile_setup_screen.dart';
import '../features/auth/screens/sport_interests_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/home/screens/splash_screen.dart';
import '../features/events/screens/create_event_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/explore/screens/explore_screen.dart';
import '../features/guardian/screens/privacy_settings_screen.dart';
import '../features/content/screens/share_event_post_screen.dart';
import '../features/events/screens/edit_event_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../core/widgets/main_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Auth & Splash (no shell) ──
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/profile-setup', builder: (context, state) => const ProfileSetupScreen()),
    GoRoute(path: '/sport-interests', builder: (context, state) => const SportInterestsScreen()),

    // ── Main App (with shell) ──
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/explore', builder: (context, state) => const ExploreScreen()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      ],
    ),

    // ── Standalone routes (no shell) ──
    GoRoute(path: '/create-event', builder: (context, state) => const CreateEventScreen()),
    GoRoute(
      path: '/event-detail',
      builder: (context, state) {
        final event = state.extra as Map<String, dynamic>;
        return EventDetailScreen(event: event);
      },
    ),
    GoRoute(path: '/privacy-settings', builder: (context, state) => const PrivacySettingsScreen()),
    GoRoute(
      path: '/share-event-post',
      builder: (context, state) {
        final event = state.extra as Map<String, dynamic>;
        return ShareEventPostScreen(event: event);
      },
    ),
    GoRoute(
      path: '/edit-event',
      builder: (context, state) {
        final event = state.extra as Map<String, dynamic>;
        return EditEventScreen(event: event);
      },
    ),
  ],
);
