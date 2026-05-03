import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLocale { tr, en }

final localeProvider = StateProvider<AppLocale>((ref) => AppLocale.tr);

class LocaleService {
  static String tr(String key, {AppLocale locale = AppLocale.tr}) {
    // Simple dictionary for now
    final Map<AppLocale, Map<String, String>> localizedValues = {
      AppLocale.tr: {
        'create_event': 'Etkinlik Oluştur',
        'next_step': 'SONRAKİ ADIM',
        'publish_event': 'ETKİNLİĞİ YAYINLA',
        'beginner': 'Başlangıç',
        'intermediate': 'Orta',
        'advanced': 'İleri',
        'venue': 'Mekan',
        'indoor': 'Kapalı',
        'outdoor': 'Açık',
        // Add more as needed
      },
      AppLocale.en: {
        'create_event': 'Create Event',
        'next_step': 'NEXT STEP',
        'publish_event': 'PUBLISH EVENT',
        'beginner': 'Beginner',
        'intermediate': 'Intermediate',
        'advanced': 'Advanced',
        'venue': 'Venue',
        'indoor': 'Indoor',
        'outdoor': 'Outdoor',
      }
    };
    return localizedValues[locale]?[key] ?? key;
  }
}
