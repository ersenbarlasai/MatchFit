# MatchFit Agent Implementation Backlog

## P0

- `@Referee` için Trust Score tek-yazar prensibini SQL ve app katmanında sertleştir.
- `@Notification` için tüm notification insert/gönderimlerini tek repository/service kontratına bağla.
- `@FraudDetection` için `fraud_signals`, `fraud_cases`, `risk_scores` migration'larını ekle.

## P1

- `@XPEngine` için `xp_events`, `user_xp`, `user_levels`, `user_streaks` tablolarını oluştur.
- `@RankingEngine` için leaderboard snapshot ve city/branch ranking modelini oluştur.
- `@EconomyEngine` için MF Points ledger, cap ve redemption attempt modelini ekle.

## P2

- `@PartnerCatalog` için sponsor, reward catalog ve inventory tabloları.
- `@ContextAgent` için weather/cache ve city context.
- `@AnalyticsAgent` için event collector ve daily agent health.

## P3

- AI Coach, Challenge/Tournament, Integration/Webhook, Admin Moderation ve A/B Test agentları için ayrı discovery dokümanları.

