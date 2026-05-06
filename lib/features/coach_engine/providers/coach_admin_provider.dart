import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/coach_repository.dart';
import '../providers/coach_provider.dart';

final pendingCoachesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(coachEngineRepositoryProvider);
  return repo.getPendingCoaches();
});
