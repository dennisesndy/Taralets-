
String normalizeActivityCategory(String value) {
  final tag = value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  const aliases = <String, String>{
    // Church and religious places
    'church': 'Church / Religious Site',
    'churches': 'Church / Religious Site',
    'church religious site': 'Church / Religious Site',
    'religious site': 'Church / Religious Site',
    'religious sites': 'Church / Religious Site',
    'religious place': 'Church / Religious Site',
    'religious places': 'Church / Religious Site',
    'place of worship': 'Church / Religious Site',
    'places of worship': 'Church / Religious Site',

    // Art galleries
    'art gallery': 'Art Galleries',
    'art galleries': 'Art Galleries',
    'gallery': 'Art Galleries',
    'galleries': 'Art Galleries',

    // Museums
    'museum': 'Museums',
    'museums': 'Museums',
    'art museum': 'Museums',
    'art museums': 'Museums',

    // Cafes
    'cafe': 'Cafes',
    'cafes': 'Cafes',
    'coffee shop': 'Cafes',
    'coffee shops': 'Cafes',
    'coffeehouse': 'Cafes',
    'coffeehouses': 'Cafes',

    // Restaurants
    'restaurant': 'Restaurants',
    'restaurants': 'Restaurants',
    'restaurant eatery': 'Restaurants',
    'eatery': 'Restaurants',
    'eateries': 'Restaurants',
    'food establishment': 'Restaurants',
    'food establishments': 'Restaurants',

    // Parks and plazas
    'park': 'Parks / Plazas',
    'parks': 'Parks / Plazas',
    'plaza': 'Parks / Plazas',
    'plazas': 'Parks / Plazas',
    'park plaza': 'Parks / Plazas',
    'parks and plazas': 'Parks / Plazas',
    'public park': 'Parks / Plazas',
    'public parks': 'Parks / Plazas',

    // Historical and tourist sites
    'historical': 'Historical / Tourist Site',
    'historical site': 'Historical / Tourist Site',
    'historical sites': 'Historical / Tourist Site',
    'historical landmark': 'Historical / Tourist Site',
    'historical landmarks': 'Historical / Tourist Site',
    'heritage site': 'Historical / Tourist Site',
    'heritage sites': 'Historical / Tourist Site',
    'tourist site': 'Historical / Tourist Site',
    'tourist sites': 'Historical / Tourist Site',
    'tourist attraction': 'Historical / Tourist Site',
    'tourist attractions': 'Historical / Tourist Site',
    'landmark': 'Historical / Tourist Site',
    'landmarks': 'Historical / Tourist Site',
  };

  return aliases[tag] ?? value.trim();
}

List<String> normalizeActivityCategories(
  Iterable<String> categories,
) {
  final normalized = categories
      .map(normalizeActivityCategory)
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  normalized.sort(
    (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
  );

  return normalized;
}
