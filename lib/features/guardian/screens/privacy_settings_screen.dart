import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../../guardian/repositories/guardian_repository.dart';
import '../../auth/repositories/auth_repository.dart';

// State management for privacy settings
class PrivacySettingsState {
  final String profileVisibility;
  final int hideLocationRadius;
  final bool isLoading;
  final bool isSaved;
  final bool isPrivateAccount;

  const PrivacySettingsState({
    this.profileVisibility = 'public',
    this.hideLocationRadius = 0,
    this.isLoading = false,
    this.isSaved = false,
    this.isPrivateAccount = false,
  });

  PrivacySettingsState copyWith({
    String? profileVisibility,
    int? hideLocationRadius,
    bool? isLoading,
    bool? isSaved,
    bool? isPrivateAccount,
  }) {
    return PrivacySettingsState(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      hideLocationRadius: hideLocationRadius ?? this.hideLocationRadius,
      isLoading: isLoading ?? this.isLoading,
      isSaved: isSaved ?? this.isSaved,
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
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
      isPrivateAccount: data?['profile_visibility'] == 'private',
      isLoading: false,
    );
  }

  void togglePrivate(bool value) {
    state = state.copyWith(
      isPrivateAccount: value,
      profileVisibility: value ? 'private' : 'public',
      isSaved: false,
    );
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
      PrivacySettingsNotifier.new,
    );

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
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Ayarlar ve Gizlilik',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: settings.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: MatchFitTheme.accentGreen,
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 20),

                // --- SECTION: ACCOUNT ---
                _SectionHeader(title: 'Hesap'),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline,
                      title: 'Profili Düzenle',
                      onTap: () => context.push('/edit-profile'),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Bildirimler',
                      onTap: () {},
                    ),
                  ],
                ),

                // --- SECTION: PRIVACY ---
                _SectionHeader(title: 'Gizlilik ve Görünürlük'),
                _SettingsGroup(
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.visibility_outlined,
                      title: 'Açık Profil',
                      subtitle: 'Başkalarının seni bulmasına izin ver',
                      value: !settings.isPrivateAccount,
                      onChanged: (v) => notifier.togglePrivate(!v),
                    ),
                    _SettingsTile(
                      icon: Icons.location_searching_rounded,
                      title: 'Konum Gizliliği',
                      subtitle: settings.hideLocationRadius > 0
                          ? '${settings.hideLocationRadius}m Gizleme Aktif'
                          : 'Tam Konum Açık',
                      onTap: () {},
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.lock_outline,
                      title: 'Gizli Hesap',
                      subtitle: 'Sadece onaylı takipçiler gönderilerini görür',
                      value: settings.isPrivateAccount,
                      onChanged: notifier.togglePrivate,
                    ),
                  ],
                ),

                // --- SECTION: SECURITY ---
                _SectionHeader(title: 'Güvenlik'),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.key_outlined,
                      title: 'Şifre Değiştir',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'İki Faktörlü Doğrulama',
                      subtitle: 'Kapalı - Kurmak için dokun',
                      onTap: () {},
                    ),
                  ],
                ),

                // --- SECTION: APPEARANCE ---
                _SectionHeader(title: 'Görünüm'),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Tema',
                      subtitle: 'Karanlık Mod',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      title: 'Dil',
                      subtitle: 'Türkçe (TR)',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Logout Button
                _LogoutButton(onTap: () => _handleLogout(context, ref)),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Çıkış Yap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'İptal',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B4B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go('/login');
    }
  }
}

// --- REUSABLE COMPONENTS ---

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                Divider(
                  color: Colors.white.withOpacity(0.05),
                  height: 1,
                  indent: 56,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white24,
        size: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: MatchFitTheme.accentGreen,
        activeTrackColor: MatchFitTheme.accentGreen.withOpacity(0.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
          color: Colors.red.withOpacity(0.05),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFFF4B4B), size: 20),
            SizedBox(width: 12),
            Text(
              'Çıkış Yap',
              style: TextStyle(
                color: Color(0xFFFF4B4B),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
