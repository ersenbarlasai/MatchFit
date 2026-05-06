# MatchFit Uygulama Agent Mimarisi Detaylı Doküman

Tarih: 6 Mayıs 2026  
Kapsam: MatchFit uygulamasında görev alacak runtime, ekonomi, hesaplama, bağlam, analitik ve DevOps agentları

## 1. Genel Mimari

MatchFit agent mimarisi, uygulamanın farklı alanlarını birbirinden ayırarak daha güvenli, ölçeklenebilir ve bakımı kolay bir yapı kurmak için tasarlanmıştır. Her agent tek bir ana sorumluluğa sahiptir; diğer agentlarla ise olay, sinyal veya hesaplama sonucu paylaşır.

Bu mimaride en önemli prensipler şunlardır:

- Trust Score yalnızca `@Referee` tarafından yazılır.
- Güvenlik sinyalleri `@Guardian` ve `@FraudDetection` tarafından üretilir, fakat nihai davranış skoru `@Referee` üzerinden işlenir.
- Bildirimlerin tamamı `@Notification` üzerinden merkezi olarak yönetilir.
- MF Points ekonomisi `@EconomyEngine` tarafından yönetilir; kişisel ödül önerileri `@RewardPersonalization` tarafından yapılır.
- Sponsor, katalog ve stok bilgisi `@PartnerCatalog` tarafından tutulur.
- Hava durumu, şehir, zaman ve çevresel bağlam `@ContextAgent` üzerinden sağlanır.
- Raporlama ve agent sağlığı `@AnalyticsAgent` tarafından izlenir.

## 2. Agent Katmanları

| Katman | Agentlar | Amaç |
| --- | --- | --- |
| Core Engine | `@Matchmaker`, `@Guardian`, `@Referee`, `@ContentManager`, `@Notification` | Kullanıcı, etkinlik, güvenlik, sosyal içerik ve bildirim akışları |
| Hesaplama Engine | `@XPEngine`, `@RankingEngine`, `@FraudDetection` | XP, leaderboard ve fraud risk hesaplamaları |
| Ekonomi | `@EconomyEngine`, `@RewardPersonalization`, `@PartnerCatalog` | MF Points, ödül önerisi, sponsor katalogu |
| Bağlam ve Analitik | `@ContextAgent`, `@AnalyticsAgent` | Hava durumu, şehir bağlamı, dashboard ve raporlama |
| DevOps | `@MatchFitReleaseCommander` | GitHub release, changelog ve risk raporu |

## 3. Agent Listesi ve Görevleri

## 3.1 `@Matchmaker`

Görev: Kullanıcıları doğru etkinlikler, doğru spor partnerleri ve uygun sosyal bağlantılarla eşleştirir.

Ana sorumluluklar:

- Kullanıcının konumuna, spor tercihlerine ve Trust Score'una göre etkinlik önerir.
- Yakındaki kullanıcıları ortak spor ilgi alanlarına göre sıralar.
- 1v1 sporlar için benzer seviye ve güvenilirlikte partner önerir.
- Etkinlik keşfinde mesafe, branş, geçmiş katılım ve sosyal yakınlığı birlikte değerlendirir.

Okuduğu veriler:

- `profiles`
- `events`
- `sports`
- `user_sports_preferences`
- kullanıcı konumu
- Trust Score

Yazdığı veya ürettiği çıktılar:

- öneri listesi
- keşif sinyalleri
- partner/etkinlik uygunluk skoru

İlişkileri:

- `@Referee` agentına katılımcı listesi ve roster bilgisi sağlar.
- `@XPEngine` agentına oyuncu çeşitliliği ve branş sinyali gönderir.
- `@RankingEngine` agentına branş/şehir filtre bilgisi verir.
- `@Notification` agentından önerilen etkinlik veya partner bildirimi göndermesini ister.
- `@ContextAgent` üzerinden şehir, zaman ve çevresel bağlam okuyabilir.

Yetki sınırı:

- Trust Score yazmaz.
- Ceza uygulamaz.
- Sadece öneri ve keşif kararları üretir.

## 3.2 `@Guardian`

Görev: Uygulamanın güvenlik, gizlilik, sahte etkinlik ve anlık moderasyon katmanıdır.

