import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/core/services/location_service.dart';
import 'package:matchfit/features/home/repositories/matchmaker_repository.dart';
import 'package:matchfit/features/matchmaker/agents/matchmaker_agent.dart';

final matchmakerAgentProvider = Provider<MatchmakerAgent>((ref) {
  final supabase = Supabase.instance.client;
  final repository = ref.watch(matchmakerRepositoryProvider);
  return MatchmakerAgent(supabase, repository);
});

class MatchupState {
  final Map<String, dynamic>? matchedUser;
  final bool isLoading;
  final String? error;

  MatchupState({
    this.matchedUser,
    this.isLoading = false,
    this.error,
  });

  MatchupState copyWith({
    Map<String, dynamic>? matchedUser,
    bool? isLoading,
    String? error,
  }) {
    return MatchupState(
      matchedUser: matchedUser ?? this.matchedUser,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class MatchupNotifier extends Notifier<MatchupState> {
  @override
  MatchupState build() {
    return MatchupState();
  }

  void reset() {
    state = MatchupState();
  }

  Future<void> findMatch() async {
    final agent = ref.read(matchmakerAgentProvider);
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Get GPS position from location service
      final position = await ref.read(userLocationProvider.future);
      
      final match = await agent.findMatch(
        lat: position?.latitude,
        lng: position?.longitude,
      );
      
      if (match != null) {
        state = state.copyWith(matchedUser: match, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false, 
          error: 'Bulunduğun ilde kriterlerine uygun eşleşme bulunamadı.'
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Eşleşme aranırken bir hata oluştu.');
    }
  }

  void setPrinciple(MatchupPrinciple principle) {
    final agent = ref.read(matchmakerAgentProvider);
    agent.setPrinciple(principle);
  }
}

final matchupProvider = NotifierProvider<MatchupNotifier, MatchupState>(
  MatchupNotifier.new,
);
