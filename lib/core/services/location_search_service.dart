import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSuggestion {
  final String description;
  final double lat;
  final double lng;

  LocationSuggestion({required this.description, required this.lat, required this.lng});
}

class LocationSearchService {
  Future<List<LocationSuggestion>> search(String query) async {
    if (query.length < 3) return [];
    
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1'
      );
      
      final response = await http.get(url, headers: {
        'User-Agent': 'MatchFit-App' // Nominatim requires a user agent
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) => LocationSuggestion(
          description: item['display_name'],
          lat: double.parse(item['lat']),
          lng: double.parse(item['lon']),
        )).toList();
      }
    } catch (e) {
      print('Location search error: $e');
    }
    return [];
  }
}