Ana sorumluluklar:

- Yeni kullanıcıların ilk 48 saat içinde etkinlik oluşturmasını kısıtlar.
- Sahte veya mantıksız etkinlik konumlarını POI ve koordinat kontrolüyle engeller.
- Kullanıcı gizlilik ayarlarını uygular.
- Chat veya event metinlerinde IBAN, dolandırıcılık, taciz, spam ve riskli ifadeleri tarar.
- Anlık güvenlik sinyali üretir.

Okuduğu veriler:

- `profiles`
- `privacy_settings`
- event koordinatları
- chat/event açıklamaları
- POI ve context verileri

Yazdığı veya ürettiği çıktılar:

- `moderation_logs`
- `fraud_signals`
- güvenlik karar logları
- bloklama veya uyarı sinyali

İlişkileri:

- `@Referee` agentına Trust Score'a işlenebilecek güvenlik sinyali gönderir.
- `@FraudDetection` agentına POI, fake event, scam ve spam sinyali gönderir.
- `@Notification` agentından güvenlik uyarısı veya hesap bildirimi göndermesini ister.
- `@ContextAgent` üzerinden konum ve çevresel doğrulama bilgisi okuyabilir.

Yetki sınırı:

- Trust Score'u doğrudan değiştirmez.
- Uzun vadeli fraud kararını tek başına vermez.
- Anlık bloklama ve güvenlik sinyali üretiminden sorumludur.

## 3.3 `@Referee`

Görev: Etkinlik check-in, katılım doğrulama, ceza matriksi ve Trust Score yönetiminin merkezidir.

Ana sorumluluklar:

- Etkinlik öncesi katılımcı durumunu takip eder.
- GPS veya QR/temporary code gibi yöntemlerle check-in doğrulaması yapar.
- No-show, geç iptal, son dakika iptali ve başarılı katılım olaylarını işler.
- Ceza matriksini uygular.
- Trust Score'u hesaplar ve günceller.
- Mücbir sebep veya anlaşmazlık durumlarında event sonucunu adil şekilde kapatır.

Okuduğu veriler:

- `event_participants`
- `event_checkins`
- `trust_events`
- `user_penalties`
- Guardian/Fraud sinyalleri

Yazdığı veya ürettiği çıktılar:

- `trust_events`
- `profiles.trust_score`
- `user_penalties`
- event outcome
- check-in sonucu

İlişkileri:

- `@XPEngine` agentına başarılı katılım, no-show, geç iptal ve Trust Score bilgisini gönderir.
- `@RankingEngine` agentına Trust Score ve ceza durumunu gönderir.
- `@EconomyEngine` agentına reward gating için güven/ceza durumunu verir.
- `@ContentManager` agentına tamamlanan etkinlik verisini aktarır.
- `@Notification` agentından hatırlatma, ceza, check-in ve sonuç bildirimi göndermesini ister.
- `@Guardian` ve `@FraudDetection` agentlarından gelen sinyalleri davranış skoruna dönüştürür.

Yetki sınırı:

- Trust Score'un tek yazarıdır.
- Güvenlik sinyali üretmek yerine gelen sinyalleri davranış sonucuna çevirir.
- Ekonomi veya ranking puanını doğrudan hesaplamaz.

## 3.4 `@ContentManager`

Görev: Etkinlik sonrası sosyal içerik, paylaşım, post, etiketleme ve event archive akışlarını yönetir.

Ana sorumluluklar:

- Başarılı etkinlik sonrası kullanıcıya paylaşım akışı açar.
- Event bağlantılı post oluşturur.
- Diğer katılımcılar için tag consent sürecini yönetir.
- Etiketlenen kullanıcının onayı olmadan içeriği profilinde göstermemeyi sağlar.
- Geçmiş event detayında public postları arşivler.
- Post visibility kurallarını uygular.

Okuduğu veriler:

- tamamlanan events
- `event_participants`
- `posts`
- `post_tags`
- privacy settings

Yazdığı veya ürettiği çıktılar:

- `posts`
- `post_tags`
- media metadata
- event archive içeriği

İlişkileri:

