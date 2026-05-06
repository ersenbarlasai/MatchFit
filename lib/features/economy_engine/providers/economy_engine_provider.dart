import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/economy_engine_repository.dart';

/// EconomyEngine Repository için Provider
final economyEngineRepositoryProvider = Provider<EconomyEngineRepository>((ref) {
  return EconomyEngineRepository();
});

/// Kullanıcının MF Balance (Bakiye) Profilini asenkron olarak çeken Provider
final userMFBalanceProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) {
  final repository = ref.watch(economyEngineRepositoryProvider);
  return repository.getUserMFBalance(userId);
});

/// Kullanıcının MF Ledger Geçmişini asenkron olarak çeken Provider
final mfLedgerProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(economyEngineRepositoryProvider);
  return repository.getMFLedger();
});
