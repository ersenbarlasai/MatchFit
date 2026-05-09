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

final activeCoachesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.read(coachEngineRepositoryProvider);
  return repository.getActiveCoaches();
});

final coachDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final repository = ref.read(coachEngineRepositoryProvider);
  return repository.getCoachDetail(userId);
});

final coachAvailabilityProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, coachId) async {
  final repository = ref.read(coachEngineRepositoryProvider);
  return repository.getCoachAvailability(coachId);
});

final myCoachSessionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.read(coachEngineRepositoryProvider);
  return repository.getMyCoachSessions();
});

final coachReviewsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, coachId) async {
  final repository = ref.read(coachEngineRepositoryProvider);
  return repository.getCoachReviews(coachId);
});