- `@Referee` agentından tamamlanan event bilgisini alır.
- `@Notification` agentından tag onayı ve sosyal etkileşim bildirimi göndermesini ister.
- `@AnalyticsAgent` agentına içerik performansı ve paylaşım metriklerini gönderir.

Yetki sınırı:

- Event sonucunu değiştirmez.
- Trust Score yazmaz.
- Sadece sosyal içerik ve consent akışını yönetir.

## 3.5 `@Notification`

Görev: Uygulama içi bildirim, push notification ve ileride e-posta/SMS gönderimlerinin merkezi agentıdır.

Ana sorumluluklar:

- Tüm agentlardan gelen bildirim taleplerini tek noktada toplar.
- Bildirim şablonlarını yönetir.
- Aynı bildirimin tekrar tekrar gönderilmesini önlemek için idempotency uygular.
- Uygulama içi `notifications` tablosunu besler.
- Local/push notification servisleriyle iletişim kurar.
- Bildirim okundu, silindi, tıklandı gibi eventleri raporlar.

Okuduğu veriler:

- notification request queue
- `notifications`
- kullanıcı bildirim tercihleri
- agent eventleri

Yazdığı veya ürettiği çıktılar:

- `notifications`
- delivery log
- open/click eventleri

İlişkileri:

- Tüm runtime agentlardan bildirim talebi alır.
- `@AnalyticsAgent` agentına delivery, open ve click metriklerini gönderir.
- `@Referee`, `@RankingEngine`, `@XPEngine`, `@EconomyEngine`, `@RewardPersonalization`, `@Guardian`, `@ContentManager` gibi agentların kullanıcıya görünür mesajlarını gönderir.

Yetki sınırı:

- İş kuralı kararı vermez.
- Ceza, XP, ekonomi veya ranking hesaplamaz.
- Sadece doğru mesajı doğru kullanıcıya doğru kanaldan iletir.

## 3.6 `@XPEngine`

Görev: Kullanıcının etkinliklerden kazandığı XP, level ve streak değerlerini hesaplar.

Ana sorumluluklar:

- Etkinlik türüne göre XP hesaplar.
- Başarılı katılım, erken check-in, streak ve farklı branş katılımına bonus verir.
- No-show, abuse veya düşük Trust Score durumlarında XP çarpanını azaltır.
- Level geçişlerini hesaplar.
- Streak durumunu günceller.

Okuduğu veriler:

- `@Referee` event outcome
- Trust Score
- Guardian abuse signal
- Matchmaker diversity signal
- sports metadata

Yazdığı veya ürettiği çıktılar:

- `xp_events`
- `user_xp`
- `user_levels`
- `user_streaks`
- `xp_gained`
- `new_level`

İlişkileri:

- `@Referee` agentından check-in ve katılım sonucu alır.
- `@Guardian` agentından abuse sinyali alır.
- `@Matchmaker` agentından oyuncu/branş çeşitliliği sinyali alır.
- `@RankingEngine` agentına XP güncellemesi gönderir.
- `@EconomyEngine` agentına level/rank etkisi gönderir.
- `@Notification` agentından level up ve streak bildirimi göndermesini ister.

Yetki sınırı:

- Trust Score yazmaz.
- MF Points ledger yönetmez.
- Ranking snapshot oluşturmaz.

## 3.7 `@RankingEngine`

Görev: Kullanıcıların global, haftalık, şehir, branş ve lig sıralamalarını hesaplar.

Ana sorumluluklar:

- XP güncellemelerine göre leaderboard hesaplar.
- Haftalık, aylık, şehir ve branş bazlı sıralama snapshotları üretir.
- Lig yükselme/düşme durumlarını belirler.
- Fraud veya düşük Trust Score sinyallerine göre ranking etkisini azaltır.
- Kullanıcıya rank değişimi bilgisi üretir.

Okuduğu veriler:

- XP güncellemeleri
- Trust Score
- Fraud flags
- kullanıcı şehir ve branş bilgisi

Yazdığı veya ürettiği çıktılar:

- `ranking_snapshots`
- `leaderboard_entries`
- `user_leagues`
- `rank_global`
- `rank_city`
- `league`

İlişkileri:

