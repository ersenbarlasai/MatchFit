import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/coach_provider.dart';

final pendingCoachesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(coachEngineRepositoryProvider);
  return repo.getPendingCoaches();
});

final allCoachesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(coachEngineRepositoryProvider);
  return repo.getAllCoaches();
});
