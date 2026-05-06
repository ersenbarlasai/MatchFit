# MatchFit Agent Inventory

## Core Engine

| Agent | Rol | Mevcut Durum | Ana Veri |
| --- | --- | --- | --- |
| `@Matchmaker` | Etkinlik/kullanıcı keşfi ve eşleştirme | Kod + SQL mevcut | `profiles`, `events`, `user_sports_preferences` |
| `@Guardian` | Güvenlik, gizlilik, POI ve moderasyon | Kod + SQL mevcut | `privacy_settings`, `moderation_logs`, event konumu |
| `@Referee` | Check-in, ceza ve Trust Score otoritesi | Kod + SQL mevcut | `event_checkins`, `user_penalties`, `trust_events` |
| `@ContentManager` | Post-event sosyal içerik ve tag consent | Kod + SQL mevcut | `posts`, `post_tags`, events |
| `@Notification` | Push, uygulama içi bildirim ve şablonlama | Kod mevcut, agent kaydı eklendi | `notifications`, local notification service |

## Hesaplama Engine

| Agent | Rol | Mevcut Durum | Ana Veri |
| --- | --- | --- | --- |
| `@XPEngine` | XP, level ve streak hesaplama | Tasarım var, kod/migration eksik | `xp_events`, `user_xp`, `user_levels` |
| `@RankingEngine` | Leaderboard, lig ve rank snapshot | Tasarım var, kod/migration eksik | `ranking_snapshots`, `leaderboard_entries` |
| `@FraudDetection` | Farming, multi-account ve check-in fraud analizi | Tasarım var, kod/migration eksik | `fraud_signals`, `fraud_cases`, `risk_scores` |

## Ekonomi

| Agent | Rol | Mevcut Durum | Ana Veri |
| --- | --- | --- | --- |
| `@EconomyEngine` | MF Points ledger, limit ve eligibility | Tasarım var, kod/migration eksik | `mf_point_ledger`, `economy_limits` |
| `@RewardPersonalization` | Kişisel ödül önerisi | Tasarım var, kod/migration eksik | `reward_recommendations` |
| `@PartnerCatalog` | Sponsor, katalog, stok ve kampanya | Yeni oluşturuldu | `partners`, `reward_catalog`, `reward_inventory` |

## Bağlam ve Analitik

| Agent | Rol | Mevcut Durum | Ana Veri |
| --- | --- | --- | --- |
| `@ContextAgent` | Hava durumu, şehir, zaman ve lokasyon bağlamı | Yeni oluşturuldu | `weather_cache`, `context_snapshots` |
| `@AnalyticsAgent` | Agent health, dashboard ve BI event toplama | Yeni oluşturuldu | `analytics_events`, `daily_agent_health` |

## DevOps

| Agent | Rol | Mevcut Durum | Ana Veri |
| --- | --- | --- | --- |
| `@MatchFitReleaseCommander` | Versiyon, changelog, risk ve release raporu | `.agents` içinde mevcut | git diff/status, migrations, tests |