- `@XPEngine` agentından XP güncellemesi alır.
- `@Referee` agentından Trust Score ve ceza durumu alır.
- `@FraudDetection` agentından abuse flag alır.
- `@Matchmaker` agentından branş/şehir filtresi alır.
- `@Notification` agentından rank değişimi ve lig bildirimi göndermesini ister.
- `@AnalyticsAgent` agentına leaderboard sağlığı ve dağılım metriklerini gönderir.

Yetki sınırı:

- XP hesaplamaz.
- Trust Score yazmaz.
- Reward eligibility belirlemez.

## 3.8 `@FraudDetection`

Görev: Multi-account, farming, sahte check-in ve ekonomi istismarını asenkron analiz eder.

Ana sorumluluklar:

- Aynı cihaz, IP, davranış paterni veya koordinat tekrarlarını analiz eder.
- Check-in sahtekarlığı riskini hesaplar.
- XP farming veya MF Points farming davranışını tespit eder.
- Multi-account şüphelerini case olarak açar.
- Risk skoruna göre önerilen aksiyon üretir.

Okuduğu veriler:

- Guardian güvenlik sinyalleri
- check-in kayıtları
- XP eventleri
- MF Points ledger
- device/session/ip fingerprint verileri

Yazdığı veya ürettiği çıktılar:

- `fraud_cases`
- `fraud_signals`
- `risk_scores`
- `fraud_risk_score`
- `recommended_action`

İlişkileri:

- `@Guardian` agentından fake event, POI, scam ve spam sinyalleri alır.
- `@RankingEngine` agentına abuse flag gönderir.
- `@EconomyEngine` agentına risk skoru ve ceza önerisi gönderir.
- `@Referee` agentına Trust Score'a işlenebilecek davranış sinyali gönderir.
- `@Guardian` agentına shadow restriction veya inceleme önerisi döndürebilir.

Yetki sınırı:

- Anlık event bloklama yapmaz; bu `@Guardian` sorumluluğudur.
- Trust Score'u doğrudan yazmaz.
- Kullanıcıya doğrudan bildirim göndermez; `@Notification` üzerinden yapılır.

## 3.9 `@EconomyEngine`

Görev: MF Points ekonomisini, kazanım limitlerini, redemption eligibility ve ekonomi sağlığını yönetir.

Ana sorumluluklar:

- Kullanıcının MF Points kazanımını ledger mantığıyla işler.
- Günlük/haftalık kazanım limitlerini uygular.
- Fraud veya düşük Trust Score durumlarında reward erişimini kısıtlar.
- Ödül kullanımı için eligibility kararı verir.
- MF Points enflasyonunu ve sistem dengesini izler.

Okuduğu veriler:

- XP level
- ranking
- Trust Score
- Fraud risk
- PartnerCatalog reward cost/stok

Yazdığı veya ürettiği çıktılar:

- `mf_point_ledger`
- `economy_limits`
- `redemption_attempts`
- `economy_status`
- `reward_eligibility`

İlişkileri:

- `@FraudDetection` agentından risk skoru alır.
- `@Referee` agentından Trust Score ve ceza durumu alır.
- `@XPEngine` agentından level/rank etkisi alır.
- `@PartnerCatalog` agentından fiyat ve stok bilgisi alır.
- `@RewardPersonalization` agentına kullanılabilir ödül sınırlarını gönderir.
- `@Notification` agentından points kazanımı veya redemption sonucu bildirimi göndermesini ister.
- `@AnalyticsAgent` agentına ekonomi sağlık metrikleri gönderir.

Yetki sınırı:

- Kişisel ödül önerisi yapmaz.
- Sponsor katalogunu yönetmez.
- Trust Score yazmaz.

## 3.10 `@RewardPersonalization`

Görev: Kullanıcının sporuna, konumuna, Trust Score'una, hava durumuna ve davranışına göre kişisel ödül önerir.

Ana sorumluluklar:

- Kullanıcıya en uygun ödülleri sıralar.
- Spor branşı ve şehir bazlı kampanyaları öne çıkarır.
- Hava durumu veya indoor/outdoor bağlamına göre öneri değiştirir.
- Kullanıcının tıklama ve redemption davranışına göre önerileri iyileştirir.

Okuduğu veriler:

