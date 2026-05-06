# MatchFit Agent Gap Analysis

Kaynaklar:

- `C:/Users/barlas/Desktop/agentlar/MatchFit_Agent_Analiz_Raporu.docx`
- `.agents`
- `lib/features/**/repositories`
- kök dizindeki Supabase `*.sql` dosyaları

## Mevcut Repo Bulguları

- `.agents` dosyası önceden 5 agent içeriyordu: `@Matchmaker`, `@Guardian`, `@Referee`, `@ContentManager`, `@MatchFitReleaseCommander`.
- Kod tarafında `NotificationRepository` ve `NotificationService` mevcut olmasına rağmen `.agents` içinde `@Notification` agent tanımı yoktu.
- XP, ranking, fraud, economy ve reward personalization mimarisi raporda anlatılıyor; repo içinde henüz kalıcı migration/repository yapısı görünmüyor.
- Guardian ile Fraud Detection sınırları raporda netleştirilmeli denmişti; canonical dokümanda Guardian gerçek zamanlı, Fraud Detection asenkron analiz olarak ayrıldı.
- Trust Score yazarı belirsizdi; canonical karar `@Referee` tek yazar olacak şekilde güncellendi.
- Economy içinde öneri mantığı karışmaması için Economy yalnızca eligibility/cap/ledger, Reward Personalization ise öneri sıralaması olarak ayrıldı.

## Oluşturulan / Tamamlanan Agent Tanımları

- `@Notification`
- `@PartnerCatalog`
- `@ContextAgent`
- `@AnalyticsAgent`

## Hâlâ Kodlanması Gereken Başlıklar

- XP tabloları ve repository/service katmanı.
- Ranking snapshot tabloları ve leaderboard hesaplayıcıları.
- Fraud signal/case/risk score veri modeli.
- MF Points ledger ve reward redemption akışı.
- Partner catalog ve reward inventory tabloları.
- Weather/context cache katmanı.
- Analytics event collector ve daily health snapshot.

