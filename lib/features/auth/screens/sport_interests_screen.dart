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
    'Tennis', 'Running', 'Basketball', 'Football', 
    'Cycling', 'Gym', 'Yoga', 'Swimming'
  ];
  
  final Set<String> selectedSports = {};
  String selectedLevel = 'Beginner';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Sports'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What do you play?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the sports you want to find partners for.',
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
              const Text('Overall Skill Level', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Beginner', label: Text('Beginner')),
                  ButtonSegment(value: 'Mid', label: Text('Mid')),
                  ButtonSegment(value: 'Advanced', label: Text('Advanced')),
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
              child: const Text('Complete Setup', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