- Economy eligibility
- PartnerCatalog reward listesi
- ContextAgent weather/city
- kullanıcı spor tercihleri
- Trust Score
- geçmiş redemption/click davranışı

Yazdığı veya ürettiği çıktılar:

- `reward_recommendations`
- impression/click signals
- kişisel ödül sıralaması

İlişkileri:

- `@EconomyEngine` agentından eligibility ve limit bilgisi alır.
- `@PartnerCatalog` agentından aktif ödül listesi alır.
- `@ContextAgent` agentından hava durumu ve şehir bağlamı alır.
- `@EconomyEngine` agentına redemption ve öneri etkisi verisi gönderir.
- `@Notification` agentından kişisel kampanya bildirimi göndermesini ister.

Yetki sınırı:

- MF Points bakiyesi veya ledger yazmaz.
- Stok/fiyat yönetmez.
- Sadece öneri sıralaması yapar.

## 3.11 `@PartnerCatalog`

Görev: Sponsor onboarding, ödül katalogu, stok, fiyat ve kampanya yaşam döngüsünü yönetir.

Ana sorumluluklar:

- Sponsor kayıtlarını ve anlaşma bilgilerini yönetir.
- Ödül katalogunu oluşturur.
- Stok ve kampanya durumunu günceller.
- Ödüllerin şehir, spor ve kullanıcı segmentine uygunluğunu belirler.
- Sponsor performansı için veri üretir.

Okuduğu veriler:

- sponsor contracts
- stock state
- reward performance
- redemption data

Yazdığı veya ürettiği çıktılar:

- `partners`
- `reward_catalog`
- `reward_inventory`
- `campaigns`

İlişkileri:

- `@EconomyEngine` agentına fiyat, stok ve sponsor value bilgisi verir.
- `@RewardPersonalization` agentına aktif ve uygun ödül listesini sağlar.
- `@AnalyticsAgent` agentına sponsor performansı gönderir.

Yetki sınırı:

- Kullanıcının reward eligibility kararını vermez.
- Kişisel öneri sıralaması yapmaz.
- MF Points ledger yazmaz.

## 3.12 `@ContextAgent`

Görev: Hava durumu, şehir, zaman dilimi, indoor/outdoor ve lokasyon bağlamı sağlar.

Ana sorumluluklar:

- Hava durumu verisini dış API veya cache üzerinden toplar.
- Şehir, ilçe ve zaman dilimi bağlamını normalize eder.
- Event için indoor/outdoor uygunluk sinyali üretir.
- Konum bağlamını Guardian ve Matchmaker agentlarına destek olarak sağlar.

Okuduğu veriler:

- weather/location APIs
- event city/district
- timezone
- POI/context kaynakları

Yazdığı veya ürettiği çıktılar:

- `context_snapshots`
- `weather_cache`
- `city_context`
- indoor/outdoor signal

İlişkileri:

- `@Matchmaker` agentına event uygunluk bağlamı verir.
- `@RewardPersonalization` agentına hava durumu ve şehir bağlamı verir.
- `@Guardian` agentına POI/context tutarsızlık sinyali verir.
- `@AnalyticsAgent` agentına context kullanım metrikleri gönderebilir.

Yetki sınırı:

- Event bloklama kararı vermez.
- Ödül önerisi yapmaz.
- Sadece bağlam verisi sağlar.

## 3.13 `@AnalyticsAgent`

Görev: Agent loglarını, ürün metriklerini, dashboard verilerini ve iş zekası çıktılarını toplar.

Ana sorumluluklar:

- Tüm agentlardan event toplar.
- Günlük agent health snapshot üretir.
- Admin panel ve BI araçları için özet veri sağlar.
- Fraud, economy, notification, ranking ve XP metriklerini raporlar.
- Sistem darboğazı veya anomali tespitine yardımcı olur.

Okuduğu veriler:

- agent event logs
- notification delivery/open/click
- XP eventleri
- ranking snapshotları
- economy ledger
- fraud risk/case verileri

Yazdığı veya ürettiği çıktılar:

- `analytics_events`
- `daily_agent_health`
- BI export snapshots
- admin dashboard metrics

İlişkileri:

