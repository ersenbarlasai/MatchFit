import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matchfit/core/theme.dart';
import '../../guardian/repositories/guardian_repository.dart';
import '../../auth/repositories/auth_repository.dart';

// State management for privacy settings
class PrivacySettingsState {
  final String profileVisibility;
  final int hideLocationRadius;
  final bool isLoading;
  final bool isSaved;

  const PrivacySettingsState({
    this.profileVisibility = 'public',
    this.hideLocationRadius = 0,
    this.isLoading = false,
    this.isSaved = false,
  });

  PrivacySettingsState copyWith({
    String? profileVisibility,
    int? hideLocationRadius,
    bool? isLoading,
    bool? isSaved,
  }) {
    return PrivacySettingsState(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      hideLocationRadius: hideLocationRadius ?? this.hideLocationRadius,
      isLoading: isLoading ?? this.isLoading,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

class PrivacySettingsNotifier extends Notifier<PrivacySettingsState> {
  @override
  PrivacySettingsState build() => const PrivacySettingsState(isLoading: true);

  Future<void> load() async {
    final supabase = ref.read(guardianRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final userId = authRepo.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final data = await supabase.getPrivacySettings(userId);
    state = PrivacySettingsState(
      profileVisibility: data?['profile_visibility'] ?? 'public',
      hideLocationRadius: data?['hide_location_radius'] ?? 0,
      isLoading: false,
    );
  }

  void setVisibility(String value) {
    state = state.copyWith(profileVisibility: value, isSaved: false);
  }

  void setHideRadius(int value) {
    state = state.copyWith(hideLocationRadius: value, isSaved: false);
  }

  Future<void> save() async {
    state = state.copyWith(isLoading: true);
    final supabase = ref.read(guardianRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final userId = authRepo.currentUser?.id;
    if (userId == null) return;

    await supabase.savePrivacySettings(
      userId: userId,
      profileVisibility: state.profileVisibility,
      hideLocationRadius: state.hideLocationRadius,
    );

    state = state.copyWith(isLoading: false, isSaved: true);
  }
}

final privacySettingsProvider =
    NotifierProvider<PrivacySettingsNotifier, PrivacySettingsState>(
        PrivacySettingsNotifier.new);

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(privacySettingsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(privacySettingsProvider);
    final notifier = ref.read(privacySettingsProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Privacy & Safety',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (!settings.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () async {
                  await notifier.save();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Colors.black),
                            const SizedBox(width: 8),
                            const Text('@Guardian: Settings saved!'),
                          ],
                        ),
                        backgroundColor: MatchFitTheme.accentGreen,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_outlined,
                    color: MatchFitTheme.accentGreen, size: 18),
                label: const Text('Save',
                    style: TextStyle(
                        color: MatchFitTheme.accentGreen,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Guardian Agent Banner
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MatchFitTheme.primaryBlue.withOpacity(0.3),
                        MatchFitTheme.primaryBlue.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: MatchFitTheme.primaryBlue.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MatchFitTheme.primaryBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.security_outlined,
                            color: MatchFitTheme.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('@Guardian Agent',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: MatchFitTheme.primaryBlue,
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              'These settings control who can see your data. Changes apply instantly.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Section: Profile Visibility
                _SectionHeader(icon: Icons.person_outline, title: 'Profile Visibility'),
                const SizedBox(height: 12),
                _VisibilityOption(
                  icon: Icons.public,
                  title: 'Public',
                  subtitle: 'Anyone can see your profile and events.',
                  value: 'public',
                  groupValue: settings.profileVisibility,
                  onChanged: notifier.setVisibility,
                ),
                _VisibilityOption(
                  icon: Icons.people_outline,
                  title: 'Friends Only',
                  subtitle: 'Only approved friends can view your full profile.',
                  value: 'friends_only',
                  groupValue: settings.profileVisibility,
                  onChanged: notifier.setVisibility,
                ),
                _VisibilityOption(
                  icon: Icons.lock_outline,
                  title: 'Private',
                  subtitle: 'Your profile is hidden. You can still join events.',
                  value: 'private',
                  groupValue: settings.profileVisibility,
                  onChanged: notifier.setVisibility,
                ),

                const SizedBox(height: 32),

                // Section: Location Privacy (Strava-style)
                _SectionHeader(
                    icon: Icons.location_on_outlined,
                    title: 'Location Privacy (Home Zone)'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Like Strava\'s Hidden Zone, this hides your precise location within a radius (e.g. around your home).',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                // Radius Selector Chips
                Wrap(
                  spacing: 8,
                  children: [0, 250, 500, 1000, 2000].map((radius) {
                    final isSelected =
                        settings.hideLocationRadius == radius;
                    final label = radius == 0
                        ? 'Off'
                        : '${radius >= 1000 ? '${radius ~/ 1000} km' : '$radius m'}';
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: MatchFitTheme.accentGreen,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor:
                          Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) => notifier.setHideRadius(radius),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Section: Content Moderation
                _SectionHeader(
                    icon: Icons.shield_moon_outlined,
                    title: 'Content Moderation'),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.sms_failed_outlined,
                  iconColor: Colors.orangeAccent,
                  title: 'Scam & Risk Detection',
                  subtitle:
                      '@Guardian scans messages for IBAN, phone number sharing, and suspicious links. Always active.',
                  badge: 'ACTIVE',
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.no_adult_content,
                  iconColor: Colors.redAccent,
                  title: 'Profanity Filter',
                  subtitle:
                      'Offensive language in event titles and descriptions is automatically blocked.',
                  badge: 'ACTIVE',
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MatchFitTheme.accentGreen, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white)),
      ],
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final void Function(String) onChanged;

  const _VisibilityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? MatchFitTheme.accentGreen.withOpacity(0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? MatchFitTheme.accentGreen
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? MatchFitTheme.accentGreen
                    : Colors.white54,
                size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? MatchFitTheme.accentGreen
                              : Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5))),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => onChanged(v!),
              activeColor: MatchFitTheme.accentGreen,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: MatchFitTheme.accentGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge,
                          style: const TextStyle(
                              fontSize: 10,
                              color: MatchFitTheme.accentGreen,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
