import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../repositories/event_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const EditEventScreen({super.key, required this.event});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  
  late String selectedSport;
  late String requiredLevel;
  late double maxParticipants;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e['title']);
    _locationController = TextEditingController(text: e['location_name'] ?? e['location_text']);
    _descriptionController = TextEditingController(text: e['description']);
    
    selectedSport = e['sports']?['name'] ?? 'Tennis';
    requiredLevel = e['required_level'] ?? 'Any';
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
  }

  Future<void> _updateEvent() async {
    if (_titleController.text.isEmpty || selectedDate == null || selectedTime == null || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
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

      final eventData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'event_date': eventDate.toIso8601String().split('T')[0],
        'start_time': formattedTime,
        'location_name': _locationController.text,
        'max_participants': maxParticipants.toInt(),
        'required_level': requiredLevel,
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
            DropdownButtonFormField<String>(
              value: selectedSport,
              decoration: const InputDecoration(labelText: 'Sport', border: OutlineInputBorder()),
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
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on), border: OutlineInputBorder()),
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
              items: ['Any', 'Beginner', 'Intermediate', 'Advanced']
                  .map((level) => DropdownMenuItem(value: level, child: Text(level)))
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