- Tüm runtime agentlardan olay ve metrik alır.
- `@MatchFitReleaseCommander` agentına değişim ve risk özeti sağlayabilir.
- Admin panel veya raporlama katmanına veri verir.

Yetki sınırı:

- Kullanıcı davranışına doğrudan müdahale etmez.
- Ceza, XP, ekonomi veya ranking kararı vermez.
- Sadece ölçüm ve raporlama yapar.

## 3.14 `@MatchFitReleaseCommander`

Görev: Geliştirme sürecinde GitHub release, changelog, commit mesajı, versiyon ve risk raporu üretir.

Ana sorumluluklar:

- Değişen dosyaları analiz eder.
- Semantik versiyon önerir.
- Commit mesajı üretir.
- Changelog hazırlar.
- Risk seviyesini belirler.
- Migration, auth, UI, performans ve breaking change risklerini bildirir.

Okuduğu veriler:

- git status/diff
- migration dosyaları
- docs
- test sonuçları
- değişen Flutter kodları

Yazdığı veya ürettiği çıktılar:

- release report
- changelog
- commit message önerisi
- risk analysis

İlişkileri:

- GitHub/release süreciyle ilişkilidir.
- Runtime agentlarla doğrudan uygulama içi veri alışverişi yapmaz.
- `@AnalyticsAgent` çıktılarından release risk özeti alabilir.

Yetki sınırı:

- Uygulama kullanıcı verisine müdahale etmez.
- Runtime karar vermez.
- Sadece geliştirme ve release çıktısı üretir.

## 4. Kritik Veri Akışları

## 4.1 Trust Score Akışı

Trust Score, MatchFit güven sisteminin merkezi değişkenidir.

Akış:

1. `@Guardian` anlık güvenlik sinyali üretir.
2. `@FraudDetection` uzun vadeli risk analizi üretir.
3. `@Referee` katılım/check-in/no-show davranışını işler.
4. `@Referee` Trust Score'u günceller.
5. `@XPEngine`, `@RankingEngine` ve `@EconomyEngine` bu skoru okur.

Kural:

- Trust Score'u yalnızca `@Referee` yazar.
- Diğer agentlar Trust Score'u sadece okur veya sinyal gönderir.

## 4.2 Etkinlik Yaşam Döngüsü

1. Kullanıcı event oluşturmak ister.
2. `@Guardian` kullanıcı hakkını ve event lokasyonunu kontrol eder.
3. `@Matchmaker` event'i uygun kullanıcılara önerir.
4. `@Notification` davet veya öneri bildirimi gönderir.
5. Etkinlik zamanı geldiğinde `@Referee` check-in sürecini yönetir.
6. Başarılı event sonrası `@XPEngine`, XP hesaplar.
7. `@RankingEngine`, leaderboard günceller.
8. `@EconomyEngine`, MF Points veya reward eligibility günceller.
9. `@ContentManager`, post-event paylaşım akışını başlatır.
10. `@AnalyticsAgent`, tüm lifecycle metriklerini toplar.

## 4.3 Anti-Abuse Akışı

1. `@Guardian` anlık riskli durumları yakalar.
2. `@FraudDetection` davranış paternlerini analiz eder.
3. `@Referee`, kesinleşen davranış etkisini Trust Score'a işler.
4. `@EconomyEngine`, reward ve MF Points erişimini sınırlar.
5. `@RankingEngine`, sıralama etkisini azaltır veya kullanıcıyı dışlar.
6. `@Notification`, gerekli uyarıyı kullanıcıya iletir.
7. `@AnalyticsAgent`, fraud trendlerini raporlar.

## 4.4 Reward ve Ekonomi Akışı

1. `@PartnerCatalog` aktif ödül, sponsor ve stok bilgisini sağlar.
2. `@EconomyEngine`, kullanıcının reward eligibility ve MF Points limitlerini kontrol eder.
3. `@ContextAgent`, hava durumu ve şehir bağlamı sağlar.
4. `@RewardPersonalization`, kullanıcıya en uygun ödülleri sıralar.
5. Kullanıcı redemption yaptığında `@EconomyEngine` ledger kaydı oluşturur.
6. `@Notification`, redemption sonucunu bildirir.
7. `@AnalyticsAgent`, sponsor ve ekonomi performansını raporlar.

