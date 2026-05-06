import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/xp_engine_repository.dart';

/// XPEngine Repository için Provider
final xpEngineRepositoryProvider = Provider<XPEngineRepository>((ref) {
  return XPEngineRepository();
});

/// Kullanıcının XP Profilini asenkron olarak çeken Provider
final userXPProfileProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) {
  final repository = ref.watch(xpEngineRepositoryProvider);
  return repository.getUserXPProfile(userId);
});

/// Kullanıcının XP Geçmişini asenkron olarak çeken Provider
final xpHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(xpEngineRepositoryProvider);
  return repository.getXPHistory();
});
