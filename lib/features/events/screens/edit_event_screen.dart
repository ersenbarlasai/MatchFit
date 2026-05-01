import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../repositories/event_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/core/services/location_search_service.dart';
import 'package:matchfit/core/constants/location_data.dart';
import 'package:matchfit/core/constants/sports_data.dart';
import 'dart:async';

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

  // Location search state
  final _searchService = LocationSearchService();
  List<LocationSuggestion> _suggestions = [];
  Timer? _debounce;
  double? _selectedLat;
  double? _selectedLng;

  void _onLocationChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (value.length > 2) {
        final contextStr = '${selectedDistrict ?? ''} ${selectedProvince ?? ''} $selectedCountry';
        final results = await _searchService.search('$value $contextStr'.trim());
        setState(() => _suggestions = results);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e['title']);
    _venueController = TextEditingController(text: ''); // Reset venue or try to parse
    _descriptionController = TextEditingController(text: e['description']);
    
    // Attempt to parse old location name if it follows the new format
    final oldLoc = e['location_name'] ?? e['location_text'] ?? '';
    if (oldLoc.contains(',')) {
      final parts = oldLoc.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 3) {
        selectedDistrict = parts[0];
        selectedProvince = parts[1];
        selectedCountry = parts[2].split('-')[0].trim(); // Handle " - Venue"
        if (oldLoc.contains(' - ')) {
          _venueController.text = oldLoc.split(' - ').last;
        }
      }
    }
    
    selectedSport = e['sports']?['name'] ?? 'Tenis';
    // Find category for initial sport
    try {
      selectedCategory = sportsData.firstWhere((c) => c.subcategories.contains(selectedSport)).name;
    } catch (_) {
      selectedCategory = 'RAKET SPORLARI';
    }

    requiredLevel = e['required_level'] ?? 'Any';
    isIndoor = e['is_indoor'] as bool? ?? false;
    maxParticipants = (e['max_participants'] as num?)?.toDouble() ?? 2.0;
    
    if (e['event_date'] != null) {
      selectedDate = DateTime.parse(e['event_date']);
    }
    
    if (e['start_time'] != null) {
      final parts = (e['start_time'] as String).split(':');
      if (parts.length >= 2) {
        selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    
    _selectedLat = (e['lat'] as num?)?.toDouble();
    _selectedLng = (e['lng'] as num?)?.toDouble();
  }

  Future<void> _updateEvent() async {
    String? error;
    if (_titleController.text.isEmpty) error = 'Event Title is required';
    else if (selectedCategory == null) error = 'Main Category is required';
    else if (selectedSport == null) error = 'Sub-branch is required';
    else if (selectedDate == null) error = 'Date is required';
    else if (selectedTime == null) error = 'Time is required';
    else if (selectedProvince == null) error = 'City is required';
    else if (selectedDistrict == null) error = 'District is required';

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final sportResponse = await Supabase.instance.client
          .from('sports')
          .select('id')
          .eq('name', selectedSport)
          .maybeSingle();
          
      if (sportResponse == null) {
        throw Exception('Sport "$selectedSport" not found');
      }

      final eventDate = DateTime(
        selectedDate!.year, selectedDate!.month, selectedDate!.day,
      );
      
      final formattedTime = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00';

      final fullLocationName = '$selectedDistrict, $selectedProvince, $selectedCountry${_venueController.text.isNotEmpty ? ' - ${_venueController.text}' : ''}';

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

      await ref.read(eventRepositoryProvider).updateEvent(widget.event['id'].toString(), eventData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
        // Go back to home to refresh lists or use context.pop()
        // context.go('/home'); 
        context.pop(); // Pop back to detail screen. Detail screen needs to refresh though.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
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
              decoration: const InputDecoration(labelText: 'Event Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            // Sport Category Dropdown
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Main Category', border: OutlineInputBorder()),
              items: sportsData.map((c) => DropdownMenuItem<String>(value: c.name, child: Text(c.name))).toList(),
              onChanged: (value) => setState(() {
                selectedCategory = value;
                // selectedSport = null; // Edit mode: keep old or pick first sub
              }),
            ),
            const SizedBox(height: 16),

            // Sub-category Dropdown
            DropdownButtonFormField<String>(
              value: selectedSport,
              decoration: const InputDecoration(labelText: 'Sub-branch', border: OutlineInputBorder()),
              items: (selectedCategory != null 
                ? sportsData.firstWhere((c) => c.name == selectedCategory).subcategories 
                : <String>[])
                  .map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                  .toList(),
              onChanged: (value) => setState(() => selectedSport = value!),
            ),
            const SizedBox(height: 16),

            // Indoor / Outdoor
            Row(
              children: [
                const Text('Setting:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Outdoor'),
                  selected: !isIndoor,
                  onSelected: (val) => setState(() => isIndoor = !val),
                  selectedColor: MatchFitTheme.accentGreen.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Indoor'),
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
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                      child: Text(selectedDate == null ? 'Select Date' : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
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
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                      child: Text(selectedTime == null ? 'Select Time' : selectedTime!.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            // Country Dropdown
            DropdownButtonFormField<String>(
              value: selectedCountry,
              decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
              items: countries.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() {
                selectedCountry = val!;
                selectedProvince = null;
                selectedDistrict = null;
              }),
            ),
            const SizedBox(height: 12),

            // Province Dropdown
            DropdownButtonFormField<String>(
              value: selectedProvince,
              hint: const Text('Select City (İl)'),
              decoration: const InputDecoration(labelText: 'City (İl)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
              items: turkeyProvinces.keys.toList().map<DropdownMenuItem<String>>((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
              onChanged: (val) => setState(() {
                selectedProvince = val;
                selectedDistrict = null;
              }),
            ),
            const SizedBox(height: 12),

            // District Dropdown
            DropdownButtonFormField<String>(
              value: selectedDistrict,
              hint: const Text('Select District (İlçe)'),
              decoration: const InputDecoration(labelText: 'District (İlçe)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
              items: (selectedProvince != null ? turkeyProvinces[selectedProvince]! : <String>[])
                  .map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) => setState(() => selectedDistrict = val),
            ),
            const SizedBox(height: 16),

            // Venue Search
            TextField(
              controller: _venueController,
              onChanged: _onLocationChanged,
              decoration: const InputDecoration(
                labelText: 'Venue / Street (Optional)',
                hintText: 'Search for a specific park, court...',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final s = _suggestions[index];
                    return ListTile(
                      title: Text(s.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      onTap: () {
                        setState(() {
                          _venueController.text = s.description;
                          _selectedLat = s.lat;
                          _selectedLng = s.lng;
                          _suggestions = [];
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            Text('Max Participants: ${maxParticipants.round()}'),
            Slider(
              value: maxParticipants,
              min: 2, max: 30, divisions: 28,
              onChanged: (v) => setState(() => maxParticipants = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: requiredLevel,
              decoration: const InputDecoration(labelText: 'Required Skill Level', border: OutlineInputBorder()),
              items: <String>['Any', 'Beginner', 'Intermediate', 'Advanced']
                  .map<DropdownMenuItem<String>>((level) => DropdownMenuItem<String>(value: level, child: Text(level)))
                  .toList(),
              onChanged: (value) => setState(() => requiredLevel = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