## 5. Agent İlişki Matrisi

| Kaynak Agent | Hedef Agent | Veri / Sinyal | Kritiklik |
| --- | --- | --- | --- |
| `@Referee` | `@XPEngine` | Trust Score, no-show, check-in outcome | Kritik |
| `@Matchmaker` | `@XPEngine` | Oyuncu çeşitliliği, branş sinyali | Orta |
| `@Guardian` | `@XPEngine` | Abuse detection sinyali | Kritik |
| `@XPEngine` | `@RankingEngine` | XP güncellemesi | Kritik |
| `@Referee` | `@RankingEngine` | Trust Score, ceza durumu | Kritik |
| `@FraudDetection` | `@RankingEngine` | Abuse flag | Yüksek |
| `@Matchmaker` | `@RankingEngine` | Branş/şehir filtresi | Orta |
| `@FraudDetection` | `@EconomyEngine` | Risk skoru, ceza önerisi | Kritik |
| `@Referee` | `@EconomyEngine` | Trust Score gating | Kritik |
| `@XPEngine` | `@EconomyEngine` | Level/rank etkisi | Yüksek |
| `@EconomyEngine` | `@RewardPersonalization` | Reward eligibility | Kritik |
| `@RewardPersonalization` | `@EconomyEngine` | Redemption etkisi | Orta |
| `@Guardian` | `@FraudDetection` | Fake event, POI, scam sinyali | Yüksek |
| `@Guardian` | `@Referee` | Güvenlik sinyali | Yüksek |
| `@Referee` | `@ContentManager` | Tamamlanan event verisi | Orta |
| `@Matchmaker` | `@Referee` | Katılımcı listesi | Yüksek |
| `@FraudDetection` | `@Guardian` | Shadow restriction önerisi | Yüksek |
| Tüm runtime agentlar | `@Notification` | Bildirim talebi | Yüksek |
| Tüm runtime agentlar | `@AnalyticsAgent` | Event ve metrik | Orta |
| `@PartnerCatalog` | `@EconomyEngine` | Stok, fiyat, sponsor value | Kritik |
| `@PartnerCatalog` | `@RewardPersonalization` | Aktif ödül listesi | Kritik |
| `@ContextAgent` | `@Matchmaker` | Şehir, hava, zaman bağlamı | Orta |
| `@ContextAgent` | `@RewardPersonalization` | Hava durumu ve lokasyon bağlamı | Yüksek |
| `@ContextAgent` | `@Guardian` | POI/context tutarsızlık sinyali | Yüksek |
| `@MatchFitReleaseCommander` | GitHub | Commit, changelog, release | Düşük |

## 6. Eksik Kodlama Alanları

Bu doküman mimariyi tamamlar; bazı agentlar henüz kod tarafında tam uygulanmamıştır.

Öncelikli eksikler:

- `@XPEngine` için XP tabloları ve repository/service katmanı.
- `@RankingEngine` için leaderboard snapshot yapısı.
- `@FraudDetection` için fraud signal/case/risk score modeli.
- `@EconomyEngine` için MF Points ledger ve redemption akışı.
- `@PartnerCatalog` için sponsor, reward catalog ve inventory tabloları.
- `@ContextAgent` için weather/context cache katmanı.
- `@AnalyticsAgent` için event collector ve daily health snapshot.

## 7. Sonuç

MatchFit agent mimarisi toplam 14 agenttan oluşur. Bu yapı uygulamanın güvenlik, etkinlik, sosyal, XP, ranking, ekonomi, ödül, bildirim ve raporlama alanlarını birbirinden ayırır.

En kritik mimari kararlar:

- `@Referee` Trust Score otoritesidir.
- `@Guardian` gerçek zamanlı güvenlikten sorumludur.
- `@FraudDetection` asenkron fraud analizinden sorumludur.
- `@Notification` tüm bildirimlerin merkezi kapısıdır.
- `@EconomyEngine` ekonomi adaletini, `@RewardPersonalization` kişisel öneriyi, `@PartnerCatalog` katalog ve stok doğruluğunu yönetir.
- `@AnalyticsAgent` büyüme ve operasyon görünürlüğü sağlar.

