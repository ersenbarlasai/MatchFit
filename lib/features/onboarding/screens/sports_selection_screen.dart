import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/constants/sports_data.dart';
import 'package:matchfit/core/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SportsSelectionScreen extends ConsumerStatefulWidget {
  const SportsSelectionScreen({super.key});

  @override
  ConsumerState<SportsSelectionScreen> createState() => _SportsSelectionScreenState();
}

class _SportsSelectionScreenState extends ConsumerState<SportsSelectionScreen> {
  int _currentStep = 1;
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedSubcategories = {};
  final Map<String, String> _skillLevels = {}; // Subcategory -> Level

  List<String> _getLevels(AppLocalizations t) => [t.beginner, t.intermediate, t.advanced];

  void _nextStep() {
    final t = AppLocalizations.of(context);
    if (_currentStep == 1 && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.selectAtLeastOneCategory)));
      return;
    }
    if (_currentStep == 2 && _selectedSubcategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.selectAtLeastOneSubBranch)));
      return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _saveAndFinish();
    }
  }

  Future<void> _saveAndFinish() async {
    final t = AppLocalizations.of(context);
    // Check if all selected subcategories have a skill level
    for (var sub in _selectedSubcategories) {
      if (!_skillLevels.containsKey(sub)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.selectSkillLevelFor}$sub')));
        return;
      }
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Save to database
    try {
      final List<Map<String, dynamic>> prefs = [];
      
      // Get sport IDs for subcategories
      final sportsResponse = await Supabase.instance.client
          .from('sports')
          .select('id, name');
      
      final Map<String, String> sportNameToId = {
        for (var s in sportsResponse) s['name'] as String: s['id'] as String
      };

      for (var sub in _selectedSubcategories) {
        final sportId = sportNameToId[sub];
        if (sportId != null) {
          prefs.add({
            'user_id': userId,
            'sport_id': sportId,
            'skill_level': _skillLevels[sub],
          });
        }
      }

      await Supabase.instance.client
          .from('user_sports_preferences')
          .upsert(prefs);

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.errorSavingPreferences}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${t.stepOf} $_currentStep / 3', style: const TextStyle(fontSize: 14, color: Colors.white54)),
        centerTitle: true,
        leading: _currentStep > 1 
          ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(() => _currentStep--))
          : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildCurrentStep(t),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(_currentStep == 3 ? t.finish : t.next.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(AppLocalizations t) {
    switch (_currentStep) {
      case 1: return _buildCategorySelection(t);
      case 2: return _buildSubcategorySelection(t);
      case 3: return _buildSkillLevelSelection(t);
      default: return const SizedBox();
    }
  }

  Widget _buildCategorySelection(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(t.chooseSportsCategories, 
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: sportsData.length,
            itemBuilder: (context, index) {
              final cat = sportsData[index];
              final isSelected = _selectedCategories.contains(cat.name);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCategories.remove(cat.name);
                      for (var sub in cat.subcategories) {
                        _selectedSubcategories.remove(sub);
                      }
                    } else {
                      _selectedCategories.add(cat.name);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? MatchFitTheme.accentGreen.withOpacity(0.1) : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? MatchFitTheme.accentGreen : Colors.white.withOpacity(0.05), width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getIconData(cat.icon), color: isSelected ? MatchFitTheme.accentGreen : Colors.white54, size: 32),
                      const SizedBox(height: 12),
                      Text(cat.name, 
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 13, 
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategorySelection(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(t.chooseSubBranches, 
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: sportsData.where((cat) => _selectedCategories.contains(cat.name)).map((cat) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(cat.name, style: const TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cat.subcategories.map((sub) {
                      final isSelected = _selectedSubcategories.contains(sub);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) _selectedSubcategories.remove(sub);
                            else _selectedSubcategories.add(sub);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? MatchFitTheme.accentGreen : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(sub, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillLevelSelection(AppLocalizations t) {
    final selectedList = _selectedSubcategories.toList();
    final levels = _getLevels(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(t.whatIsYourSkillLevel, 
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: selectedList.length,
            itemBuilder: (context, index) {
              final sub = selectedList[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: levels.map((level) {
                        final isSelected = _skillLevels[sub] == level;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _skillLevels[sub] = level),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? MatchFitTheme.accentGreen : const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? MatchFitTheme.accentGreen : Colors.transparent),
                              ),
                              child: Text(level, 
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isSelected ? Colors.black : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'sports_tennis': return Icons.sports_tennis;
      case 'groups': return Icons.groups;
      case 'directions_run': return Icons.directions_run;
      case 'directions_bike': return Icons.directions_bike;
      case 'fitness_center': return Icons.fitness_center;
      case 'terrain': return Icons.terrain;
      case 'waves': return Icons.waves;
      case 'sports_mma': return Icons.sports_mma;
      case 'self_improvement': return Icons.self_improvement;
      case 'ac_unit': return Icons.ac_unit;
      case 'reorder': return Icons.reorder;
      case 'motorcycle': return Icons.motorcycle;
      default: return Icons.sports;
    }
  }
}
