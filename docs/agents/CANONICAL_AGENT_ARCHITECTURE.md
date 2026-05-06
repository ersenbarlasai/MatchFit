# MatchFit Canonical Agent Architecture

Bu dosya MatchFit agent mimarisinin tek ana kaynağıdır. Kodlama, migration, refactor, test ve dokümantasyon işleri yapılırken agent sorumlulukları için bu dosya esas alınmalıdır.

Diğer dosyaların rolü:

- `AGENTS.md`: Coding agent'lara kısa çalışma talimatı verir ve bu dosyaya yönlendirir.
- `GEMINI.md`: Antigravity/Gemini için aynı yönlendirmeyi yapar.
- `.agents`: Kısa agent registry ve hızlı referans dosyasıdır.
- `.agent/rules/matchfit-workspace.md`: Workspace rule olarak kısa hatırlatıcıdır.
- `antigravity/agents/agent_map.json`: Makine-okunabilir agent haritasıdır.
- `docs/agents/matchfit_agent_mimarisi_detayli_dokuman.md`: İnsan için uzun açıklamalı dokümandır.

Çelişki durumunda öncelik sırası:

1. `docs/agents/CANONICAL_AGENT_ARCHITECTURE.md`
2. `AGENTS.md`
3. `GEMINI.md`
4. `.agents`
5. diğer destek dokümanları

## Mimari Prensipler

- Her agent tek ana sorumluluğa sahiptir.
- Agentlar birbirinin verisini doğrudan manipüle etmez; sinyal, event veya servis kontratı üzerinden iletişim kurar.
- Trust Score sadece `@Referee` tarafından yazılır.
- Güvenlik sinyali `@Guardian` ve `@FraudDetection` tarafından üretilebilir, fakat Trust Score'a işleme yetkisi `@Referee`'dedir.
- Bildirim gönderimi ve notification kayıtları `@Notification` üzerinden merkezileştirilir.
- MF Points ledger, cap, limit ve eligibility `@EconomyEngine` sorumluluğundadır.
- Ödül öneri sıralaması `@RewardPersonalization` sorumluluğundadır.
- Sponsor, ödül katalogu, stok ve kampanya verisi `@PartnerCatalog` üzerinden yönetilir.
- Hava durumu, şehir, zaman ve lokasyon bağlamı `@ContextAgent` üzerinden okunur.
- Dashboard, metrik, raporlama ve agent health eventleri `@AnalyticsAgent` üzerinden toplanır.

## Agent Katmanları

| Katman | Agentlar |
| --- | --- |
| Core Engine | `@Matchmaker`, `@Guardian`, `@Referee`, `@ContentManager`, `@Notification` |
| Calculation Engine | `@XPEngine`, `@RankingEngine`, `@FraudDetection` |
| Economy | `@EconomyEngine`, `@RewardPersonalization`, `@PartnerCatalog` |
| Context & Analytics | `@ContextAgent`, `@AnalyticsAgent` |
| DevOps | `@MatchFitReleaseCommander` |

## Agent Registry

### `@Matchmaker`

Role: Etkinlik keşfi, kullanıcı eşleştirme ve partner önerisi.

Authority:

- Event/user recommendation ranking.
- Trust Score yazmaz.
- Ceza veya ekonomi kararı vermez.

Reads:

- `profiles`
- `events`
- `sports`
- `user_sports_preferences`
- kullanıcı konumu
- Trust Score
- `@ContextAgent` şehir/zaman/lokasyon bağlamı

Writes / Emits:

- öneri listeleri
- keşif sinyalleri
- roster değişiklik sinyali

Relations:

- `@Referee`: katılımcı listesi ve roster bilgisi.
- `@XPEngine`: oyuncu çeşitliliği ve branş sinyali.
- `@RankingEngine`: branş/şehir filtresi.
- `@Notification`: önerilen etkinlik veya partner bildirimi.
- `@ContextAgent`: bağlam okuma.

### `@Guardian`

Role: Gerçek zamanlı güvenlik, gizlilik, POI kontrolü ve moderasyon.

Authority:

- Event oluşturma güvenlik kontrolü.
- POI ve mantıksız lokasyon bloklama.
- Risk sinyali üretimi.
- Trust Score yazmaz.

Reads:

- `profiles`
- `privacy_settings`
- event koordinatları
- chat/event text
- POI/context verisi

Writes / Emits:

- `moderation_logs`
- `fraud_signals`
- güvenlik karar logları
- blok/uyarı sinyali

Relations:

- `@Referee`: Trust Score'a işlenebilecek güvenlik sinyali.
- `@FraudDetection`: fake event, POI, scam ve spam sinyali.
- `@Notification`: güvenlik uyarısı.
- `@ContextAgent`: POI/context doğrulama verisi.

### `@Referee`

Role: Check-in, event outcome, ceza matriksi ve Trust Score otoritesi.

Authority:

- Trust Score'un tek yazarıdır.
- `trust_events`, `profiles.trust_score`, `user_penalties` yazabilir.
- Event katılım sonucunu kesinleştirir.

Reads:

- `event_participants`
- `event_checkins`
- `trust_events`
- `user_penalties`
- Guardian/Fraud sinyalleri

Writes / Emits:

- `trust_events`
- `profiles.trust_score`
- `user_penalties`
- event outcome
- check-in sonucu

Relations:

- `@XPEngine`: başarılı katılım, no-show, geç iptal, Trust Score.
- `@RankingEngine`: Trust Score ve ceza durumu.
- `@EconomyEngine`: reward gating için Trust Score ve ceza durumu.
- `@ContentManager`: tamamlanan event verisi.
- `@Notification`: hatırlatma, ceza, check-in ve sonuç bildirimi.
- `@Guardian` / `@FraudDetection`: sinyal alır.

### `@ContentManager`

Role: Etkinlik sonrası sosyal içerik, post, tag consent ve event archive.

Authority:

- Post-event content akışı.
- Tag onay süreci.
- Post visibility uygulaması.

Reads:

- completed events
- `event_participants`
- `posts`
- `post_tags`
- privacy settings

Writes / Emits:

- `posts`
- `post_tags`
- media metadata
- content performance events

Relations:

- `@Referee`: tamamlanan event verisi alır.
- `@Notification`: tag onayı ve sosyal etkileşim bildirimi.
- `@AnalyticsAgent`: içerik metrikleri.

### `@Notification`

Role: Uygulama içi bildirim, push notification ve mesaj şablonlarının merkezi agent'ı.

Authority:

- Bildirim gönderimi.
- Notification idempotency.
- Notification template ve delivery log.

Reads:

- notification request queue
- `notifications`
- kullanıcı bildirim tercihleri

Writes / Emits:

- `notifications`
- delivery log
- open/click events

Relations:

- Tüm runtime agentlardan bildirim talebi alır.
- `@AnalyticsAgent`: delivery/open/click metrikleri.

### `@XPEngine`

Role: XP, level ve streak hesaplama.

Authority:

- XP hesaplama.
- Level ve streak güncelleme.
- Trust Score yazmaz.
- MF Points ledger yazmaz.

Reads:

- `@Referee` event outcome
- Trust Score
- Guardian abuse signal
- Matchmaker diversity signal
- sports metadata

Writes / Emits:

- `xp_events`
- `user_xp`
- `user_levels`
- `user_streaks`
- XP update event

Relations:

- `@RankingEngine`: XP güncellemesi.
- `@EconomyEngine`: level/rank etkisi.
- `@Notification`: level up ve streak bildirimi.

### `@RankingEngine`

Role: Global, haftalık, şehir, branş ve lig sıralamaları.

Authority:

- Leaderboard snapshot.
- League transition.
- Rank hesaplama.

Reads:

- XP update
- Trust Score
- Fraud flags
- branch/city filters

Writes / Emits:

- `ranking_snapshots`
- `leaderboard_entries`
- `user_leagues`
- rank change event

Relations:

- `@XPEngine`: XP update alır.
- `@Referee`: Trust Score/ceza durumu alır.
- `@FraudDetection`: abuse flag alır.
- `@Notification`: rank/league bildirimi.
- `@AnalyticsAgent`: leaderboard metrikleri.

