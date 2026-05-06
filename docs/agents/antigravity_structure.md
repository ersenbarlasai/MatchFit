# MatchFit Antigravity Structure

## Stabil Kural Hiyerarşisi

Tek ana kaynak:

`docs/agents/CANONICAL_AGENT_ARCHITECTURE.md`

Antigravity/Codex giriş dosyaları bu dosyaya yönlendirir. Böylece aynı kuralın birkaç yerde farklılaşması engellenir.

## Kök Dosyalar

- `AGENTS.md`: Cross-tool kısa giriş ve canonical yönlendirme.
- `GEMINI.md`: Antigravity/Gemini kısa giriş ve canonical yönlendirme.
- `.agents`: Kısa MatchFit agent registry.

## Workspace Rule

- `.agent/rules/matchfit-workspace.md`: Antigravity workspace rule olarak kısa agent sınırları.

## Antigravity Paket Klasörü

- `antigravity/README.md`: Paket açıklaması.
- `antigravity/agents/agent_map.json`: Agentlar ve bağımlılıkların makine-okunabilir haritası.
- `antigravity/agents/workflows.md`: Önerilen agent workflow'ları.

## Kullanım

1. Antigravity'de proje kökünü `C:/Users/barlas/Desktop/MatchFit` olarak aç.
2. Agent'a önce `docs/agents/CANONICAL_AGENT_ARCHITECTURE.md` dosyasını okumasını söyle.
3. Runtime agent mimarisi değişirse `.agents` ve `docs/agents/` birlikte güncellenmeli.
4. Kod üretiminde Trust Score, notification, economy ve fraud sorumluluk sınırları korunmalı.
