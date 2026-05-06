import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/ranking_engine_repository.dart';

final rankingEngineRepositoryProvider = Provider<RankingEngineRepository>((ref) {
  return RankingEngineRepository();
});

final globalLeaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(rankingEngineRepositoryProvider).getGlobalLeaderboard();
});

final cityLeaderboardProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, city) {
  return ref.watch(rankingEngineRepositoryProvider).getCityLeaderboard(city);
});

final friendsLeaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(rankingEngineRepositoryProvider).getFriendsLeaderboard();
});

final weeklyLeaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(rankingEngineRepositoryProvider).getWeeklyLeaderboard();
});

final availableCitiesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(rankingEngineRepositoryProvider).getAvailableCities();
});

final availableSportsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(rankingEngineRepositoryProvider).getAvailableSports();
});

// A dynamic provider that takes both filters
final filteredLeaderboardProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String? city, String? sport})>((ref, args) {
  return ref.watch(rankingEngineRepositoryProvider).getFilteredLeaderboard(
    city: args.city,
    sportName: args.sport,
  );
});