### `@FraudDetection`

Role: Asenkron abuse, farming, multi-account ve check-in fraud analizi.

Authority:

- Risk skoru üretimi.
- Fraud case açma.
- Önerilen aksiyon üretimi.
- Anlık event bloklama yapmaz.
- Trust Score yazmaz.

Reads:

- Guardian signals
- check-in kayıtları
- XP/MF Points events
- device/session/ip fingerprint

Writes / Emits:

- `fraud_cases`
- `fraud_signals`
- `risk_scores`
- recommended action

Relations:

- `@Guardian`: shadow restriction veya inceleme önerisi.
- `@Referee`: Trust Score'a işlenebilecek davranış sinyali.
- `@EconomyEngine`: reward/farming risk sinyali.
- `@RankingEngine`: abuse flag.

### `@EconomyEngine`

Role: MF Points ekonomisi, ledger, cap, limit ve reward eligibility.

Authority:

- MF Points ledger.
- Kazanım limitleri.
- Redemption eligibility.
- Kişisel öneri yapmaz.

Reads:

- XP level/rank
- Trust Score
- Fraud risk
- PartnerCatalog cost/stock

Writes / Emits:

- `mf_point_ledger`
- `economy_limits`
- `redemption_attempts`
- reward eligibility

Relations:

- `@FraudDetection`: risk skoru alır.
- `@Referee`: Trust Score ve ceza durumu alır.
- `@XPEngine`: level/rank etkisi alır.
- `@PartnerCatalog`: fiyat/stok kontrolü.
- `@RewardPersonalization`: kullanılabilir ödül sınırları.
- `@Notification`: points/redemption bildirimi.
- `@AnalyticsAgent`: ekonomi metrikleri.

### `@RewardPersonalization`

Role: Kişisel ödül öneri sıralaması.

Authority:

- Ödül öneri ranking.
- Kullanıcıya özel kampanya seçimi.
- Ledger veya stok yazmaz.

Reads:

- Economy eligibility
- PartnerCatalog rewards
- ContextAgent weather/city
- user interests
- Trust Score

Writes / Emits:

- `reward_recommendations`
- impression/click signals

Relations:

- `@EconomyEngine`: eligibility alır, redemption etkisi gönderir.
- `@PartnerCatalog`: aktif ödül listesi alır.
- `@ContextAgent`: hava/şehir bağlamı alır.
- `@Notification`: kişisel kampanya bildirimi.

### `@PartnerCatalog`

Role: Sponsor, reward catalog, stok, fiyat ve kampanya yönetimi.

Authority:

- Reward catalog tek kaynağı.
- Sponsor inventory.
- Campaign lifecycle.

Reads:

- sponsor contracts
- stock state
- reward performance

Writes / Emits:

- `partners`
- `reward_catalog`
- `reward_inventory`
- `campaigns`

Relations:

- `@EconomyEngine`: fiyat, stok ve sponsor value.
- `@RewardPersonalization`: aktif ve uygun ödül listesi.
- `@AnalyticsAgent`: sponsor performansı.

### `@ContextAgent`

Role: Hava durumu, şehir, zaman dilimi, indoor/outdoor ve lokasyon bağlamı.

Authority:

- Context cache ve normalize veri.
- Dış context verisinin tek okuma katmanı.
- İş kuralı kararı vermez.

Reads:

- weather/location APIs
- event city/district
- timezone
- POI/context kaynakları

Writes / Emits:

- `context_snapshots`
- `weather_cache`
- `city_context`
- indoor/outdoor signal

Relations:

- `@Matchmaker`: event uygunluk bağlamı.
- `@RewardPersonalization`: hava/şehir bağlamı.
- `@Guardian`: POI/context tutarsızlık sinyali.
- `@AnalyticsAgent`: context kullanım metrikleri.

### `@AnalyticsAgent`

Role: Agent eventleri, metrikler, dashboard ve BI reporting.

Authority:

