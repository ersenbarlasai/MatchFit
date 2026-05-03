import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../../auth/repositories/auth_repository.dart';

// ── Trust Level Model ──────────────────────────────────────────────

enum TrustLevel { rookie, active, reliable, pro, elite, legend }

class TrustLevelInfo {
  final String label;
  final String emoji;
  final Color color;
  final int minScore;
  final int maxScore;

  const TrustLevelInfo({
    required this.label,
    required this.emoji,
    required this.color,
    required this.minScore,
    required this.maxScore,
  });
}

const Map<TrustLevel, TrustLevelInfo> kTrustLevels = {
  TrustLevel.rookie: TrustLevelInfo(
    label: 'Rookie', emoji: '🟢', color: Color(0xFF6EE7B7),
    minScore: 0, maxScore: 20,
  ),
  TrustLevel.active: TrustLevelInfo(
    label: 'Active Player', emoji: '🔵', color: Color(0xFF60A5FA),
    minScore: 20, maxScore: 40,
  ),
  TrustLevel.reliable: TrustLevelInfo(
    label: 'Reliable Player', emoji: '🟣', color: Color(0xFFC084FC),
    minScore: 40, maxScore: 60,
  ),
  TrustLevel.pro: TrustLevelInfo(
    label: 'Pro Player', emoji: '🔵', color: Color(0xFF38BDF8),
    minScore: 60, maxScore: 80,
  ),
  TrustLevel.elite: TrustLevelInfo(
    label: 'Elite', emoji: '🟡', color: Color(0xFFFBBF24),
    minScore: 80, maxScore: 95,
  ),
  TrustLevel.legend: TrustLevelInfo(
    label: 'Legend', emoji: '👑', color: Color(0xFFFFD700),
    minScore: 95, maxScore: 100,
  ),
};

TrustLevel getTrustLevel(int score) {
  if (score >= 95) return TrustLevel.legend;
  if (score >= 80) return TrustLevel.elite;
  if (score >= 60) return TrustLevel.pro;
  if (score >= 40) return TrustLevel.reliable;
  if (score >= 20) return TrustLevel.active;
  return TrustLevel.rookie;
}

TrustLevelInfo getTrustLevelInfo(int score) => kTrustLevels[getTrustLevel(score)]!;

// ── Badge Definitions ──────────────────────────────────────────────

enum BadgeCategory { trust, social, activity, special }
enum BadgeDifficulty { easy, medium, hard }

class BadgeDef {
  final String key;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final BadgeCategory category;
  final BadgeDifficulty difficulty;
  final String requirement; // Human-readable requirement

  const BadgeDef({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.difficulty,
    required this.requirement,
  });
}

const List<BadgeDef> kAllBadges = [
  // 🟢 TRUST
  BadgeDef(
    key: 'iron_reliability',
    name: 'Iron Reliability',
    description: '10 etkinlik üst üste no-show yapmadan katıl',
    icon: Icons.shield_rounded,
    color: Color(0xFF6EE7B7),
    category: BadgeCategory.trust,
    difficulty: BadgeDifficulty.medium,
    requirement: '10 etkinlik no-show\'suz',
  ),
  BadgeDef(
    key: 'solid_partner',
    name: 'Solid Partner',
    description: '30 etkinlik tamamla ve %95 katılım oranını koru',
    icon: Icons.handshake_rounded,
    color: Color(0xFF34D399),
    category: BadgeCategory.trust,
    difficulty: BadgeDifficulty.hard,
    requirement: '30 etkinlik + %95 oran',
  ),
  // 🟣 SOCIAL
  BadgeDef(
    key: 'crowd_favorite',
    name: 'Crowd Favorite',
    description: '20 olumlu yorum al',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEC4899),
    category: BadgeCategory.social,
    difficulty: BadgeDifficulty.medium,
    requirement: '20 pozitif yorum',
  ),
  BadgeDef(
    key: 'team_player',
    name: 'Team Player',
    description: '10 farklı kullanıcıdan olumlu puan al',
    icon: Icons.group_rounded,
    color: Color(0xFFA78BFA),
    category: BadgeCategory.social,
    difficulty: BadgeDifficulty.easy,
    requirement: '10 farklı kullanıcı',
  ),
  // 🔵 ACTIVITY
  BadgeDef(
    key: 'streak_master',
    name: 'Streak Master',
    description: '4 hafta üst üste aktif ol',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF59E0B),
    category: BadgeCategory.activity,
    difficulty: BadgeDifficulty.medium,
    requirement: '4 haftalık streak',
  ),
  BadgeDef(
    key: 'always_ready',
    name: 'Always Ready',
    description: '5 etkinliğe son dakika katıl',
    icon: Icons.bolt_rounded,
    color: Color(0xFF60A5FA),
    category: BadgeCategory.activity,
    difficulty: BadgeDifficulty.easy,
    requirement: '5 son dakika katılım',
  ),
  // 🟡 SPECIAL
  BadgeDef(
    key: 'elite_circle',
    name: 'Elite Circle',
    description: '85+ Trust Score ve 20 etkinlik tamamla',
    icon: Icons.stars_rounded,
    color: Color(0xFFFFD700),
    category: BadgeCategory.special,
    difficulty: BadgeDifficulty.hard,
    requirement: '85+ skor + 20 etkinlik',
  ),
  BadgeDef(
    key: 'perfect_player',
    name: 'Perfect Player',
    description: '15 etkinlik üst üste sıfır negatif puanla tamamla',
    icon: Icons.military_tech_rounded,
    color: Color(0xFFF97316),
    category: BadgeCategory.special,
    difficulty: BadgeDifficulty.hard,
    requirement: '15 etkinlik 0 negatif',
  ),
];

