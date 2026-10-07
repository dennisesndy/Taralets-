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
      emoji: '📍', // Default emoji muna
      name: json['name'] ?? 'Unknown Place',
      sub: json['address'] ?? 'City of Manila',
      rating: 4.5, // Default rating muna dahil wala pa sa DB
      price: json['entrance_fee'] == 0.0 ? 'Free' : '₱₱', 
      distanceLabel: 'Calculating...', 
      distanceKm: 0.0,
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      category: json['category'] ?? 'General',
      openingHours: json['opening_hours'] ?? 'Not specified',
      description: 'Isang magandang lugar na pwedeng pasyalan sa Manila.', // Default description
      imageUrl: '', // Default muna dahil wala pang image sa DB
    );
  }
  
  // REAL-TIME CHECKER: Automatic na kinakalkula kung Open o Closed ngayon
  bool get isOpen {
    // Kung 24/7 o Open 24/7 ang nakalagay
    if (openingHours.toLowerCase().contains('24/7')) {
      return true;
    }

    final now = DateTime.now();
    final currentDay = now.weekday; // 1 = Monday, 7 = Sunday
    final currentMinutes = now.hour * 60 + now.minute;

    // I-parse ang opening hours string (e.g., "Mo-Fr 9:00 AM-7:30 PM; Sa,Su 9:00 AM-8:30 PM")
    final segments = openingHours.split(';');
    for (var segment in segments) {
      segment = segment.trim();
      final parts = segment.split(' ');
      if (parts.length < 2) continue;

      final daysPart = parts[0]; // Halimbawa: "Mo-Fr" o "Tu-Su" o "Mo"
      final timePart = parts.sublist(1).join(' '); // Halimbawa: "9:00 AM-7:30 PM"

      if (_isTodayInSchedule(currentDay, daysPart)) {
        return _isCurrentTimeInRange(currentMinutes, timePart);
      }
    }

    return false; // Default kapag walang tugmang oras
  }

  bool _isTodayInSchedule(int currentDay, String daysStr) {
    const dayMap = {'Mo': 1, 'Tu': 2, 'We': 3, 'Th': 4, 'Fr': 5, 'Sa': 6, 'Su': 7};

    for (var part in daysStr.split(',')) {
      part = part.trim();
      if (part.contains('-')) {
        final range = part.split('-');
        if (range.length == 2) {
          final start = dayMap[range[0]];
          final end = dayMap[range[1]];
          if (start != null && end != null) {
            if (start <= end) {
              if (currentDay >= start && currentDay <= end) return true;
            } else {
              // Kapag tumawid ng linggo (e.g., Sa-Mo)
              if (currentDay >= start || currentDay <= end) return true;
            }
          }
        }
      } else {
        if (dayMap[part] == currentDay) return true;
      }
    }
    return false;
  }

  bool _isCurrentTimeInRange(int currentMinutes, String timeStr) {
    // Suportahan ang multiple time slots (e.g., "8:00 AM-12:00 PM, 1:30 PM-5:30 PM")
    final slots = timeStr.split(',');
    for (var slot in slots) {
      slot = slot.trim();
      final times = slot.split('-');
      if (times.length != 2) continue;

      final startMin = _parseTimeString(times[0].trim());
      final endMin = _parseTimeString(times[1].trim());

      if (startMin != null && endMin != null) {
        if (currentMinutes >= startMin && currentMinutes <= endMin) {
          return true;
        }
      }
    }
    return false;
  }

  int? _parseTimeString(String t) {
    try {
      final isPM = t.toUpperCase().contains('PM');
      final isAM = t.toUpperCase().contains('AM');
      final clean = t.replaceAll(RegExp(r'[^0-9:]'), '');
      final timeParts = clean.split(':');
      
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }
}

