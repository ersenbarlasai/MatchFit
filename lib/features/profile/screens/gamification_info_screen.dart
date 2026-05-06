import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../models/trust_system.dart';

class GamificationInfoScreen extends StatelessWidget {
  const GamificationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Oyunlaştırma ve İlerleme',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: const GamificationRulesContent(),
    );
  }
}

class GamificationRulesContent extends StatelessWidget {
  const GamificationRulesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildIntroSection(),
        const SizedBox(height: 32),
        _buildBadgeSection(),
        const SizedBox(height: 32),
        _buildTierSection(),
        const SizedBox(height: 32),
        _buildLevelUpSection(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sports_esports_outlined, color: MatchFitTheme.accentGreen, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MatchFit Evreni',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'MatchFit sadece bir etkinlik platformu değil, aynı zamanda güvenilir ve aktif oyuncuların ödüllendirildiği bir oyunlaştırma evrenidir. Seviyeni yükselt, rozetleri topla ve avantajlardan faydalan.',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Rozet Yapısı (Badges)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        ...kAllBadges.map((badge) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badge.color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: badge.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badge.icon, color: badge.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildTierSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Kalite ve Güven (Tier Sistemi)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Güven Seviyeleri (Trust Levels)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Trust Score'unuza (0-100) göre profilinde farklı seviyeler görünür:",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...kTrustLevels.values.map((lvl) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Text(lvl.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Text(
                          '${lvl.label} ',
                          style: TextStyle(color: lvl.color, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '(${lvl.minScore}-${lvl.maxScore} Puan)',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                  )),
              const Divider(color: Colors.white10, height: 32),
              const Text(
                'Etkinlik Kalitesi & XP Çarpanı',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Katıldığın etkinliklerin kalitesi ve senin davranışların XP kazanımını doğrudan etkiler:',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildMultiplierRow('S-Tier (Kusursuz)', '1.4x Çarpan', Colors.amber),
              _buildMultiplierRow('A-Tier (İyi)', '1.2x Çarpan', Colors.blue),
              _buildMultiplierRow('B-Tier (Normal)', '1.0x Standart', Colors.white70),
              _buildMultiplierRow('C-Tier (Kötü)', '0.7x Ceza Çarpanı', Colors.redAccent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiplierRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. XP ve Seviye Atlama',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nasıl Level Atlarım?',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Sistemdeki ana kural şudur: Her 1.000 XP barajını aştığında otomatik olarak Seviye (Level) atlarsın. Seviyeni hızlı yükseltmek için sadece çok etkinliğe katılmak yetmez; güvenilir olmak ve seriyi (streak) korumak gerekir.',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              const Text('Taban Puanlar:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildBulletPoint('Host (Oluşturan): Tamamlandığında ~45 XP & ~10 MF*'),
              _buildBulletPoint('Guest (Katılımcı): Check-in yapıldığında ~40 XP & ~10 MF*'),
              _buildBulletPoint('Günlük Giriş: Her gün ilk açılışta +10 XP & +5 MF'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 14.0),
                child: Text(
                  "* MF Puanları; Trust Score'un yüksekse, etkinlik kalitesi kusursuzsa ve streak serin varsa çarpanlarla katlanarak artar.",
                  style: TextStyle(color: MatchFitTheme.accentGreen.withOpacity(0.8), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Bonuslar ve Çarpanlar:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildBulletPoint('İlk etkinlik bonusu: +20 XP'),
              _buildBulletPoint('Yeni branş deneme: +10 XP'),
              _buildBulletPoint('Arkadaş davetiyle katılım: Kişi başı +15 XP'),
              const SizedBox(height: 8),
              _buildBulletPoint('Streak (Seri): 30 günün sonunda %25 ekstra (1.25x) XP çarpanı.'),
              _buildBulletPoint("Integrity: Trust Score'u 80'in üzerinde olanlar %20 ekstra (1.2x) çarpan kazanır."),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 8.0),
            child: Icon(Icons.circle, color: MatchFitTheme.accentGreen, size: 6),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
