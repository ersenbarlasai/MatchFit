import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/features/home/repositories/matchmaker_repository.dart';

enum MatchupPrinciple {
  random,
  highestXP,
  genderBased,
}

class MatchmakerAgent {
  final SupabaseClient _supabase;
  final MatchmakerRepository _repository;
  
  MatchupPrinciple _currentPrinciple = MatchupPrinciple.random;

  MatchmakerAgent(this._supabase, this._repository);

  /// Sets the matching principle for the agent.
  void setPrinciple(MatchupPrinciple principle) {
    _currentPrinciple = principle;
    debugPrint('MatchmakerAgent: Principle changed to $principle');
  }

  /// Resolves GPS coordinates to a city name (il).
  /// Uses native geocoding first, falls back to Nominatim API.
  Future<String?> _resolveCity(double lat, double lng) async {
    // 1. Try native geocoding plugin
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final city = placemarks.first.administrativeArea;
        if (city != null && city.isNotEmpty) {
          debugPrint('MatchmakerAgent: Resolved city via native geocoder: $city');
          return city;
        }
      }
    } catch (e) {
      debugPrint('MatchmakerAgent: Native geocoder failed: $e');
    }

    // 2. Fallback to Nominatim (OpenStreetMap)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=10&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'MatchFitApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        if (address != null) {
          final city = address['province'] ?? address['city'] ?? address['state'];
          if (city != null && city.toString().isNotEmpty) {
            debugPrint('MatchmakerAgent: Resolved city via Nominatim: $city');
            return city.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('MatchmakerAgent: Nominatim API failed: $e');
    }

    return null;
  }

  /// Finds a match based on GPS location and shared sport interests.
  /// [lat] and [lng] are the user's current GPS coordinates.
  Future<Map<String, dynamic>?> findMatch({double? lat, double? lng}) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return null;

    try {
      // 1. Resolve city from GPS coordinates
      String? gpsCity;
      if (lat != null && lng != null) {
        gpsCity = await _resolveCity(lat, lng);
      }

      // 2. Fallback: if GPS city resolution failed, use profile city
      if (gpsCity == null || gpsCity.isEmpty) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('city')
            .eq('id', currentUser.id)
            .maybeSingle();
        gpsCity = profileResponse?['city'] as String?;
      }

      debugPrint('MatchmakerAgent: Matching in city: $gpsCity');

      // 3. Get user sport interests
      final interestsResponse = await _supabase
          .from('user_sports_preferences')
          .select('sport_id')
          .eq('user_id', currentUser.id);
      
      final sportIds = (interestsResponse as List)
          .map((e) => e['sport_id'])
          .toList();

      if (sportIds.isEmpty) {
        debugPrint('MatchmakerAgent: User has no sport interests.');
        return null;
      }

      debugPrint('MatchmakerAgent: User sport IDs: $sportIds');

      // 4. Find other users who share at least one sport interest (two-step query)
      final matchingSportsResponse = await _supabase
          .from('user_sports_preferences')
          .select('user_id')
          .inFilter('sport_id', sportIds)
          .neq('user_id', currentUser.id)
          .limit(100);

      final matchingUserIds = (matchingSportsResponse as List)
          .map((e) => e['user_id'] as String)
          .toSet()
          .toList();

      debugPrint('MatchmakerAgent: Found ${matchingUserIds.length} users with shared sports');

      if (matchingUserIds.isEmpty) {
        debugPrint('MatchmakerAgent: No users with shared sports found.');
        return null;
      }

      // 5. Get profiles of those users, filtered by city
      var profileQuery = _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', matchingUserIds);
      
      if (gpsCity != null && gpsCity.isNotEmpty) {
        profileQuery = profileQuery.eq('city', gpsCity);
      }

      final candidatesResponse = await profileQuery.limit(50);
      List candidates = candidatesResponse as List;

      debugPrint('MatchmakerAgent: Found ${candidates.length} candidates in "$gpsCity"');

      if (candidates.isEmpty) {
        debugPrint('MatchmakerAgent: No candidates found in "$gpsCity" with shared interests.');
        return null;
      }


      // 5. Apply current principle
      Map<String, dynamic>? selectedMatch;

      switch (_currentPrinciple) {
        case MatchupPrinciple.highestXP:
          // Placeholder for XP-based sorting (future)
          candidates.shuffle();
          selectedMatch = Map<String, dynamic>.from(candidates.first);
          break;
          
        case MatchupPrinciple.genderBased:
          // Placeholder for gender-based filtering (future)
          candidates.shuffle();
          selectedMatch = Map<String, dynamic>.from(candidates.first);
          break;

        case MatchupPrinciple.random:
        default:
          candidates.shuffle();
          selectedMatch = Map<String, dynamic>.from(candidates.first);
          break;
      }

      debugPrint('MatchmakerAgent: Matched with ${selectedMatch?['full_name']}');
      return selectedMatch;
    } catch (e) {
      debugPrint('MatchmakerAgent: Error finding match: $e');
      return null;
    }
  }
}
