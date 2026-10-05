class GeoBoundary {
  GeoBoundary._();

  static const double minLat = 14.35; // South (Muntinlupa / Las Piñas)
  static const double maxLat = 14.78; // North (Caloocan / Valenzuela)
  static const double minLng = 120.90; // West (Manila Bay)
  static const double maxLng = 121.15; // East (Pasig / Marikina)

  static bool isWithinMetroManila(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  /// Same keyword list as the Figma prototype.
  static const List<String> _outside = [
    'tagaytay',
    'baguio',
    'cebu',
    'clark',
    'pampanga',
    'batangas',
    'laguna',
    'bulacan',
    'cavite',
    'subic',
  ];

  static bool mentionsOutside(String query) {
    final q = query.toLowerCase();
    return _outside.any(q.contains);
  }

  /// Default center: City of Manila.
  static const double defaultLat = 14.5995;
  static const double defaultLng = 120.9842;
}
