/// A place that a group member can add to the shared itinerary draft.
///
/// This is deliberately separate from [ItineraryStop]: a candidate still has
/// to survive the group vote before it becomes a stop in the final plan.
class ItineraryCandidate {
  const ItineraryCandidate({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.budget,
    required this.groupScore,
    required this.icon,
    this.backendId = '',
    this.address = '',
    this.description = '',
    this.imageUrl = '',
    this.activityTags = const [],
    this.dietaryTags = const [],
    this.accessibilityTags = const [],
  });

  /// Display id used by the local draft. It may include an index suffix.
  final String id;

  /// Stable database id (master id or numeric place id) used by the API.
  final String backendId;

  final String name;
  final String category;
  final String area;
  final String address;
  final String description;
  final String imageUrl;
  final String icon;

  /// Estimated spend in pesos. `0` means free.
  final int budget;

  /// Normalized group match, `0.0` to `1.0`.
  final double groupScore;

  final List<String> activityTags;
  final List<String> dietaryTags;
  final List<String> accessibilityTags;

  int get placeId =>
      int.tryParse(backendId) ?? (id.hashCode & 0x7fffffff);

  String get locationLabel =>
      area.isEmpty ? category : '$category • $area';
}

/// Small emoji marker used in the timeline. Keeps the existing itinerary
/// visual language without introducing an asset per category.
String itineraryIconForCategory(String category) {
  final value = category.toLowerCase();
  if (value.contains('food') ||
      value.contains('restaurant') ||
      value.contains('cafe') ||
      value.contains('eatery')) {
    return '🍽';
  }
  if (value.contains('museum') || value.contains('gallery')) {
    return '🖼';
  }
  if (value.contains('park') || value.contains('plaza')) {
    return '🌳';
  }
  if (value.contains('church') || value.contains('religious')) {
    return '⛪';
  }
  if (value.contains('historical') ||
      value.contains('heritage') ||
      value.contains('landmark')) {
    return '🏛';
  }
  if (value.contains('shopping') || value.contains('market')) {
    return '🛍';
  }
  return '📍';
}
