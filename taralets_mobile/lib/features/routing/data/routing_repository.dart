import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoutingRepository {
  // Approximate Bounding Box ng City of Manila:
  // West: 120.9500, East: 121.0300, South: 14.5500, North: 14.6300
  static const double _minLat = 14.5500;
  static const double _maxLat = 14.6300;
  static const double _minLng = 120.9500;
  static const double _maxLng = 121.0300;

  bool _isWithinManila(double lat, double lng) {
    return lat >= _minLat && lat <= _maxLat && lng >= _minLng && lng <= _maxLng;
  }

  // Autocomplete na naka-restrict strictly sa City of Manila
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // viewbox format: <left>,<top>,<right>,<bottom> (minLng, maxLat, maxLng, minLat)
    // bounded=1 forces Nominatim to only return results inside this box
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?'
      'q=${Uri.encodeComponent('$cleanQuery, Manila')}'
      '&format=json'
      '&addressdetails=1'
      '&limit=6'
      '&countrycodes=ph'
      '&viewbox=$_minLng,$_maxLat,$_maxLng,$_minLat'
      '&bounded=1',
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'TaraletsApp/1.0',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        return data
            .map((item) {
              final lat = double.tryParse(item['lat'] ?? '') ?? 0.0;
              final lng = double.tryParse(item['lon'] ?? '') ?? 0.0;
              final displayName = item['display_name'] as String? ?? '';

              return {
                'name': displayName.split(',').first.trim(),
                'full_address': displayName,
                'lat': lat,
                'lng': lng,
              };
            })
            // Double-check: salain para Manila coordinates lang talaga ang makalusot
            .where((item) => _isWithinManila(item['lat'] as double, item['lng'] as double))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  // Device Geolocation para sa "Use my current location"
  Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  }
}

final routingRepositoryProvider = Provider((ref) => RoutingRepository());