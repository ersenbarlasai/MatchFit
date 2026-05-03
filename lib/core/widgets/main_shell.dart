import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import 'package:matchfit/core/l10n/app_localizations.dart';
import 'dart:ui';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _routes = ['/home', '/explore', '/create-event', '/notifications', '/profile'];

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/create-event')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: widget.child,
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(context, currentIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    final t = AppLocalizations.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.85),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: t.navHome, index: 0, current: currentIndex, onTap: (i) => _onTap(i, context)),
              _NavItem(icon: Icons.explore_outlined, label: t.navDiscover, index: 1, current: currentIndex, onTap: (i) => _onTap(i, context)),
              // Center Create Button
              GestureDetector(
                onTap: () => _onTap(2, context),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: currentIndex == 2 ? MatchFitTheme.accentGreen : Colors.white12,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, color: currentIndex == 2 ? Colors.black : Colors.white, size: 26),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.navCreate,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: currentIndex == 2 ? MatchFitTheme.accentGreen : Colors.white30,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavItem(icon: Icons.chat_bubble_outline_rounded, label: t.navMessages, index: 3, current: currentIndex, onTap: (i) => _onTap(i, context)),
              
              // Profile Tab with Avatar
              _ProfileNavItem(
                index: 4,
                current: currentIndex,
                onTap: (i) => _onTap(i, context),
                profileAsync: profileAsync,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final int index;
  final int current;
  final void Function(int) onTap;
  final AsyncValue<Map<String, dynamic>?> profileAsync;

  const _ProfileNavItem({
    required this.index,
    required this.current,
    required this.onTap,
    required this.profileAsync,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                profileAsync.when(
                  data: (p) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? MatchFitTheme.accentGreen : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(1),
                    child: AvatarWidget(
                      name: p?['full_name'] ?? 'P',
                      avatarUrl: p?['avatar_url'],
                      radius: 11, // Small for nav bar
                      editable: false,
                    ),
                  ),
                  loading: () => Icon(Icons.person_outline_rounded, color: isActive ? MatchFitTheme.accentGreen : Colors.white38, size: 24),
                  error: (_, __) => Icon(Icons.person_outline_rounded, color: isActive ? MatchFitTheme.accentGreen : Colors.white38, size: 24),
                ),
                if (isActive)
                  Positioned(
                    bottom: -4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: MatchFitTheme.accentGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).navProfile,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isActive ? MatchFitTheme.accentGreen : Colors.white30,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? MatchFitTheme.accentGreen : Colors.white38,
                  size: 24,
                ),
                if (isActive)
                  Positioned(
                    bottom: -4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: MatchFitTheme.accentGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isActive ? MatchFitTheme.accentGreen : Colors.white30,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
