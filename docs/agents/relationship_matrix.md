# MatchFit Agent Relationship Matrix

## Raporla Uyumlu Ana İlişkiler

| Kaynak | Hedef | Veri / Sinyal | Kritiklik |
| --- | --- | --- | --- |
| `@Referee` | `@XPEngine` | Trust Score, no-show, check-in sonucu | Kritik |
| `@Matchmaker` | `@XPEngine` | Oyuncu çeşitliliği, spor branşı | Orta |
| `@Guardian` | `@XPEngine` | Abuse detection sinyali | Kritik |
| `@XPEngine` | `@RankingEngine` | XP güncellemesi | Kritik |
| `@Referee` | `@RankingEngine` | Trust Score, ceza durumu | Kritik |
| `@FraudDetection` | `@RankingEngine` | Abuse flag | Yüksek |
| `@Matchmaker` | `@RankingEngine` | Branş ve şehir filtresi | Orta |
| `@FraudDetection` | `@EconomyEngine` | Risk skoru ve önerilen ceza | Kritik |
| `@Referee` | `@EconomyEngine` | Trust Score gating | Kritik |
| `@XPEngine` | `@EconomyEngine` | Level ve rank etkisi | Yüksek |
| `@EconomyEngine` | `@RewardPersonalization` | Reward eligibility | Kritik |
| `@RewardPersonalization` | `@EconomyEngine` | Redemption ve öneri etkisi | Orta |
| `@Guardian` | `@FraudDetection` | Fake event, POI, scam sinyali | Yüksek |
| `@Guardian` | `@Referee` | Trust'a işlenecek güvenlik sinyali | Yüksek |
| `@Referee` | `@ContentManager` | Tamamlanan event verisi | Orta |
| `@Matchmaker` | `@Referee` | Katılımcı listesi | Yüksek |
| `@FraudDetection` | `@Guardian` | Shadow restriction önerisi | Yüksek |
| `@MatchFitReleaseCommander` | GitHub | Commit, changelog, release | Düşük |

## Yeni Merkezi Destek İlişkileri

| Kaynak | Hedef | Veri / Sinyal | Neden |
| --- | --- | --- | --- |
| Tüm runtime agent'lar | `@Notification` | Bildirim talebi | Dağınık bildirim mantığını önler |
| `@PartnerCatalog` | `@EconomyEngine` | Stok, fiyat, sponsor değeri | Reward redemption tutarlılığı |
| `@PartnerCatalog` | `@RewardPersonalization` | Aktif ödül listesi | Kişisel önerinin veri kaynağı |
| `@ContextAgent` | `@RewardPersonalization` | Hava durumu, şehir, indoor/outdoor | Bağlama göre ödül önerisi |
| `@ContextAgent` | `@Matchmaker` | Lokasyon ve zaman bağlamı | Daha iyi etkinlik önerisi |
| `@ContextAgent` | `@Guardian` | POI ve konum tutarsızlığı | Sahte event kontrolünü güçlendirir |
| Tüm runtime agent'lar | `@AnalyticsAgent` | Agent event ve health logları | Admin dashboard ve BI |

