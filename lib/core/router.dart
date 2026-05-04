import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/update_password_screen.dart';
import '../features/auth/screens/profile_setup_screen.dart';
import '../features/onboarding/screens/sports_selection_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/home/screens/splash_screen.dart';
import '../features/events/screens/create_event_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/explore/screens/explore_screen.dart';
import '../features/guardian/screens/privacy_settings_screen.dart';
import '../features/content/screens/share_event_post_screen.dart';
import '../features/events/screens/edit_event_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/notifications/screens/notification_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/events/screens/friend_upcoming_events_screen.dart';
import '../features/profile/screens/connections_screen.dart';
import '../features/events/screens/user_events_screen.dart';
import '../core/widgets/main_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Auth & Splash (no shell) ──
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/update-password',
      builder: (context, state) => const UpdatePasswordScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/sport-interests',
      builder: (context, state) => const SportsSelectionScreen(),
    ),

    // ── Main App (with shell) ──
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExploreScreen(),
        ),
        GoRoute(
          path: '/create-event',
          builder: (context, state) => const CreateEventScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // ── Standalone routes (no shell) ──
    GoRoute(
      path: '/event-detail',
      builder: (context, state) {
        final event = _extraMap(state);
        if (event == null) return const _MissingRouteDataScreen();
        return EventDetailScreen(event: event);
      },
    ),
    GoRoute(
      path: '/privacy-settings',
      builder: (context, state) => const PrivacySettingsScreen(),
    ),
    GoRoute(
      path: '/share-event-post',
      builder: (context, state) {
        final event = _extraMap(state);
        if (event == null) return const _MissingRouteDataScreen();
        return ShareEventPostScreen(event: event);
      },
    ),
    GoRoute(
      path: '/edit-event',
      builder: (context, state) {
        final event = _extraMap(state);
        if (event == null) return const _MissingRouteDataScreen();
        return EditEventScreen(event: event);
      },
    ),
    GoRoute(
      path: '/user-profile',
      builder: (context, state) {
        final extra = state.extra;
        final userId = extra is String ? extra : null;
        return ProfileScreen(userId: userId);
      },
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/friend-upcoming-events',
      builder: (context, state) {
        final extra = _extraMap(state);
        final friendId = _stringExtra(extra, 'friendId');
        final friendName = _stringExtra(extra, 'friendName');
        if (friendId == null || friendName == null) {
          return const _MissingRouteDataScreen();
        }
        return FriendUpcomingEventsScreen(
          friendId: friendId,
          friendName: friendName,
          friendAvatar: _stringExtra(extra, 'friendAvatar'),
        );
      },
    ),
    GoRoute(
      path: '/connections',
      builder: (context, state) {
        final extra = _extraMap(state);
        final userId = _stringExtra(extra, 'userId');
        if (userId == null) return const _MissingRouteDataScreen();
        return ConnectionsScreen(
          userId: userId,
          initialTab: _intExtra(extra, 'initialTab') ?? 0,
        );
      },
    ),
    GoRoute(
      path: '/user-events',
      builder: (context, state) {
        final extra = _extraMap(state);
        final userId = _stringExtra(extra, 'userId');
        if (userId == null) return const _MissingRouteDataScreen();
        return UserEventsScreen(
          userId: userId,
          initialTab: _intExtra(extra, 'initialTab') ?? 0,
        );
      },
    ),
  ],
);

Map<String, dynamic>? _extraMap(GoRouterState state) {
  final extra = state.extra;
  if (extra is Map<String, dynamic>) return extra;
  if (extra is Map) return Map<String, dynamic>.from(extra);
  return null;
}

String? _stringExtra(Map<String, dynamic>? extra, String key) {
  final value = extra?[key];
  return value is String ? value : null;
}

int? _intExtra(Map<String, dynamic>? extra, String key) {
  final value = extra?[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

class _MissingRouteDataScreen extends StatelessWidget {
  const _MissingRouteDataScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Bu sayfa için gerekli bilgi bulunamadı.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Ana sayfaya dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
