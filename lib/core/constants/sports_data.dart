class SportCategory {
  final String name;
  final List<String> subcategories;
  final String icon; // Icon name or path

  SportCategory({required this.name, required this.subcategories, required this.icon});
}

final List<SportCategory> sportsData = [
  SportCategory(
    name: 'RAKET SPORLARI',
    subcategories: ['Tenis', 'Padel', 'Masa Tenisi'],
    icon: 'sports_tennis',
  ),
  SportCategory(
    name: 'TAKIM SPORLARI',
    subcategories: ['Basketbol', 'Futbol / Halı Saha', 'Voleybol'],
    icon: 'groups',
  ),
  SportCategory(
    name: 'KOŞU & KARDİYO',
    subcategories: ['Yol Koşusu', 'Trail Run', 'Sprint / Interval'],
    icon: 'directions_run',
  ),
  SportCategory(
    name: 'BİSİKLET',
    subcategories: ['Yol Bisikleti', 'MTB (Dağ Bisikleti)', 'Şehir / Grup Sürüşü'],
    icon: 'directions_bike',
  ),
  SportCategory(
    name: 'FITNESS & GYM',
    subcategories: ['Ağırlık Antrenmanı', 'Functional Training', 'Cross Training'],
    icon: 'fitness_center',
  ),
  SportCategory(
    name: 'YÜRÜYÜŞ & HIKING',
    subcategories: ['Tempolu Yürüyüş', 'Trekking', 'Doğa Yürüyüşü'],
    icon: 'terrain',
  ),
  SportCategory(
    name: 'SU SPORLARI',
    subcategories: ['Yüzme', 'Kürek / Paddle', 'Sörf / SUP'],
    icon: 'waves',
  ),
  SportCategory(
    name: 'DÖVÜŞ SPORLARI',
    subcategories: ['Boks', 'Kick Boks / MMA', 'Jiu Jitsu / Grappling'],
    icon: 'sports_mma',
  ),
  SportCategory(
    name: 'ZİHİN & DENGE',
    subcategories: ['Yoga', 'Pilates', 'Meditasyon Hareketi'],
    icon: 'self_improvement',
  ),
  SportCategory(
    name: 'KIŞ & EKSTREM',
    subcategories: ['Kayak / Snowboard', 'Tırmanış / Boulder', 'Skate / Roller'],
    icon: 'ac_unit',
  ),
  SportCategory(
    name: 'GENÇLİK & URBAN SPORTS',
    subcategories: ['Calisthenics', 'Street Workout', 'Parkour'],
    icon: 'reorder',
  ),
  SportCategory(
    name: 'MOTORLU AKTİVİTE',
    subcategories: ['Motocross', 'ATV Ride', 'Enduro Grup Sürüşü'],
    icon: 'motorcycle',
  ),
];
