# MatchFit Agent Workspace Rules

Bu dosya coding agent'lar için kısa giriş dosyasıdır. Agent mimarisinin tek ana kaynağı:

`docs/agents/CANONICAL_AGENT_ARCHITECTURE.md`

Kodlama, migration, refactor, test veya dokümantasyon görevi yapmadan önce bu canonical dosyayı esas al.

## Kısa Kurallar

- Trust Score sadece `@Referee` tarafından yazılır.
- Real-time güvenlik ve POI kontrolü `@Guardian` sorumluluğundadır.
- Asenkron fraud/risk analizi `@FraudDetection` sorumluluğundadır.
- Bildirim gönderimi ve notification kayıtları `@Notification` üzerinden yapılır.
- MF Points ledger, cap ve eligibility `@EconomyEngine` sorumluluğundadır.
- Ödül önerisi `@RewardPersonalization`, katalog/stok `@PartnerCatalog` sorumluluğundadır.
- Hava durumu/şehir/zaman bağlamı `@ContextAgent` üzerinden okunur.
- Metrik ve dashboard eventleri `@AnalyticsAgent` üzerinden toplanır.

## Proje Pratikleri

- Mevcut Flutter, Riverpod ve Supabase pattern'lerini koru.
- SQL değişikliklerinde RLS ve idempotent migration yaklaşımını kullan.
- Kullanıcı değişikliklerini geri alma.
- Gereksiz refactor yapma.
- Agent davranışı değişirse önce canonical dosyayı güncelle.

