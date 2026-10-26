import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/network/api_endpoints.dart';
import '../../../../data/manila_places.dart';

/// Home feed sourced from the same backend database as Discover.
final discoverPlacesProvider = FutureProvider<List<Place>>((ref) async {
  final url = Uri.parse(
    '${ApiEndpoints.baseUrl}${ApiEndpoints.apiPrefix}/places/clusters',
  );
  final response = await http.get(url).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw Exception('Could not load places (${response.statusCode}).');
  }

  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  final clusters = payload['clusters'] as List? ?? const [];
  final places = <Place>[];

  for (final clusterValue in clusters) {
    if (clusterValue is! Map) continue;
    final cluster = Map<String, dynamic>.from(clusterValue);
    final clusterId = (cluster['cluster_id'] as num?)?.toInt() ?? 0;
    final clusterPlaces = cluster['places'] as List? ?? const [];

    for (final placeValue in clusterPlaces) {
      if (placeValue is Map) {
        places.add(
          Place.fromJson(Map<String, dynamic>.from(placeValue), clusterId),
        );
      }
    }
  }

  return places;
});
