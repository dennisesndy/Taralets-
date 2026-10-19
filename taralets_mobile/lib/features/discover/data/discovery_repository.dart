import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class Place {
  final int id;
  final String emoji;
  final String name;
  final String sub;
  final double rating;
  final String price;
  final String distanceLabel;
  final double distanceKm;
  final double lat;
  final double lng;
  final String category;
  final String openingHours;
  final String description;
  final String imageUrl;

  const Place({
    required this.id,
    required this.emoji,
    required this.name,
    required this.sub,
    required this.rating,
    required this.price,
    required this.distanceLabel,
    required this.distanceKm,
    required this.lat,
    required this.lng,
    required this.category,
    required this.openingHours,
    required this.description,
    required this.imageUrl,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] ?? 0,
      emoji: '📍', 
      name: json['name'] ?? 'Unknown Place',
      sub: json['address'] ?? 'City of Manila',
      rating: (json['rating'] ?? 0.0).toDouble(),
      price: json['entrance_fee'] ?? 'Free', // Na-update para tumugma sa db
      distanceLabel: 'Calculating...', 
      distanceKm: 0.0,
      lat: (json['latitude'] ?? 0.0).toDouble(), // Na-update para tumugma sa db
      lng: (json['longitude'] ?? 0.0).toDouble(), // Na-update para tumugma sa db
      category: json['category'] ?? 'General',
      openingHours: json['open_time'] != null && json['close_time'] != null 
          ? '${json['open_time']} - ${json['close_time']}' 
          : 'Not specified',
      description: json['description'] ?? 'Isang magandang lugar na pwedeng pasyalan sa Manila.',
      imageUrl: json['image_url'] ?? '',
    );
  }
}

// PROVIDER PARA SA TOTOONG LOCATION
final userLocationProvider = FutureProvider<Position?>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return null;
  }

  if (permission == LocationPermission.deniedForever) return null;

  return await Geolocator.getCurrentPosition();
});

// HELPER PARA MAG-COMPUTE NG DISTANCE
double? calculateDistanceKm(Position? userPos, double placeLat, double placeLng) {
  if (userPos == null) return null;
  final meters = Geolocator.distanceBetween(
    userPos.latitude,
    userPos.longitude,
    placeLat,
    placeLng,
  );
  return meters / 1000;
}