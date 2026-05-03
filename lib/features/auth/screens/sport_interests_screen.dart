import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SportInterestsScreen extends StatefulWidget {
  const SportInterestsScreen({super.key});

  @override
  State<SportInterestsScreen> createState() => _SportInterestsScreenState();
}

class _SportInterestsScreenState extends State<SportInterestsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allSports = [];
  bool _isLoading = true;
  bool _isSaving = false;
  
  final Set<String> selectedSportIds = {};
  String selectedLevel = 'beginner'; // beginner, intermediate, advanced

  @override
  void initState() {
    super.initState();
    _fetchSports();
  }

  Future<void> _fetchSports() async {
    try {
      final response = await _supabase.from('sports').select('id, name');
      setState(() {
        _allSports = List<Map<String, dynamic>>.from(response);
        // İsteğe bağlı olarak popüler sporları üste alabilir veya alfabetik dizebiliriz
        _allSports.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching sports: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveInterests() async {
    if (selectedSportIds.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      final inserts = selectedSportIds.map((id) => {
        'user_id': userId,
        'sport_id': id,
        'skill_level': selectedLevel,
      }).toList();

      await _supabase.from('user_sports_preferences').upsert(inserts);
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      debugPrint('Error saving interests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sporların'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Neler oynuyorsun?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Partner bulmak istediğin sporları seç.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: _allSports.length,
                    itemBuilder: (context, index) {
                      final sport = _allSports[index];
                      final id = sport['id'] as String;
                      final name = sport['name'] as String;
                      final isSelected = selectedSportIds.contains(id);
                      
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedSportIds.remove(id);
                            } else {
                              selectedSportIds.add(id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? MatchFitTheme.primaryBlue.withOpacity(0.1) : Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: isSelected ? MatchFitTheme.primaryBlue : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? MatchFitTheme.primaryBlue : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
            if (selectedSportIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Genel Yetenek Seviyesi', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'beginner', label: Text('Başlangıç')),
                  ButtonSegment(value: 'intermediate', label: Text('Orta')),
                  ButtonSegment(value: 'advanced', label: Text('İleri')),
                ],
                selected: {selectedLevel},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    selectedLevel = newSelection.first;
                  });
                },
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: selectedSportIds.isEmpty || _isSaving ? null : _saveInterests,
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kurulumu Tamamla', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
