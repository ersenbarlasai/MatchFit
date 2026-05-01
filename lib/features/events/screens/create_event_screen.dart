import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../repositories/event_repository.dart';
import '../../auth/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../referee/repositories/referee_repository.dart';
import '../../guardian/repositories/guardian_repository.dart';
import 'package:matchfit/core/services/location_search_service.dart';
import 'package:matchfit/core/constants/location_data.dart';
import 'package:matchfit/core/constants/sports_data.dart';
import 'dart:async';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _venueController = TextEditingController(); // Replaced _locationController with _venueController
  final _descriptionController = TextEditingController();
  
  String selectedCountry = 'Türkiye';
  String? selectedProvince;
  String? selectedDistrict;
  
  String? selectedCategory;
  String? selectedSport; // This will now be the sub-category
  String requiredLevel = 'Any';
  bool isIndoor = false;
  double maxParticipants = 2;
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
  Future<void> _publishEvent() async {
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
      final authRepo = ref.read(authRepositoryProvider);
      final currentUser = authRepo.currentUser;
      if (currentUser == null) throw Exception('You must be logged in to create an event');

      // @Referee Agent Restriction Check
      final refereeRepo = ref.read(refereeRepositoryProvider);
      final isRestricted = await refereeRepo.isUserRestricted(currentUser.id);
      if (isRestricted) {
        throw Exception('Referee Agent: You are currently in "Bench Mode" due to a penalty. You cannot create new events right now.');
      }

      // @Guardian Agent — 48-hour new user barrier
      // POST-MVP: Enable this when going to production.
      // Currently disabled to allow testing. In production, this prevents
      // fake event creation by brand-new accounts.
      //
      // final guardianRepo = ref.read(guardianRepositoryProvider);
      // final canCreate = await guardianRepo.canCreateEvent(currentUser.id);
      // if (!canCreate) {
      //   throw Exception('Guardian Agent: New accounts must wait 48 hours before creating an event.');
      // }

      // Fetch the sport_id from Supabase
      final sportResponse = await Supabase.instance.client
          .from('sports')
          .select('id')
          .eq('name', selectedSport!)
          .maybeSingle();
          
      if (sportResponse == null) {
        throw Exception('Sport "$selectedSport" not found in database. Make sure to seed the sports table!');
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
        'host_id': currentUser.id,
      };

      await ref.read(eventRepositoryProvider).createEvent(eventData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event published successfully!')),
        );
        context.pop();
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
        title: const Text('Create Event'),
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
              decoration: const InputDecoration(
                labelText: 'Event Title',
                hintText: 'e.g. Morning Tennis Match',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Sport Category Dropdown
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Main Category', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
              items: sportsData.map((c) => DropdownMenuItem<String>(value: c.name, child: Text(c.name))).toList(),
              onChanged: (value) => setState(() {
                selectedCategory = value;
                selectedSport = null; // Reset subcategory
              }),
            ),
            const SizedBox(height: 16),

            // Sub-category Dropdown
            DropdownButtonFormField<String>(
              value: selectedSport,
              hint: const Text('Select Sub-branch'),
              decoration: const InputDecoration(labelText: 'Sub-branch', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
              items: (selectedCategory != null 
                ? sportsData.firstWhere((c) => c.name == selectedCategory).subcategories 
                : <String>[])
                  .map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                  .toList(),
              onChanged: (value) => setState(() => selectedSport = value),
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
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(selectedDate == null ? 'Select Date' : '${selectedDate!.day}/${selectedDate!.month}'),
                        ],
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
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) setState(() => selectedTime = time);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(selectedTime == null ? 'Select Time' : selectedTime!.format(context)),
                        ],
                      ),
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
            const Text('Max Participants', style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: maxParticipants,
              min: 2,
              max: 20,
              divisions: 18,
              label: maxParticipants.round().toString(),
              activeColor: MatchFitTheme.primaryBlue,
              onChanged: (value) => setState(() => maxParticipants = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: requiredLevel,
              decoration: const InputDecoration(
                labelText: 'Required Skill Level',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              items: <String>['Any', 'Beginner', 'Intermediate', 'Advanced']
                  .map<DropdownMenuItem<String>>((level) => DropdownMenuItem<String>(value: level, child: Text(level)))
                  .toList(),
              onChanged: (value) => setState(() => requiredLevel = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _publishEvent,
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Publish Event', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
