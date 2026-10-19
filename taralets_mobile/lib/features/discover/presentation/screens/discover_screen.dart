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
import '../../../../shared/widgets/taralets_chip.dart';
import 'place_detail_sheet.dart';

IconData getCategoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('church') || c.contains('religious') || c.contains('heritage')) return Icons.church;
  if (c.contains('restaurant') || c.contains('eatery') || c.contains('food')) return Icons.restaurant_menu;
  if (c.contains('cafe') || c.contains('bakery') || c.contains('dessert')) return Icons.local_cafe;
  if (c.contains('shopping') || c.contains('retail') || c.contains('mall')) return Icons.shopping_bag_outlined;
  if (c.contains('health') || c.contains('wellness') || c.contains('spa')) return Icons.spa_outlined;
  if (c.contains('accommodation') || c.contains('hotel')) return Icons.hotel_outlined;
  if (c.contains('park') || c.contains('nature')) return Icons.park_outlined;
  if (c.contains('museum') || c.contains('art')) return Icons.museum_outlined;
  if (c.contains('entertainment') || c.contains('leisure')) return Icons.local_play_outlined;
  return Icons.place_outlined; 
}

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
  int? _focusedPlaceId; 

  static const _outside = [
    'makati', 'quezon', 'pasig', 'taguig', 'tagaytay',
    'cebu', 'baguio', 'mandaluyong', 'pasay', 'caloocan',
    'antipolo', 'bgc',
  ];

  bool _mapView = false;
  String _filter = 'All';
  String _query = '';
  
  // Mga idinagdag na filters
  bool _budget = false;
  bool _near = false;
  bool _open = false;
  bool _petFriendly = false;
  bool _kidFriendly = false;
  bool _wheelchair = false;

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
        .take(6)
        .toList();
        
    return ['All', ...topCats];
  }

  bool _catMatch(String c) => _filter == 'All' || c == _filter;

  void _focusOnMap(Place place) {
    setState(() {
      _mapView = true;
      _activeClusterId = place.clusterId; 
      _focusedPlaceId = place.id; 
    });
    
    Future.delayed(const Duration(milliseconds: 150), () {
      _mapController.move(LatLng(place.lat, place.lng), 16.5);
    });
  }

  void _clearMapFocus() {
    setState(() {
      _activeClusterId = null;
      _focusedPlaceId = null;
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
      // Logic para sa mga bagong Filter Toggles
      if (_petFriendly && !p.petFriendly) return false;
      if (_kidFriendly && !p.goodForChildren) return false;
      if (_wheelchair && !p.wheelchairAccessible) return false;

      // Kasama na ang sub_categories sa searchable string!
      final searchableString = '${p.name} ${p.sub} ${p.category} ${p.description} ${p.subCategory1} ${p.subCategory2} ${p.subCategory3}'.toLowerCase();

      return _catMatch(p.category) &&
          (!_budget || p.price.toLowerCase() == 'free' || p.price == '₱' || p.price == '₱₱') &&
          (!_near || p.distanceKm <= 0.5) &&
          (q.trim().isEmpty || outside || searchableString.contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA), 
      body: SafeArea(
        child: Column(
          children: [
            _PremiumHeader(
              onQuery: (v) => setState(() => _query = v),
              budget: _budget,
              near: _near,
              open: _open,
              petFriendly: _petFriendly,
              kidFriendly: _kidFriendly,
              wheelchair: _wheelchair,
              onBudget: () => setState(() => _budget = !_budget),
              onNear: () => setState(() => _near = !_near),
              onOpen: () => setState(() => _open = !_open),
              onPetFriendly: () => setState(() => _petFriendly = !_petFriendly),
              onKidFriendly: () => setState(() => _kidFriendly = !_kidFriendly),
              onWheelchair: () => setState(() => _wheelchair = !_wheelchair),
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
                      focusedPlaceId: _focusedPlaceId, 
                      onFocusPlace: _focusOnMap, 
                      onClearFocus: _clearMapFocus, 
                    )
                  : _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                      : _hasError 
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.muted.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Failed to load places.\nPlease check your connection.",
                                    textAlign: TextAlign.center,
                                    style: AppText.ui(14, FontWeight.w500, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              itemCount: results.length + (outside ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (outside && index == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.only(bottom: 20),
                                    child: ErrorNote(
                                      title: 'Outside City of Manila',
                                      message: 'Discovery is limited to the City of Manila. Try Intramuros, Binondo, or Malate.',
                                    ),
                                  );
                                }
                                
                                final placeIndex = outside ? index - 1 : index;
                                
                                if (!outside && results.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 40),
                                    child: Center(
                                      child: Text(
                                        'No places match your filters.',
                                        style: AppText.ui(14, FontWeight.w500, color: AppColors.muted),
                                      ),
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: _PremiumPlaceCard(
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

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.onQuery,
    required this.budget,
    required this.near,
    required this.open,
    required this.petFriendly,
    required this.kidFriendly,
    required this.wheelchair,
    required this.onBudget,
    required this.onNear,
    required this.onOpen,
    required this.onPetFriendly,
    required this.onKidFriendly,
    required this.onWheelchair,
    required this.cats,
    required this.filter,
    required this.onFilter,
    required this.mapView,
    required this.onView,
  });

  final ValueChanged<String> onQuery;
  final bool budget, near, open, petFriendly, kidFriendly, wheelchair, mapView;
  final VoidCallback onBudget, onNear, onOpen, onPetFriendly, onKidFriendly, onWheelchair;
  final List<String> cats;
  final String filter;
  final ValueChanged<String> onFilter;
  final ValueChanged<bool> onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discover', style: AppText.ui(28, FontWeight.w900, color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text('Manila’s best spots for your group', style: AppText.ui(14, FontWeight.w400, color: AppColors.muted)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _ViewToggle(label: 'List', icon: Icons.view_agenda_rounded, on: !mapView, onTap: () => onView(false)),
                    _ViewToggle(label: 'Map', icon: Icons.map_rounded, on: mapView, onTap: () => onView(true)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search_rounded, color: AppColors.orange, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: onQuery,
                    style: AppText.ui(15, FontWeight.w500, color: AppColors.navy),
                    cursorColor: AppColors.orange,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search museums, cafes, parks...',
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
            runSpacing: 10,
            children: [
              for (final c in cats)
                TaraletsChip(label: c, selected: filter == c, onTap: () => onFilter(c), compact: true),
            ],
          ),
          const SizedBox(height: 12),
          // IDINAGDAG: Mga bagong Quick Filters sa ilalim ng Categories
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TaraletsChip(label: 'Budget', selected: budget, onTap: onBudget, compact: true),
                const SizedBox(width: 6),
                TaraletsChip(label: 'Distance', selected: near, onTap: onNear, compact: true),
                const SizedBox(width: 6),
                TaraletsChip(label: 'Open Now', selected: open, onTap: onOpen, compact: true),
                const SizedBox(width: 6),
                TaraletsChip(label: 'Pet Friendly', selected: petFriendly, onTap: onPetFriendly, compact: true),
                const SizedBox(width: 6),
                TaraletsChip(label: 'Kid Friendly', selected: kidFriendly, onTap: onKidFriendly, compact: true),
                const SizedBox(width: 6),
                TaraletsChip(label: 'Wheelchair', selected: wheelchair, onTap: onWheelchair, compact: true),
              ],
            ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: on ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))] : [],
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

class _PremiumPlaceCard extends StatelessWidget {
  const _PremiumPlaceCard({required this.place, required this.onViewOnMap});
  final Place place;
  final VoidCallback onViewOnMap;

  @override
  Widget build(BuildContext context) {
    final bool hasImage = place.imageUrl.isNotEmpty && place.imageUrl.toLowerCase() != 'nan';
    
    final List<Color> fallbackColors = [
      AppColors.orange, AppColors.navy, Colors.teal, Colors.purple, Colors.pink
    ];
    final Color clusterColor = fallbackColors[place.clusterId % fallbackColors.length];

    // Kunin ang mga sub-categories at tanggaling ang mga empty/null
    final List<String> subCats = [place.subCategory1, place.subCategory2, place.subCategory3]
        .where((s) => s.isNotEmpty && s != 'nan')
        .toList();

    return GestureDetector(
      onTap: () {
        // Binibigay pa rin natin ang map switch function kung kailangan sa popup
        showPlaceDetail(context, place, onViewOnMap: onViewOnMap);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              child: SizedBox(
                height: 180, 
                child: hasImage
                    ? Image.network(
                        place.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildImageFallback(clusterColor),
                      )
                    : _buildImageFallback(clusterColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          style: AppText.ui(18, FontWeight.w800, color: AppColors.navy),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('${place.rating}', style: AppText.ui(14, FontWeight.w800, color: AppColors.navy)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(getCategoryIcon(place.category), size: 14, color: AppColors.orange),
                      const SizedBox(width: 6),
                      Text(
                        place.category,
                        style: AppText.ui(13, FontWeight.w600, color: AppColors.orange),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("•", style: TextStyle(color: Colors.grey)),
                      ),
                      Icon(Icons.payments_outlined, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place.price, 
                          style: AppText.ui(13, FontWeight.w500, color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // IDINAGDAG: Mga Sub-Category Tags sa loob ng Place Card!
                  if (subCats.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: subCats.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s, 
                            style: AppText.ui(11, FontWeight.w600, color: Colors.grey.shade700)
                          ),
                        )).toList(),
                      ),
                    ),

                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place.sub, // Exact address galing dataset
                          style: AppText.ui(13, FontWeight.w400, color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFallback(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)]),
            child: Icon(getCategoryIcon(place.category), size: 36, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            place.category,
            style: AppText.ui(13, FontWeight.w700, color: color.withOpacity(0.8), letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  final List<Place> places;
  final MapController mapController;
  final int? activeClusterId;
  final int? focusedPlaceId; 
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
    Place? focusedPlace;

    if (focusedPlaceId != null) {
      try {
        focusedPlace = places.firstWhere((p) => p.id == focusedPlaceId);
      } catch (_) {}
    }

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
      if (focusedPlace != null) {
        const distanceCalculator = Distance();
        final centerLatLng = LatLng(focusedPlace.lat, focusedPlace.lng);
        
        mapPlaces = places.where((p) {
          final distMeters = distanceCalculator.distance(centerLatLng, LatLng(p.lat, p.lng));
          return distMeters <= 500.0;
        }).toList();
      } else {
        mapPlaces = places.where((p) => p.clusterId == activeClusterId).toList();
      }
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
            
            CircleLayer(
              circles: [
                if (focusedPlace != null)
                  CircleMarker(
                    point: LatLng(focusedPlace.lat, focusedPlace.lng),
                    color: AppColors.orange.withOpacity(0.08), 
                    borderColor: AppColors.orange.withOpacity(0.4),
                    borderStrokeWidth: 1.5,
                    radius: 500, 
                    useRadiusInMeter: true, 
                  ),
              ],
            ),
            
            MarkerLayer(
              markers: mapPlaces.map((p) {
                final bool isFocused = p.id == focusedPlaceId;
                final Color baseColor = clusterColors[p.clusterId % clusterColors.length];
                
                final double markerSize = isFocused ? 48.0 : 26.0;

                return Marker(
                  point: LatLng(p.lat, p.lng),
                  width: markerSize,
                  height: markerSize,
                  child: GestureDetector(
                    onTap: () {
                      onFocusPlace(p);
                      showPlaceDetail(context, p, onViewOnMap: () {
                        mapController.move(LatLng(p.lat, p.lng), 17.5);
                      });
                    },
                    child: isFocused 
                        ? const Icon(Icons.location_on, color: AppColors.navy, size: 48)
                        : Container(
                            decoration: BoxDecoration(
                              color: baseColor.withOpacity(0.95),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                            ),
                            child: Icon(
                              getCategoryIcon(p.category), 
                              color: Colors.white,
                              size: 14, 
                            ),
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