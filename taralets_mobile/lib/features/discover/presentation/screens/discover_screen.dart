import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../data/manila_places.dart'; 
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/error_note.dart';
import '../../../../shared/widgets/taralets_card.dart';
import '../../../../shared/widgets/taralets_chip.dart';
import 'place_detail_sheet.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<Place> _apiPlaces = [];
  bool _isLoading = true;
  bool _hasError = false; 

  final MapController _mapController = MapController();
  
  int? _activeClusterId; 
  int? _focusedPlaceId; // IDINAGDAG: Para matukoy kung anong eksaktong lugar ang pinindot

  static const _outside = [
    'makati', 'quezon', 'pasig', 'taguig', 'tagaytay',
    'cebu', 'baguio', 'mandaluyong', 'pasay', 'caloocan',
    'antipolo', 'bgc',
  ];

  bool _mapView = false;
  String _filter = 'All';
  String _query = '';
  bool _budget = false;
  bool _near = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _fetchPlacesList(); 
  }

  Future<void> _fetchPlacesList() async {
    final String baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
    final url = Uri.parse('$baseUrl/api/v1/places/clusters'); 
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15)); 
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List clusters = data['clusters'] ?? [];
        
        List<Place> allPlaces = [];
        for (var cluster in clusters) {
          if (cluster['is_outlier'] == true || cluster['cluster_id'] == -1) continue;

          int cId = cluster['cluster_id'] ?? 0;
          List places = cluster['places'] ?? [];
          allPlaces.addAll(places.map((p) => Place.fromJson(p, cId)).toList());
        }

        if (mounted) {
          setState(() {
            _apiPlaces = allPlaces;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        _showErrorState();
      }
    } catch (e) {
      debugPrint("Error fetching places list: $e");
      _showErrorState(); 
    }
  }

  void _showErrorState() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  List<String> get _dynamicCategories {
    if (_apiPlaces.isEmpty) return ['All'];
    
    final counts = <String, int>{};
    for (var p in _apiPlaces) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    
    final sortedCats = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      
    final topCats = sortedCats
        .where((c) => c.isNotEmpty && c.toLowerCase() != 'unknown')
        .take(8)
        .toList();
        
    return ['All', ...topCats];
  }

  bool _catMatch(String c) => _filter == 'All' || c == _filter;

  void _focusOnMap(Place place) {
    setState(() {
      _mapView = true;
      _activeClusterId = place.clusterId; 
      _focusedPlaceId = place.id; // I-set ang mismong pinindot na lugar
    });
    
    Future.delayed(const Duration(milliseconds: 150), () {
      // Mas inilapit natin (17.5 zoom level) para eksakto sa lugar
      _mapController.move(LatLng(place.lat, place.lng), 17.5);
    });
  }

  void _clearMapFocus() {
    setState(() {
      _activeClusterId = null;
      _focusedPlaceId = null; // I-reset
    });
    _mapController.move(const LatLng(14.5995, 120.9842), 13.0);
  }

  @override
  Widget build(BuildContext context) {
    final currentCats = _dynamicCategories;
    if (!currentCats.contains(_filter)) {
      _filter = 'All';
    }

    final q = _query.toLowerCase();
    final outside = _outside.any(q.contains);
    
    final results = _apiPlaces.where((p) {
      return _catMatch(p.category) &&
          (!_budget || p.price.length <= 1) &&
          (!_near || p.distanceKm <= 0.5) &&
          (q.trim().isEmpty ||
              outside ||
              '${p.name} ${p.sub} ${p.category} ${p.description}'.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _HomeStyleHeader(
              onQuery: (v) => setState(() => _query = v),
              budget: _budget,
              near: _near,
              open: _open,
              onBudget: () => setState(() => _budget = !_budget),
              onNear: () => setState(() => _near = !_near),
              onOpen: () => setState(() => _open = !_open),
              cats: currentCats, 
              filter: _filter,
              onFilter: (c) => setState(() => _filter = c),
              mapView: _mapView,
              onView: (map) {
                setState(() {
                  _mapView = map;
                  if (!map) {
                    _activeClusterId = null;
                    _focusedPlaceId = null;
                  }
                });
              },
            ),
            Expanded(
              child: _mapView
                  ? _MapView(
                      places: results, 
                      mapController: _mapController,
                      activeClusterId: _activeClusterId, 
                      focusedPlaceId: _focusedPlaceId, // Ipinasa ang focused place ID
                      onFocusPlace: _focusOnMap, 
                      onClearFocus: _clearMapFocus, 
                    )
                  : _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                      : _hasError 
                          ? Center(
                              child: Text(
                                "Failed to load database.\nPlease ensure the backend is running.",
                                textAlign: TextAlign.center,
                                style: AppText.ui(14, FontWeight.w500, color: AppColors.muted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              itemCount: results.length + (outside ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (outside && index == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: ErrorNote(
                                      title: 'Outside City of Manila',
                                      message: 'Discovery is limited to the City of Manila. Try Intramuros, Binondo, Ermita or Malate.',
                                    ),
                                  );
                                }
                                
                                final placeIndex = outside ? index - 1 : index;
                                
                                if (!outside && results.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      'No places match these filters.',
                                      textAlign: TextAlign.center,
                                      style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _PlaceCard(
                                    place: results[placeIndex],
                                    onViewOnMap: () => _focusOnMap(results[placeIndex]),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeStyleHeader extends StatelessWidget {
  const _HomeStyleHeader({
    required this.onQuery,
    required this.budget,
    required this.near,
    required this.open,
    required this.onBudget,
    required this.onNear,
    required this.onOpen,
    required this.cats,
    required this.filter,
    required this.onFilter,
    required this.mapView,
    required this.onView,
  });

  final ValueChanged<String> onQuery;
  final bool budget, near, open, mapView;
  final VoidCallback onBudget, onNear, onOpen;
  final List<String> cats;
  final String filter;
  final ValueChanged<String> onFilter;
  final ValueChanged<bool> onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explore Manila', style: AppText.ui(24, FontWeight.w800, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text('Find places your group might enjoy.', style: AppText.ui(14, FontWeight.w400, color: AppColors.muted)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _ViewToggle(label: 'List', icon: Icons.format_list_bulleted, on: !mapView, onTap: () => onView(false)),
                    _ViewToggle(label: 'Map', icon: Icons.map_outlined, on: mapView, onTap: () => onView(true)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: AppColors.muted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: onQuery,
                    style: AppText.ui(14, FontWeight.w500),
                    cursorColor: AppColors.orange,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search for cafés, parks, museums...',
                      hintStyle: AppText.ui(14, FontWeight.w400, color: AppColors.placeholder),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                TaraletsChip(label: c, selected: filter == c, onTap: () => onFilter(c), compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TaraletsChip(label: 'Budget', selected: budget, onTap: onBudget, compact: true),
              const SizedBox(width: 8),
              TaraletsChip(label: 'Distance', selected: near, onTap: onNear, compact: true),
              const SizedBox(width: 8),
              TaraletsChip(label: 'Open Now', selected: open, onTap: onOpen, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.label, required this.icon, required this.on, required this.onTap});
  
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: on ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: on ? AppColors.orange : AppColors.muted),
            const SizedBox(width: 6),
            Text(label, style: AppText.ui(12, FontWeight.w700, color: on ? AppColors.orange : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onViewOnMap});
  final Place place;
  final VoidCallback onViewOnMap;

  @override
  Widget build(BuildContext context) {
    return TaraletsCard(
      clip: true,
      onTap: () => showPlaceDetail(context, place, onViewOnMap: onViewOnMap),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              width: 90,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: place.imageUrl.isNotEmpty && place.imageUrl != 'nan'
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        place.imageUrl, 
                        fit: BoxFit.cover, 
                        height: 100, 
                        width: 90,
                        errorBuilder: (context, error, stackTrace) => Text(place.emoji, style: const TextStyle(fontSize: 36)),
                      ),
                    )
                  : Text(place.emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          style: AppText.ui(16, FontWeight.w800, color: AppColors.navy),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.category,
                    style: AppText.ui(12, FontWeight.w600, color: AppColors.orange),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('${place.rating}', style: AppText.ui(12, FontWeight.w700)),
                      const SizedBox(width: 4),
                      Text('(${place.reviews})', style: AppText.ui(11, FontWeight.w400, color: AppColors.muted)),
                      const SizedBox(width: 12),
                      Icon(Icons.payments_outlined, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place.price, 
                          style: AppText.ui(12, FontWeight.w500, color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place.sub,
                          style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    place.description,
                    style: AppText.ui(12, FontWeight.w400, color: AppColors.navy.withOpacity(0.7)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  final List<Place> places;
  final MapController mapController;
  final int? activeClusterId;
  final int? focusedPlaceId; // IDINAGDAG
  final Function(Place) onFocusPlace;
  final VoidCallback onClearFocus;
  
  const _MapView({
    required this.places, 
    required this.mapController,
    required this.activeClusterId,
    required this.focusedPlaceId,
    required this.onFocusPlace,
    required this.onClearFocus,
  });

  @override
  Widget build(BuildContext context) {
    List<Place> mapPlaces = [];

    if (activeClusterId == null) {
      final Map<int, Place> bestPerCluster = {};
      for (var p in places) {
        if (!bestPerCluster.containsKey(p.clusterId)) {
          bestPerCluster[p.clusterId] = p;
        } else {
          if (p.rating > bestPerCluster[p.clusterId]!.rating) {
            bestPerCluster[p.clusterId] = p;
          }
        }
      }
      mapPlaces = bestPerCluster.values.toList();
    } else {
      mapPlaces = places.where((p) => p.clusterId == activeClusterId).toList();
    }

    final List<Color> clusterColors = [
      Colors.red, Colors.blue, Colors.green, Colors.purple,
      Colors.orange, Colors.teal, Colors.pink, Colors.brown,
      Colors.cyan, Colors.indigo, Colors.lime, Colors.amber
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: const MapOptions(
            initialCenter: LatLng(14.5995, 120.9842), 
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.taralets.app',
            ),
            MarkerLayer(
              markers: mapPlaces.map((p) {
                final bool isFocused = p.id == focusedPlaceId;
                final Color baseColor = clusterColors[p.clusterId % clusterColors.length];
                
                // LOGIC: Kung focused, malaki at Navy Blue. Kung hindi, medyo faded.
                final Color markerColor = isFocused 
                    ? AppColors.navy 
                    : (activeClusterId != null ? baseColor.withOpacity(0.4) : baseColor);
                final double markerSize = isFocused ? 55.0 : 30.0;

                return Marker(
                  point: LatLng(p.lat, p.lng),
                  width: markerSize,
                  height: markerSize,
                  child: GestureDetector(
                    onTap: () {
                      showPlaceDetail(context, p, onViewOnMap: () => onFocusPlace(p));
                    },
                    child: Icon(
                      Icons.location_on, 
                      color: markerColor, 
                      size: markerSize
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        if (activeClusterId != null)
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.white,
              onPressed: onClearFocus,
              icon: const Icon(Icons.layers_clear, color: AppColors.navy, size: 18),
              label: Text("Show All Areas", style: AppText.ui(12, FontWeight.w700, color: AppColors.navy)),
            ),
          ),
      ],
    );
  }
}