# Coach System Agents

Bu dosya MatchFit "Verified Coach" sistemini yöneten agent'ların yetki, görev ve sınırlarını tanımlar.

## 1. @CoachVerificationAgent
**Rolü:** Koç başvurularının ilk incelemesini ve evrak doğrulamasını yapar.
**Yetki Alanı:** `coaches`, `coach_documents`
**Sınırları:** Sadece belge geçerliliğini ve kimlik doğrulamasını (KYC) onaylar. Maçlara veya ödemelere karışamaz.
**Aksiyonlar:**
- `document_approved` / `document_rejected`
- `verification_level` güncellemesi (pending -> basic -> certified)

## 2. @GuardianAgent (Extended for Coaches)
**Rolü:** Sahte koçları ve istismar girişimlerini engeller.
**Yetki Alanı:** `coach_documents` (hash kontrolü), `coach_verification_logs`
**Sınırları:** Puan hesaplamaz, sadece fraud tespit ettiğinde koçu suspend (askıya alma) eder veya Elite statüsünden düşürür.
**Aksiyonlar:**
- Aynı TC kimlik/belge ile açılan farklı hesapları tespit edip engeller.
- Aşırı kısa sürede çok fazla seans açan koçları flag'ler.

## 3. @RefereeAgent (Coach Mode)
**Rolü:** Seansların (derslerin) fiilen gerçekleşip gerçekleşmediğini denetler.
**Yetki Alanı:** `events` (is_coach_session = true), `event_participants`, `coach_reviews`
**Sınırları:** Belge onayına karışmaz. Sadece GPS konum teyidi (check-in) ve dersin tamamlanma durumuna bakar.
**Aksiyonlar:**
- Öğrenci check-in yaptı mı?
- Koç lokasyonda mıydı?
- No-show (gelmeme) durumunda `reliability_score` düşürülmesini tetikler.

## 4. @CoachReputationAgent
**Rolü:** Koçun kalitesini, puanını ve arama/listeleme (ranking) sırasını belirler.
**Yetki Alanı:** `coaches` (reliability_score, rating_avg), `coach_reviews`
**Sınırları:** Ödemelere karışmaz, sadece performans skorunu hesaplar.
**Aksiyonlar:**
- Ders tamamlama oranı, iptal oranı ve kullanıcı yorumlarını harmanlayarak Coach Score'u (0-100) günceller.
- Skoru 90+ olanları "Elite" seviyesine yükseltir.

## 5. @MonetizationAgent
**Rolü:** Ücretli seansların finansal akışını, platform komisyonlarını ve öne çıkma (boost) harcamalarını yönetir.
**Yetki Alanı:** `events` (price), `coaches` (commission_rate, is_featured)
**Sınırları:** Koçun kalitesine veya belgelerine karışmaz, sadece para akışını hesaplar.
**Aksiyonlar:**
- Seans ücretinden komisyonu kesip net kazancı hesaplar.
- Koç "Öne Çıkar" (Boost) paketi alırsa `is_featured = true` yapar.
