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
import '../features/ranking_engine/screens/leaderboard_screen.dart';
import '../features/coach_engine/screens/become_coach_screen.dart';
import '../features/profile/screens/gamification_info_screen.dart';
import '../features/explore/screens/user_search_screen.dart';
import '../features/coach_engine/screens/coach_onboarding_info_screen.dart';
import '../features/coach_engine/screens/coach_management_screen.dart';
import '../features/coach_engine/screens/coach_directory_screen.dart';
import '../features/coach_engine/screens/coach_marketplace_screen.dart';
import '../features/coach_engine/screens/coach_detail_screen.dart';
import '../features/coach_engine/screens/coach_sessions_screen.dart';
import '../features/coach_engine/screens/coach_availability_screen.dart';
import '../features/coach_engine/screens/coach_admin_hub_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/chat/screens/conversations_screen.dart';
import '../features/chat/screens/conversations_screen.dart';
import '../features/partner_catalog/screens/reward_catalog_screen.dart';
import '../features/partner_catalog/screens/reward_detail_screen.dart';
import '../features/partner_catalog/screens/partner_admin_screen.dart';
import '../features/partner_catalog/screens/redemption_history_screen.dart';
import '../features/partner_catalog/screens/partner_application_screen.dart';
import '../features/partner_catalog/screens/partner_detail_admin_screen.dart';
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
          path: '/messages',
          builder: (context, state) => const ConversationsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'gamification-info',
              builder: (context, state) => const GamificationInfoScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/coach-info',
          builder: (context, state) => const CoachOnboardingInfoScreen(),
        ),
        GoRoute(
          path: '/coaches',
          builder: (context, state) => const CoachMarketplaceScreen(),
        ),
        GoRoute(
          path: '/coach-detail',
          builder: (context, state) {
            final userId = state.extra is String ? state.extra as String : null;
            if (userId == null) return const _MissingRouteDataScreen();
            return CoachDetailScreen(userId: userId);
          },
        ),
        GoRoute(
          path: '/coach-sessions',
          builder: (context, state) => const CoachSessionsScreen(),
        ),
        GoRoute(
          path: '/coach-availability',
          builder: (context, state) => const CoachAvailabilityScreen(),
        ),
        GoRoute(
          path: '/become-coach',
          builder: (context, state) => const BecomeCoachScreen(),
        ),
        GoRoute(
          path: '/coach-hub',
          builder: (context, state) => const CoachAdminHubScreen(),
        ),
        GoRoute(
          path: '/admin/coaches',
          builder: (context, state) => const CoachManagementScreen(),
        ),
        GoRoute(
          path: '/admin/coach-directory',
          builder: (context, state) => const CoachDirectoryScreen(),
        ),
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
          path: '/chat',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final targetUserId = extra?['targetUserId'] as String?;
            final targetUserName = extra?['targetUserName'] as String? ?? 'Kullanıcı';
            final targetAvatarUrl = extra?['targetAvatarUrl'] as String?;

            if (targetUserId == null) {
              return const _MissingRouteDataScreen();
            }
            return ChatScreen(
              targetUserId: targetUserId,
              targetUserName: targetUserName,
              targetAvatarUrl: targetAvatarUrl,
            );
          },
        ),
        GoRoute(
          path: '/user-search',
          builder: (context, state) => const UserSearchScreen(),
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
        GoRoute(
          path: '/rewards',
          builder: (context, state) => const RewardCatalogScreen(),
        ),
        GoRoute(
          path: '/reward-detail',
          builder: (context, state) {
            final rewardId = state.extra is String ? state.extra as String : null;
            if (rewardId == null) return const _MissingRouteDataScreen();
            return RewardDetailScreen(rewardId: rewardId);
          },
        ),
        GoRoute(
          path: '/admin/partners',
          builder: (context, state) => const PartnerAdminScreen(),
        ),
        GoRoute(
          path: '/my-rewards',
          builder: (context, state) => const RedemptionHistoryScreen(),
        ),
        GoRoute(
          path: '/partner-apply',
          builder: (context, state) => const PartnerApplicationScreen(),
        ),
        GoRoute(
          path: '/admin/partner-detail/:id',
          builder: (context, state) => PartnerDetailAdminScreen(partnerId: state.pathParameters['id']!),
        ),
      ],
    ),

    // ── Standalone routes (no shell) ──
    // Routes removed as they are now inside ShellRoute
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
