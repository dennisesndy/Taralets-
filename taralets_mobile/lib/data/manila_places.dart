import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class Place {
  final int id;
  final int clusterId;
  final String emoji;
  final String name;
  final String sub;
  final double rating;
  final int reviews;
  final String price;
  final double minCost;
  final double maxCost;
  final String distanceLabel;
  final double distanceKm;
  final double lat;
  final double lng;
  final String category;
  // BAGO: Sub-categories at Accessibility
  final String subCategory1;
  final String subCategory2;
  final String subCategory3;
  final bool petFriendly;
  final bool wheelchairAccessible;
  final bool goodForChildren;
  
  final String openingHours;
  final String description;
  final String imageUrl;
  final List<String> activityTags;

  const Place({
    required this.id,
    this.clusterId = 0,
    required this.emoji,
    required this.name,
    required this.sub,
    required this.rating,
    this.reviews = 0,
    required this.price,
    this.minCost = 0,
    this.maxCost = 0,
    required this.distanceLabel,
    required this.distanceKm,
    required this.lat,
    required this.lng,
    required this.category,
    required this.subCategory1,
    required this.subCategory2,
    required this.subCategory3,
    required this.petFriendly,
    required this.wheelchairAccessible,
    required this.goodForChildren,
    required this.openingHours,
    required this.description,
    required this.imageUrl,
    this.activityTags = const [],
  });

  factory Place.fromJson(Map<String, dynamic> json, [int clusterId = 0]) {
    List<String> parsedTags = [];
    if (json['activity_tags'] != null) {
      parsedTags = List<String>.from(json['activity_tags']);
    }
    
    String exactAddress = json['address'] != null && json['address'].toString().isNotEmpty 
        ? json['address'] 
        : (json['district'] ?? 'City of Manila');

    return Place(
      id: json['id'] ?? 0,
      clusterId: clusterId,
      emoji: '📍', 
      name: json['name'] ?? 'Unknown Place',
      sub: exactAddress,
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviews: json['reviews'] ?? 0,
      price: json['entrance_fee'] != null && json['entrance_fee'].toString().isNotEmpty ? json['entrance_fee'] : 'Free', 
      minCost: double.tryParse(json['min_cost']?.toString() ?? '') ?? 0,
      maxCost: double.tryParse(json['max_cost']?.toString() ?? '') ?? 0,
      distanceLabel: 'Calculating...', 
      distanceKm: 0.0,
      lat: (json['lat'] ?? 0.0).toDouble(), 
      lng: (json['lng'] ?? 0.0).toDouble(), 
      category: json['category'] ?? 'General',
      // Sinasalo ang sub-categories at boolean filters
      subCategory1: json['sub_category_1'] ?? '',
      subCategory2: json['sub_category_2'] ?? '',
      subCategory3: json['sub_category_3'] ?? '',
      petFriendly: json['pet_friendly'] == true,
      wheelchairAccessible: json['wheelchair_accessible'] == true,
      goodForChildren: json['good_for_children'] == true,
      openingHours: json['open_time'] != null && json['close_time'] != null 
          ? '${json['open_time']} - ${json['close_time']}' 
          : 'Not specified',
      description: json['description'] != null && json['description'].toString().isNotEmpty 
          ? json['description'] 
          : 'No description available for this location.',
      imageUrl: json['image_url'] ?? '',
      activityTags: parsedTags,
    );
  }

  bool get isOpen {
    if (openingHours == 'Not specified' || !openingHours.contains('-')) return true;
    try {
      final parts = openingHours.split('-');
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      int parseTime(String t) {
        final p = t.split(':');
        return int.parse(p[0]) * 60 + int.parse(p[1]);
      }

      final startMin = parseTime(parts[0].trim());
      final endMin = parseTime(parts[1].trim());

      return currentMinutes >= startMin && currentMinutes <= endMin;
    } catch (_) {
      return true;
    }
  }
}

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