final List<Place> manilaPlaces = [
  Place(
    id: 1,
    emoji: '🏰',
    name: 'Intramuros',
    sub: 'Intramuros Manila',
    rating: 4.0,
    price: 'Free',
    distanceLabel: '0.5 km',
    distanceKm: 0.5,
    lat: 14.59194,
    lng: 120.974508,
    category: 'Heritage',
    openingHours: 'Mo-Fr 9:00 AM-7:30 PM; Sa,Su 9:00 AM-8:30 PM',
    description: 'Explore the historic walled city of Manila, featuring Spanish-era architecture and cobblestone streets.',
    imageUrl: '',
  ),
  Place(
    id: 2,
    emoji: '🏰',
    name: 'Fort Santiago',
    sub: 'Intramuros Manila',
    rating: 4.1,
    price: '₱',
    distanceLabel: '0.8 km',
    distanceKm: 0.8,
    lat: 14.594505,
    lng: 120.970337,
    category: 'Heritage',
    openingHours: 'Mo-Su 8:00 AM-11:00 PM',
    description: 'A historic citadel built by Spanish navigator Miguel López de Legazpi for the new established city of Manila.',
    imageUrl: '',
  ),
  Place(
    id: 3,
    emoji: '🌳',
    name: 'Rizal Park',
    sub: 'Roxas Blvd Ermita Manila',
    rating: 4.2,
    price: 'Free',
    distanceLabel: '1.1 km',
    distanceKm: 1.1,
    lat: 14.582935,
    lng: 120.978678,
    category: 'Parks',
    openingHours: 'Mo-Su 5:00 AM-10:00 PM',
    description: 'A historical urban park in the Philippines, adjacent to the old walled city of Intramuros.',
    imageUrl: '',
  ),
  Place(
    id: 4,
    emoji: '🏛️',
    name: 'National Museum of Fine Arts',
    sub: 'Padre Burgos Ave Ermita Manila',
    rating: 4.3,
    price: 'Free',
    distanceLabel: '1.4 km',
    distanceKm: 1.4,
    lat: 14.587239,
    lng: 120.980993,
    category: 'Museums',
    openingHours: 'Mo-Su 9:00 AM-6:00 PM',
    description: 'Home to classical Philippine art, including Juan Luna\'s famous Spoliarium.',
    imageUrl: '',
  ),
  Place(
    id: 5,
    emoji: '🏛️',
    name: 'National Museum of Anthropology',
    sub: 'P. Burgos Drive, Rizal Park, Ermita, Manila',
    rating: 4.4,
    price: 'Free',
    distanceLabel: '1.7 km',
    distanceKm: 1.7,
    lat: 14.585574,
    lng: 120.980944,
    category: 'Museums',
    openingHours: 'Mo-Su 9:00 AM-6:00 PM',
    description: 'Features exhibits on the ethnological and archaeological history of the Philippines.',
    imageUrl: '',
  ),
  Place(
    id: 6,
    emoji: '⛪',
    name: 'Manila Cathedral',
    sub: 'Cabildo St Intramuros Manila',
    rating: 4.5,
    price: 'Free',
    distanceLabel: '2.0 km',
    distanceKm: 2.0,
    lat: 14.592013,
    lng: 120.973422,
    category: 'Heritage',
    openingHours: 'Tu-Sa 8:00 AM-4:30 PM; Su 8:00 AM-11:30 AM',
    description: 'The Minor Basilica and Metropolitan Cathedral of the Immaculate Conception is a historic church in Intramuros.',
    imageUrl: '',
  ),
  Place(
    id: 7,
    emoji: '⛪',
    name: 'San Agustin Church',
    sub: 'General Luna St Intramuros Manila',
    rating: 4.6,
    price: 'Free',
    distanceLabel: '2.3 km',
    distanceKm: 2.3,
    lat: 14.589366,
    lng: 120.975405,
    category: 'Heritage',
    openingHours: 'Tu-Su 8:00 AM-5:00 PM',
    description: 'A UNESCO World Heritage site and the oldest stone church in the country.',
    imageUrl: '',
  ),
  Place(
    id: 8,
    emoji: '🏛️',
    name: 'Casa Manila',
    sub: 'Plaza San Luis Intramuros Manila',
    rating: 4.7,
    price: '₱',
    distanceLabel: '2.6 km',
    distanceKm: 2.6,
    lat: 14.589914,
    lng: 120.975226,
    category: 'Museums',
    openingHours: 'Tu-Su 9:00 AM-6:00 PM',
    description: 'A museum depicting colonial lifestyle during Spanish colonization of the Philippines.',
    imageUrl: '',
  ),
  Place(
    id: 9,
    emoji: '🎡',
    name: 'Manila Zoo',
    sub: 'M. Adriatico St Malate Manila',
    rating: 4.8,
    price: '₱₱',
    distanceLabel: '2.9 km',
    distanceKm: 2.9,
    lat: 14.56503,
    lng: 120.988348,
    category: 'All',
    openingHours: 'Mo 11:00 AM-8:00 PM; Tu-Su 9:00 AM-8:00 PM',
    description: 'A 5.5-hectare zoo located in Malate, Manila, home to various animal species.',
    imageUrl: '',
  ),
  Place(
    id: 10,
    emoji: '⛪',
    name: 'Binondo Church',
    sub: 'Plaza Lorenzo Ruiz, Binondo, Manila',
    rating: 4.9,
    price: 'Free',
    distanceLabel: '3.2 km',
    distanceKm: 3.2,
    lat: 14.600442,
    lng: 120.974497,
    category: 'Heritage',
    openingHours: 'Tu-Su 8:00 AM-12:00 PM, 1:30 PM-5:30 PM',
    description: 'Also known as the Minor Basilica of St. Lorenzo Ruiz, founded by Dominican priests in 1596.',
    imageUrl: '',
  ),
  Place(
    id: 11,
    emoji: '⛪',
    name: 'Quiapo Church',
    sub: 'Plaza Miranda Quiapo Manila',
    rating: 4.0,
    price: 'Free',
    distanceLabel: '3.5 km',
    distanceKm: 3.5,
    lat: 14.599135,
    lng: 120.983724,
    category: 'Heritage',
    openingHours: 'Mo-Th,Sa 8:00 AM-11:45 AM, 1:00 PM-4:45 PM; Fr,Su 7:00 AM-6:45 PM',
    description: 'Home to the Black Nazarene, a much-venerated statue of Jesus Christ.',
    imageUrl: '',
  ),
  Place(
    id: 12,
    emoji: '🌳',
    name: 'Manila Baywalk',
    sub: 'Roxas Blvd Manila',
    rating: 4.1,
    price: 'Free',
    distanceLabel: '3.8 km',
    distanceKm: 3.8,
    lat: 14.567764,
    lng: 120.983253,
    category: 'Parks',
    openingHours: 'Open 24/7',
    description: 'A popular promenade overlooking Manila Bay, famous for its golden sunsets.',
    imageUrl: '',
  ),
  Place(
    id: 13,
    emoji: '🎡',
    name: 'Manila Ocean Park',
    sub: 'Behind Quirino Grandstand Manila',
    rating: 4.2,
    price: 'Free',
    distanceLabel: '4.1 km',
    distanceKm: 4.1,
    lat: 14.579647,
    lng: 120.972469,
    category: 'All',
    openingHours: 'Mo-Fr 10:00 AM-6:00 PM; Sa,Su 9:00 AM-6:00 PM',
    description: 'An oceanarium in Manila with various marine life exhibits and attractions.',
    imageUrl: '',
  ),
  Place(
    id: 14,
    emoji: '🌳',
    name: 'Chinese Garden (Rizal Park)',
    sub: 'Rizal Park Ermita Manila',
    rating: 4.3,
    price: 'Free',
    distanceLabel: '4.4 km',
    distanceKm: 4.4,
    lat: 14.583242,
    lng: 120.977733,
    category: 'Parks',
    openingHours: '24/7',
    description: 'A peaceful garden within Rizal Park featuring Chinese-style architecture and koi ponds.',
    imageUrl: '',
  ),
  Place(
    id: 15,
    emoji: '🍲',
    name: 'Eng Bee Tin Chinese Deli (Ongpin)',
    sub: 'Ongpin St, Binondo, Manila',
    rating: 4.4,
    price: 'Free',
    distanceLabel: '0.7 km',
    distanceKm: 0.7,
    lat: 14.600379,
    lng: 120.975147,
    category: 'Food & Cafés',
    openingHours: 'Mo-Su 7:00 AM-10:00 PM',
    description: 'A famous Chinese deli known for its hopia, tikoy, and other traditional delicacies.',
    imageUrl: '',
  ),
  Place(
    id: 16,
    emoji: '🛍️',
    name: 'Lucky Chinatown Mall',
    sub: 'Reina Regente St, Binondo, Manila',
    rating: 4.5,
    price: 'Free',
    distanceLabel: '1.0 km',
    distanceKm: 1.0,
    lat: 14.603285,
    lng: 120.973417,
    category: 'Shopping',
    openingHours: 'Mo-Th 11:00 AM-9:00 PM; Fr-Su 10:00 AM-9:00 PM',
    description: 'A modern shopping mall located in the heart of Binondo, the world\'s oldest Chinatown.',
    imageUrl: '',
  ),
  Place(
    id: 17,
    emoji: '📍',
    name: 'Manila City Hall',
    sub: 'Padre Burgos Ave, Ermita, Manila',
    rating: 4.6,
    price: 'Free',
    distanceLabel: '1.3 km',
    distanceKm: 1.3,
    lat: 14.589763,
    lng: 120.981558,
    category: 'All',
    openingHours: 'Mo-Fr 7:00 AM-4:00 PM',
    description: 'The official seat of government of the City of Manila, known for its iconic clock tower.',
    imageUrl: '',
  ),
];

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