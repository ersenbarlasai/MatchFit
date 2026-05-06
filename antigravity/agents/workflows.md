# MatchFit Agent Workflows

## Event Lifecycle

1. `@Guardian` event konumunu ve kullanıcı yaratma hakkını kontrol eder.
2. `@Matchmaker` event'i ilgili kullanıcılara görünür kılar.
3. `@Notification` öneri veya davet bildirimi gönderir.
4. `@Referee` check-in ve katılım sonucunu işler.
5. `@XPEngine`, `@RankingEngine` ve `@EconomyEngine` outcome'a göre hesaplama yapar.
6. `@ContentManager` tamamlanan event için paylaşım akışını açar.
7. `@AnalyticsAgent` lifecycle metriklerini toplar.

## Anti-Abuse

1. `@Guardian` anlık POI, scam ve moderation sinyali üretir.
2. `@FraudDetection` bu sinyali geçmiş davranışla birleştirir.
3. `@Referee` Trust Score'a işlenecek kesin davranış sonucunu yazar.
4. `@EconomyEngine` reward ve MF Points erişimini sınırlar.
5. `@RankingEngine` abuse flag'e göre sıralama etkisini düşürür.

## Reward Redemption

1. `@PartnerCatalog` aktif ödül ve stok bilgisini sağlar.
2. `@EconomyEngine` kullanıcının eligibility ve limit kontrolünü yapar.
3. `@RewardPersonalization` önerileri sıralar.
4. `@Notification` kişisel kampanya veya redemption sonucunu iletir.
5. `@AnalyticsAgent` sponsor ve redemption performansını raporlar.

