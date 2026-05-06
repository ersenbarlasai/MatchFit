import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/coach_repository.dart';

final coachEngineRepositoryProvider = Provider((ref) => CoachEngineRepository());

final currentCoachProfileProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final repository = ref.read(coachEngineRepositoryProvider);
  return repository.getCoachProfile(userId);
});

final coachLandingContentProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repository = ref.read(coachEngineRepositoryProvider);
  return repository.getCoachLandingContent();
});
