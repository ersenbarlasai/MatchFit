import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';

class SportInterestsScreen extends StatefulWidget {
  const SportInterestsScreen({super.key});

  @override
  State<SportInterestsScreen> createState() => _SportInterestsScreenState();
}

class _SportInterestsScreenState extends State<SportInterestsScreen> {
  final List<String> sports = [
    'Tenis', 'Koşu', 'Basketbol', 'Futbol', 
    'Bisiklet', 'Gym', 'Yoga', 'Yüzme'
  ];
  
  final Set<String> selectedSports = {};
  String selectedLevel = 'Başlangıç';

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
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.5,
                ),
                itemCount: sports.length,
                itemBuilder: (context, index) {
                  final sport = sports[index];
                  final isSelected = selectedSports.contains(sport);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedSports.remove(sport);
                        } else {
                          selectedSports.add(sport);
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
                        sport,
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
            if (selectedSports.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Genel Yetenek Seviyesi', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Başlangıç', label: Text('Başlangıç')),
                  ButtonSegment(value: 'Orta', label: Text('Orta')),
                  ButtonSegment(value: 'İleri', label: Text('İleri')),
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
              onPressed: selectedSports.isEmpty ? null : () {
                context.go('/home');
              },
              child: const Text('Kurulumu Tamamla', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
