import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../repositories/event_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/core/constants/location_data.dart';
import 'package:matchfit/core/constants/sports_data.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const EditEventScreen({super.key, required this.event});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _venueController;
  late final TextEditingController _descriptionController;

  String selectedCountry = 'Türkiye';
  String? selectedProvince;
  String? selectedDistrict;

  String? selectedCategory;
  late String selectedSport;
  late String requiredLevel;
  late bool isIndoor;
  late double maxParticipants;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool _isLoading = false;

  double? _selectedLat;
  double? _selectedLng;

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e['title']);
    _venueController = TextEditingController(text: '');
    _descriptionController = TextEditingController(text: e['description']);

    final oldLoc = e['location_name'] ?? e['location_text'] ?? '';
    if (oldLoc.contains(',')) {
      final parts = oldLoc.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 3) {
        selectedDistrict = parts[0];
        selectedProvince = parts[1];
        selectedCountry = parts[2].split('-')[0].trim();
        if (oldLoc.contains(' - ')) {
          _venueController.text = oldLoc.split(' - ').last;
        }
      }
    }

    selectedSport = e['sports']?['name'] ?? 'Tenis';
    try {
      selectedCategory = sportsData
          .firstWhere((c) => c.subcategories.contains(selectedSport))
          .name;
    } catch (_) {
      selectedCategory = 'RAKET SPORLARI';
    }

    requiredLevel = e['required_level'] ?? 'Başlangıç';
    // Mapping for legacy/mixed data
    if (requiredLevel == 'Any' || requiredLevel == 'Beginner')
      requiredLevel = 'Başlangıç';
    if (requiredLevel == 'Intermediate') requiredLevel = 'Orta';
    if (requiredLevel == 'Advanced') requiredLevel = 'İleri';

    isIndoor = e['is_indoor'] as bool? ?? false;
    maxParticipants = (e['max_participants'] as num?)?.toDouble() ?? 12.0;

    if (e['event_date'] != null) {
      selectedDate = DateTime.parse(e['event_date']);
    }

    if (e['start_time'] != null) {
      final parts = (e['start_time'] as String).split(':');
      if (parts.length >= 2) {
        selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    _selectedLat = (e['lat'] as num?)?.toDouble();
    _selectedLng = (e['lng'] as num?)?.toDouble();
  }

  Future<void> _updateEvent() async {
    String? error;
    if (_titleController.text.isEmpty)
      error = 'Etkinlik başlığı gereklidir';
    else if (selectedCategory == null)
      error = 'Ana kategori gereklidir';
    else if (selectedDate == null)
      error = 'Tarih gereklidir';
    else if (selectedTime == null)
      error = 'Saat gereklidir';
    else if (selectedProvince == null)
      error = 'Şehir gereklidir';
    else if (selectedDistrict == null)
      error = 'İlçe gereklidir';

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final sportResponse = await Supabase.instance.client
          .from('sports')
          .select('id')
          .ilike('name', selectedSport)
          .maybeSingle();

      if (sportResponse == null) {
        throw Exception(
          '"$selectedSport" branşı veritabanında bulunamadı. Lütfen SQL scriptini çalıştırın.',
        );
      }

      final eventDate = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );

      final formattedTime =
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00';

      final fullLocationName =
          '$selectedDistrict, $selectedProvince, $selectedCountry${_venueController.text.isNotEmpty ? ' - ${_venueController.text}' : ''}';

      final eventData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'event_date': eventDate.toIso8601String().split('T')[0],
        'start_time': formattedTime,
        'location_name': fullLocationName,
        'lat': _selectedLat,
        'lng': _selectedLng,
        'max_participants': maxParticipants.toInt(),
        'required_level': requiredLevel,
        'is_indoor': isIndoor,
        'sport_id': sportResponse['id'],
      };

      await ref
          .read(eventRepositoryProvider)
          .updateEvent(widget.event['id'].toString(), eventData);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Etkinlik güncellendi!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Etkinliği Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Etkinlik Başlığı',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value:
                  (selectedCategory != null &&
                      sportsData.any((c) => c.name == selectedCategory))
                  ? selectedCategory
                  : null,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Ana Kategori',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              items: sportsData
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c.name,
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                selectedCategory = value;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value:
                  (selectedCategory != null &&
                      sportsData
                          .firstWhere((c) => c.name == selectedCategory)
                          .subcategories
                          .contains(selectedSport))
                  ? selectedSport
                  : null,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Alt Branş',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              items:
                  (selectedCategory != null
                          ? sportsData
                                .firstWhere((c) => c.name == selectedCategory)
                                .subcategories
                          : <String>[])
                      .map<DropdownMenuItem<String>>(
                        (s) =>
                            DropdownMenuItem<String>(value: s, child: Text(s)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => selectedSport = value!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Mekan:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Açık'),
                  selected: !isIndoor,
                  onSelected: (val) => setState(() => isIndoor = !val),
                  selectedColor: MatchFitTheme.accentGreen.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Kapalı'),
                  selected: isIndoor,
                  onSelected: (val) => setState(() => isIndoor = val),
                  selectedColor: MatchFitTheme.accentGreen.withOpacity(0.3),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selectedDate == null
                            ? 'Tarih Seç'
                            : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (time != null) setState(() => selectedTime = time);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selectedTime == null
                            ? 'Saat Seç'
                            : selectedTime!.format(context),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Konum',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedCountry,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Ülke',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              items: countries
                  .map<DropdownMenuItem<String>>(
                    (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                  )
                  .toList(),
              onChanged: (val) => setState(() {
                selectedCountry = val!;
                selectedProvince = null;
                selectedDistrict = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedProvince,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              hint: const Text(
                'Şehir Seç (İl)',
                style: TextStyle(color: Colors.white54),
              ),
              decoration: const InputDecoration(
                labelText: 'Şehir (İl)',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              items: turkeyProvinces.keys
                  .toList()
                  .map<DropdownMenuItem<String>>(
                    (p) => DropdownMenuItem<String>(value: p, child: Text(p)),
                  )
                  .toList(),
              onChanged: (val) => setState(() {
                selectedProvince = val;
                selectedDistrict = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedDistrict,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              hint: const Text(
                'İlçe Seç',
                style: TextStyle(color: Colors.white54),
              ),
              decoration: const InputDecoration(
                labelText: 'İlçe',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              items:
                  (selectedProvince != null
                          ? turkeyProvinces[selectedProvince]!
                          : <String>[])
                      .map<DropdownMenuItem<String>>(
                        (d) =>
                            DropdownMenuItem<String>(value: d, child: Text(d)),
                      )
                      .toList(),
              onChanged: (val) => setState(() => selectedDistrict = val),
            ),
            const SizedBox(height: 24),
            Text(
              'Maksimum Katılımcı: ${maxParticipants.round()}',
              style: const TextStyle(color: Colors.white),
            ),
            Slider(
              value: maxParticipants,
              min: 2,
              max: 50,
              divisions: 48,
              activeColor: MatchFitTheme.accentGreen,
              onChanged: (v) => setState(() => maxParticipants = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: requiredLevel,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Gerekli Seviye',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              items: <String>['Başlangıç', 'Orta', 'İleri']
                  .map<DropdownMenuItem<String>>(
                    (level) => DropdownMenuItem<String>(
                      value: level,
                      child: Text(
                        level,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => requiredLevel = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      'Değişiklikleri Kaydet',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
