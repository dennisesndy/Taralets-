/// Mock places. Every entry is inside the City of Manila (matches the Figma
/// `PLACES` array; Discover is limited to the City of Manila).
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.sub,
    required this.category,
    required this.price,
    required this.rating,
    required this.distanceKm,
    required this.emoji,
    required this.isOpen,
    required this.description,
  });

  final int id;
  final String name;
  final String sub;
  final String category;
  final String price; // ₱ / ₱₱ / ₱₱₱
  final double rating;
  final double distanceKm;
  final String emoji;
  final bool isOpen;
  final String description;

  String get distanceLabel => '$distanceKm km';
}

const List<Place> manilaPlaces = [
  Place(
    id: 1,
    name: 'Intramuros',
    sub: 'Historic walled city',
    category: 'Heritage',
    price: '₱₱',
    rating: 4.8,
    distanceKm: 0.2,
    emoji: '🏰',
    isOpen: true,
    description:
        'The historic walled city of Manila, featuring cobblestone streets, Spanish colonial buildings, and centuries of Filipino heritage.',
  ),
  Place(
    id: 2,
    name: 'Fort Santiago',
    sub: 'Historical landmark',
    category: 'Heritage',
    price: '₱',
    rating: 4.8,
    distanceKm: 0.3,
    emoji: '🏛',
    isOpen: true,
    description:
        'A citadel built by Spanish conquistador Miguel López de Legazpi, now a park and memorial to Philippine national hero José Rizal.',
  ),
  Place(
    id: 3,
    name: 'Binondo',
    sub: "World's oldest Chinatown",
    category: 'Food & Heritage',
    price: '₱',
    rating: 4.7,
    distanceKm: 0.8,
    emoji: '🏮',
    isOpen: true,
    description:
        'The oldest Chinatown in the world, famous for authentic Chinese-Filipino cuisine and cultural heritage.',
  ),
  Place(
    id: 4,
    name: 'Manila Baywalk',
    sub: 'Sunset & leisure',
    category: 'Leisure',
    price: '₱',
    rating: 4.6,
    distanceKm: 1.2,
    emoji: '🌅',
    isOpen: true,
    description:
        'A scenic waterfront promenade along Manila Bay, famous for its breathtaking sunset views.',
  ),
  Place(
    id: 5,
    name: 'National Museum',
    sub: 'Culture & history',
    category: 'Museum',
    price: '₱',
    rating: 4.8,
    distanceKm: 1.5,
    emoji: '🏛',
    isOpen: true,
    description:
        'The premier cultural institution of the Philippines, housing the finest collections of Philippine art, anthropology, and natural history.',
  ),
  Place(
    id: 6,
    name: 'San Agustin Church',
    sub: 'UNESCO Heritage site',
    category: 'Heritage',
    price: '₱',
    rating: 4.8,
    distanceKm: 0.4,
    emoji: '⛪',
    isOpen: true,
    description:
        'The oldest stone church in the Philippines, a UNESCO World Heritage Site built in 1607.',
  ),
  Place(
    id: 7,
    name: 'Ilustrado',
    sub: 'Filipino fine dining',
    category: 'Restaurant',
    price: '₱₱₱',
    rating: 4.7,
    distanceKm: 0.5,
    emoji: '🍽',
    isOpen: true,
    description:
        'A landmark restaurant serving contemporary Filipino cuisine in a beautiful heritage setting inside Intramuros.',
  ),
  Place(
    id: 8,
    name: 'Casa Manila',
    sub: 'Colonial museum home',
    category: 'Museum',
    price: '₱',
    rating: 4.5,
    distanceKm: 0.4,
    emoji: '🏠',
    isOpen: false,
    description:
        'A reconstruction of an upper-class colonial home from Spanish-era Manila, now a museum showcasing 19th-century Filipino lifestyle.',
  ),
];
