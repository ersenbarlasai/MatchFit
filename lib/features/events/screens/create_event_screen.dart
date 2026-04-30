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
import 'dart:async';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String selectedSport = 'Tennis';
  String requiredLevel = 'Any';
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
        final results = await _searchService.search(value);
        setState(() => _suggestions = results);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _publishEvent() async {
    if (_titleController.text.isEmpty || selectedDate == null || selectedTime == null || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
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
          .eq('name', selectedSport)
          .maybeSingle();
          
      if (sportResponse == null) {
        throw Exception('Sport "$selectedSport" not found in database. Make sure to seed the sports table!');
      }

      final eventDate = DateTime(
        selectedDate!.year, selectedDate!.month, selectedDate!.day,
      );
      
      final formattedTime = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00';

      final eventData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'event_date': eventDate.toIso8601String().split('T')[0],
        'start_time': formattedTime,
        'location_name': _locationController.text,
        'lat': _selectedLat,
        'lng': _selectedLng,
        'max_participants': maxParticipants.toInt(),
        'required_level': requiredLevel,
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
            DropdownButtonFormField<String>(
              value: selectedSport,
              decoration: const InputDecoration(
                labelText: 'Sport',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              items: ['Tennis', 'Running', 'Basketball', 'Football']
                  .map((sport) => DropdownMenuItem(value: sport, child: Text(sport)))
                  .toList(),
              onChanged: (value) => setState(() => selectedSport = value!),
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
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              onChanged: _onLocationChanged,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Search for a court or park...',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
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
                          _locationController.text = s.description;
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
              items: ['Any', 'Beginner', 'Intermediate', 'Advanced']
                  .map((level) => DropdownMenuItem(value: level, child: Text(level)))
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