// ── Trust Score Data Model ─────────────────────────────────────────

class TrustScoreData {
  final int total;
  final int reliability;
  final int social;
  final int activity;
  final int noShowCount;
  final int streakCount;
  final List<String> earnedBadgeKeys;

  const TrustScoreData({
    required this.total,
    required this.reliability,
    required this.social,
    required this.activity,
    required this.noShowCount,
    required this.streakCount,
    required this.earnedBadgeKeys,
  });

  TrustLevel get level => getTrustLevel(total);
  TrustLevelInfo get levelInfo => getTrustLevelInfo(total);

  TrustLevel get nextLevel {
    final levels = TrustLevel.values;
    final idx = level.index;
    if (idx < levels.length - 1) return levels[idx + 1];
    return TrustLevel.legend;
  }

  int get pointsToNextLevel {
    final info = kTrustLevels[nextLevel]!;
    return (info.minScore - total).clamp(0, 100);
  }

  factory TrustScoreData.empty() => const TrustScoreData(
    total: 0, reliability: 0, social: 0, activity: 0,
    noShowCount: 0, streakCount: 0, earnedBadgeKeys: [],
  );
}

// ── Provider ────────────────────────────────────────────────────────

final trustScoreProvider = FutureProvider.autoDispose.family<TrustScoreData, String?>((ref, userId) async {
  try {
    final targetId = userId?.isNotEmpty == true
        ? userId!
        : ref.read(authRepositoryProvider).currentUser?.id;
    if (targetId == null || targetId.isEmpty) return TrustScoreData.empty();

    final sb = Supabase.instance.client;

    // Profil verisi (tek sorgu, timeout ile)
    final profile = await sb
        .from('profiles')
        .select('trust_score, reliability_score, social_score, activity_score, no_show_count, streak_count')
        .eq('id', targetId)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));

    // Rozetler — ayrı try/catch, tablo yoksa boş dön
    List<String> badges = [];
    try {
      final badgesRes = await sb
          .from('user_badges')
          .select('badge_key')
          .eq('user_id', targetId)
          .timeout(const Duration(seconds: 5));
      badges = List<Map<String, dynamic>>.from(badgesRes as List)
          .map((b) => b['badge_key'] as String)
          .toList();
    } catch (_) {
      // user_badges tablosu yoksa veya RLS engelliyorsa boş bırak
      badges = [];
    }

    return TrustScoreData(
      total: profile?['trust_score'] as int? ?? 0,
      reliability: profile?['reliability_score'] as int? ?? 0,
      social: profile?['social_score'] as int? ?? 0,
      activity: profile?['activity_score'] as int? ?? 0,
      noShowCount: profile?['no_show_count'] as int? ?? 0,
      streakCount: profile?['streak_count'] as int? ?? 0,
      earnedBadgeKeys: badges,
    );
  } catch (e) {
    // Herhangi bir hata durumunda boş veri dön — spinner'ı sonlandır
    return TrustScoreData.empty();
  }
});

