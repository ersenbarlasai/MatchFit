import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../../guardian/repositories/guardian_repository.dart';
import '../../auth/repositories/auth_repository.dart';
import 'package:matchfit/core/l10n/app_localizations.dart';
import 'package:matchfit/core/providers/locale_provider.dart';

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
        title: Text(AppLocalizations.of(context).privacySettings,
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
                            const Text('@Guardian: Ayarlar kaydedildi!'),
                          ],
                        ),
                        backgroundColor: MatchFitTheme.accentGreen,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_outlined,
                    color: MatchFitTheme.accentGreen, size: 18),
                label: Text(AppLocalizations.of(context).save,
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
                            const Text('@Guardian Asistanı',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: MatchFitTheme.primaryBlue,
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              'Bu ayarlar verilerinizi kimlerin görebileceğini kontrol eder. Değişiklikler anında uygulanır.',
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

                // Section: Language
                _SectionHeader(icon: Icons.language, title: 'Uygulama Dili / Language'),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, child) {
                    final currentLocale = ref.watch(localeProvider);
                    final notifier = ref.read(localeProvider.notifier);

                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'tr',
                            groupValue: currentLocale.languageCode,
                            activeColor: MatchFitTheme.accentGreen,
                            title: const Text('Türkçe (TR)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onChanged: (val) {
                              if (val != null) notifier.setLocale(val);
                            },
                          ),
                          Divider(color: Colors.white.withOpacity(0.05), height: 1),
                          RadioListTile<String>(
                            value: 'en',
                            groupValue: currentLocale.languageCode,
                            activeColor: MatchFitTheme.accentGreen,
                            title: const Text('English (EN)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onChanged: (val) {
                              if (val != null) notifier.setLocale(val);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Section: Profile Visibility
                _SectionHeader(icon: Icons.person_outline, title: 'Profil Görünürlüğü'),
                const SizedBox(height: 12),
                _VisibilityOption(
                  icon: Icons.public,
                  title: 'Herkese Açık',
                  subtitle: 'Profilinizi ve etkinliklerinizi herkes görebilir.',
                  value: 'public',
                  groupValue: settings.profileVisibility,
                  onChanged: notifier.setVisibility,
                ),
                _VisibilityOption(
                  icon: Icons.people_outline,
                  title: 'Sadece Arkadaşlar',
                  subtitle: 'Sadece onaylı arkadaşlarınız tam profilinizi görebilir.',
                  value: 'friends_only',
                  groupValue: settings.profileVisibility,
                  onChanged: notifier.setVisibility,
                ),
                _VisibilityOption(
                  icon: Icons.lock_outline,
                  title: 'Gizli',
                  subtitle: 'Profiliniz gizlidir. Etkinliklere yine de katılabilirsiniz.',
                  value: 'private',
                  groupValue: settings.profileVisibility,
                  onChanged: notifier.setVisibility,
                ),

                const SizedBox(height: 32),

                // Section: Location Privacy (Strava-style)
                _SectionHeader(
                    icon: Icons.location_on_outlined,
                    title: 'Konum Gizliliği (Ev Alanı)'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Seçtiğiniz yarıçap içindeki konumunuz gizlenir (Örn: evinizin etrafı).',
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
                        ? 'Kapalı'
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
                    title: 'İçerik Denetimi'),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.sms_failed_outlined,
                  iconColor: Colors.orangeAccent,
                  title: 'Risk ve Dolandırıcılık Taraması',
                  subtitle:
                      '@Guardian Asistanı mesajları IBAN, telefon numarası ve şüpheli linklere karşı tarar. Her zaman aktiftir.',
                  badge: 'AKTİF',
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.no_adult_content,
                  iconColor: Colors.redAccent,
                  title: 'Küfür Filtresi',
                  subtitle:
                      'Etkinlik başlıklarında ve açıklamalardaki argo kelimeler otomatik olarak engellenir.',
                  badge: 'AKTİF',
                ),

                const SizedBox(height: 32),

                // Section: Account
                _SectionHeader(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Hesap Yönetimi'),
                const SizedBox(height: 12),
                _LogoutTile(),

                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

class _LogoutTile extends ConsumerWidget {
  const _LogoutTile();

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context).logOut, 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel, style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B4B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).logOut, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        onTap: () => _handleLogout(context, ref),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded, color: Color(0xFFFF4B4B), size: 20),
        ),
        title: Text(AppLocalizations.of(context).logOut,
            style: TextStyle(color: Color(0xFFFF4B4B), fontWeight: FontWeight.bold)),
        subtitle: Text('Oturumunuzu sonlandırın.',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.1), size: 14),
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
