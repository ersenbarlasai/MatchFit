import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matchfit/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/coach_provider.dart';

class CoachAvailabilityScreen extends ConsumerStatefulWidget {
  const CoachAvailabilityScreen({super.key});

  @override
  ConsumerState<CoachAvailabilityScreen> createState() => _CoachAvailabilityScreenState();
}

class _CoachAvailabilityScreenState extends ConsumerState<CoachAvailabilityScreen> {
  final List<Map<String, dynamic>> _slots = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  void _loadAvailability() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final slots = await ref.read(coachEngineRepositoryProvider).getCoachAvailability(userId);
      setState(() {
        _slots.clear();
        _slots.addAll(slots);
      });
    } catch (e) {
      debugPrint('Error loading availability: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addSlot() async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'BAŞLANGIÇ SAATİ',
    );
    if (start == null) return;

    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
      helpText: 'BİTİŞ SAATİ',
    );
    if (end == null) return;

    if (!mounted) return;
    final int? selectedDay = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Gün Seçin'),
        children: [
          _dayOption(context, 'Pazartesi', 1),
          _dayOption(context, 'Salı', 2),
          _dayOption(context, 'Çarşamba', 3),
          _dayOption(context, 'Perşembe', 4),
          _dayOption(context, 'Cuma', 5),
          _dayOption(context, 'Cumartesi', 6),
          _dayOption(context, 'Pazar', 0),
        ],
      ),
    );
    if (selectedDay == null) return;

    if (!mounted) return;
    final locationController = TextEditingController();
    final String? location = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konum'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(hintText: 'Örn: Ana Saha, Fitness Salonu'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, locationController.text), child: const Text('Ekle')),
        ],
      ),
    );

    setState(() {
      _slots.add({
        'day_of_week': selectedDay,
        'start_time': '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
        'end_time': '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
        'location_name': location ?? 'Belirtilmedi',
      });
    });
  }

  Widget _dayOption(BuildContext context, String label, int value) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: Text(label),
    );
  }

  void _save() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(coachEngineRepositoryProvider).upsertCoachAvailability(_slots);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uygunluk saatleriniz güncellendi.'), backgroundColor: MatchFitTheme.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _dayName(int day) {
    switch (day) {
      case 1: return 'Pazartesi';
      case 2: return 'Salı';
      case 3: return 'Çarşamba';
      case 4: return 'Perşembe';
      case 5: return 'Cuma';
      case 6: return 'Cumartesi';
      case 0: return 'Pazar';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Uygunluk Saatlerim', style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MatchFitTheme.accentGreen.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: MatchFitTheme.accentGreen, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Haftalık tekrarlanan çalışma saatlerinizi ekleyin. Öğrenciler bu saatler arasından randevu alabilir.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _slots.isEmpty 
                  ? const Center(child: Text('Henüz saat eklenmemiş.', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _slots.length,
                      itemBuilder: (context, index) {
                        final slot = _slots[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151515),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_dayName(slot['day_of_week']), style: const TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('${slot['start_time']} - ${slot['end_time']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Text(slot['location_name'] ?? 'Konum belirtilmedi', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => setState(() => _slots.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addSlot,
                        icon: const Icon(Icons.add),
                        label: const Text('Saat Ekle'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MatchFitTheme.accentGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