- Analytics event collector.
- Daily agent health.
- Reporting snapshot.
- Runtime karar vermez.

Reads:

- agent event logs
- notifications
- XP
- ranking
- economy
- fraud

Writes / Emits:

- `analytics_events`
- `daily_agent_health`
- BI export snapshots

Relations:

- Tüm runtime agentlardan event/metrik alır.
- `@MatchFitReleaseCommander`: release risk özeti sağlayabilir.

### `@MatchFitReleaseCommander`

Role: Release raporu, changelog, semantic versioning ve risk analizi.

Authority:

- Version önerisi.
- Commit message önerisi.
- Changelog/risk output.
- Runtime uygulama verisine müdahale etmez.

Reads:

- git diff/status
- migrations
- docs
- tests

Writes / Emits:

- release notes
- commit message önerisi
- risk analysis

Relations:

- GitHub/release süreci.
- `@AnalyticsAgent`: ops/risk özeti okuyabilir.

## Kritik İlişki Matrisi

| Source | Target | Signal | Criticality |
| --- | --- | --- | --- |
| `@Referee` | `@XPEngine` | Trust Score, no-show, check-in outcome | Critical |
| `@Guardian` | `@FraudDetection` | fake event, POI, scam signal | High |
| `@Guardian` | `@Referee` | security signal | High |
| `@FraudDetection` | `@Referee` | behavior risk signal | High |
| `@XPEngine` | `@RankingEngine` | XP update | Critical |
| `@Referee` | `@RankingEngine` | Trust Score, penalty state | Critical |
| `@FraudDetection` | `@RankingEngine` | abuse flag | High |
| `@Referee` | `@EconomyEngine` | Trust gating | Critical |
| `@FraudDetection` | `@EconomyEngine` | risk score | Critical |
| `@XPEngine` | `@EconomyEngine` | level/rank effect | High |
| `@EconomyEngine` | `@RewardPersonalization` | reward eligibility | Critical |
| `@PartnerCatalog` | `@EconomyEngine` | price, stock, sponsor value | Critical |
| `@PartnerCatalog` | `@RewardPersonalization` | active reward list | Critical |
| `@ContextAgent` | `@RewardPersonalization` | weather/city context | High |
| `@ContextAgent` | `@Matchmaker` | city/time/location context | Medium |
| `@ContextAgent` | `@Guardian` | POI/context inconsistency | High |
| `@Referee` | `@ContentManager` | completed event | Medium |
| all runtime agents | `@Notification` | notification request | High |
| all runtime agents | `@AnalyticsAgent` | events/metrics | Medium |

## Kodlama Sırasında Uygulanacak Karar Ağacı

Bir değişiklik yaparken önce hangi agentın owner olduğunu belirle:

- Etkinlik önerisi veya partner eşleşmesi: `@Matchmaker`
- Event güvenliği, POI, gizlilik, anlık moderasyon: `@Guardian`
- Check-in, no-show, ceza, Trust Score: `@Referee`
- Post, tag, sosyal feed: `@ContentManager`
- Notification insert/send/template: `@Notification`
- XP, level, streak: `@XPEngine`
- Leaderboard, rank, league: `@RankingEngine`
- Farming, multi-account, abuse risk: `@FraudDetection`
- MF Points ledger, cap, eligibility: `@EconomyEngine`
- Reward recommendation: `@RewardPersonalization`
- Sponsor/reward catalog/stock: `@PartnerCatalog`
- Weather/city/context: `@ContextAgent`
- Dashboard/reporting/event metrics: `@AnalyticsAgent`
- Release/changelog/version: `@MatchFitReleaseCommander`

Owner belirlendikten sonra:

1. Owner agentın yazma yetkisini kontrol et.
2. Gerekli veri başka agentın authority alanındaysa doğrudan yazma; sinyal veya repository/service kontratı üzerinden bağla.
3. Bildirim gerekiyorsa `@Notification` üzerinden tasarla.
4. Metrik gerekiyorsa `@AnalyticsAgent` event'i ekle.
5. Trust Score gerekiyorsa sadece `@Referee` akışına sinyal gönder.

