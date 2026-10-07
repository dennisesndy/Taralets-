import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../data/manila_places.dart'; // Siguraduhing tama ang import path na ito sa Place model mo
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
  // Idinagdag ang state variables para sa API data
  List<Place> _apiPlaces = [];
  bool _isLoading = true;

  static const _cats = [
    'All',
    'Heritage',
    'Food & Cafés',
    'Museums',
    'Leisure',
  ];

  static const _outside = [
    'makati',
    'quezon',
    'pasig',
    'taguig',
    'tagaytay',
    'cebu',
    'baguio',
    'mandaluyong',
    'pasay',
    'caloocan',
    'antipolo',
    'bgc',
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
    _fetchPlacesList(); // I-fetch agad pagka-load ng screen
  }

  // Function para kunin ang lahat ng places para sa List View
  Future<void> _fetchPlacesList() async {
    final url = Uri.parse('http://10.0.2.2:8000/api/v1/places'); 
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _apiPlaces = data.map((json) => Place.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching places list: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _catMatch(String c) =>
      _filter == 'All' ||
      (_filter == 'Heritage' && c.contains('Heritage')) ||
      (_filter == 'Food & Cafés' &&
          RegExp('Food|Restaurant|Caf').hasMatch(c)) ||
      (_filter == 'Museums' && c == 'Museum') ||
      (_filter == 'Leisure' && c == 'Leisure');

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final outside = _outside.any(q.contains);
    
    // Gagamitin na ang _apiPlaces imbes na hardcoded na manilaPlaces
    final results = _apiPlaces.where((p) {
      return _catMatch(p.category) &&
          (!_budget || p.price.length <= 1) &&
          (!_near || p.distanceKm <= 0.5) &&
          // Kung walang isOpen na property sa API model mo, tanggalin ang condition na ito
          // (!_open || p.isOpen) && 
          (q.trim().isEmpty ||
              outside ||
              '${p.name} ${p.sub} ${p.category}'.toLowerCase().contains(q));
    }).toList();

    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        children: [
          _Header(
            onQuery: (v) => setState(() => _query = v),
            budget: _budget,
            near: _near,
            open: _open,
            onBudget: () => setState(() => _budget = !_budget),
            onNear: () => setState(() => _near = !_near),
            onOpen: () => setState(() => _open = !_open),
            cats: _cats,
            filter: _filter,
            onFilter: (c) => setState(() => _filter = c),
            mapView: _mapView,
            onView: (map) => setState(() => _mapView = map),
          ),
          Expanded(
            child: _mapView
                ? const _MapView()
                : _isLoading 
                    ? const Center(child: CircularProgressIndicator()) // Loading indicator
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        children: [
                          if (outside)
                            const ErrorNote(
                              title: 'Outside City of Manila',
                              message:
                                  'Discovery is limited to the City of Manila. Try Intramuros, Binondo, Ermita or Malate.',
                            ),
                          if (!outside && results.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No places match these filters.',
                                textAlign: TextAlign.center,
                                style: AppText.ui(
                                  13,
                                  FontWeight.w400,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          if (!outside)
                            for (final p in results) ...[
                              _PlaceCard(place: p),
                              const SizedBox(height: 12),
                            ],
                          if (!outside && results.isNotEmpty)
                            const _NearbyClusters(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover Manila',
            style: AppText.ui(20, FontWeight.w800, color: AppColors.navy),
          ),
          const SizedBox(height: 2),
          Text(
            'Find places your group might enjoy.',
            style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                AppIcons.search(),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: onQuery,
                    style: AppText.ui(13, FontWeight.w400),
                    cursorColor: AppColors.orange,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search cafés, museums, landmarks...',
                      hintStyle: AppText.ui(
                        13,
                        FontWeight.w400,
                        color: AppColors.placeholder,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discovery is limited to the City of Manila.',
            style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TaraletsChip(
                label: 'Budget',
                selected: budget,
                onTap: onBudget,
                compact: true,
              ),
              const SizedBox(width: 6),
              TaraletsChip(
                label: 'Distance',
                selected: near,
                onTap: onNear,
                compact: true,
              ),
              const SizedBox(width: 6),
              TaraletsChip(
                label: 'Open Now',
                selected: open,
                onTap: onOpen,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in cats) ...[
                        TaraletsChip(
                          label: c,
                          selected: filter == c,
                          onTap: () => onFilter(c),
                          compact: true,
                        ),
                        if (c != cats.last) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _ViewToggle(
                      label: '≡ List',
                      on: !mapView,
                      onTap: () => onView(false),
                    ),
                    const SizedBox(width: 2),
                    _ViewToggle(
                      label: '⊞ Map',
                      on: mapView,
                      onTap: () => onView(true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppText.ui(
            12,
            FontWeight.w600,
            color: on ? AppColors.text : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    return TaraletsCard(
      clip: true,
      onTap: () => showPlaceDetail(context, place),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 100,
            color: AppColors.bg,
            alignment: Alignment.center,
            child: Text(place.emoji, style: const TextStyle(fontSize: 48)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place.name, style: AppText.ui(15, FontWeight.w700)),
                          const SizedBox(height: 1),
                          Text(
                            place.sub,
                            style: AppText.ui(
                              12,
                              FontWeight.w400,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        place.category,
                        style: AppText.ui(
                          10,
                          FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppIcons.star(),
                    const SizedBox(width: 3),
                    Text('${place.rating}', style: AppText.ui(12, FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(
                      place.price,
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${place.distanceLabel} away',
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                    // Kung walang isOpen na property sa API model mo, pwede mo muna itong i-comment:
                    // const SizedBox(width: 8),
                    // Text(
                    //   place.isOpen ? '● Open' : '● Closed',
                    //   style: AppText.ui(
                    //     11,
                    //     FontWeight.w600,
                    //     color: place.isOpen ? AppColors.green : AppColors.red,
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Save',
                          style: AppText.ui(12, FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Add to Trip',
                          style: AppText.ui(
                            12,
                            FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyClusters extends StatelessWidget {
  const _NearbyClusters();

  static const _clusters = [
    (
      'INTRAMUROS',
      [
        'Intramuros',
        'Fort Santiago',
        'San Agustin Church',
        'Casa Manila',
        'Ilustrado',
      ],
    ),
    ('BINONDO', ['Binondo']),
  ];

  @override
  Widget build(BuildContext context) {
    return TaraletsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEARBY CLUSTERS',
            style: AppText.ui(
              11,
              FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final cl in _clusters)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cl.$1,
                    style: AppText.ui(
                      12,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final n in cl.$2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orangeSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            n,
                            style: AppText.ui(
                              11,
                              FontWeight.w600,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _fetchClusters();
  }

  Future<void> _fetchClusters() async {
    final url = Uri.parse('http://10.0.2.2:8000/api/v1/places/clusters');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List clusters = data['clusters'];

        List<Marker> newMarkers = [];
        
        final List<Color> clusterColors = [
          AppColors.orange,
          AppColors.navy,
          AppColors.purple,
          AppColors.green,
          Colors.teal,
          Colors.amber,
        ];

        for (var cluster in clusters) {
          int clusterId = cluster['cluster_id'];
          List places = cluster['places'];

          Color markerColor = cluster['is_outlier'] 
              ? Colors.grey 
              : clusterColors[clusterId % clusterColors.length];

          for (var place in places) {
            newMarkers.add(
              Marker(
                point: LatLng(place['lat'], place['lng']),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () async {
                    // Fetch full details gamit ang Place Detail endpoint
                    final detailUrl = Uri.parse('http://10.0.2.2:8000/api/v1/places/${place['id']}');
                    
                    try {
                      final detailRes = await http.get(detailUrl);
                      if (detailRes.statusCode == 200) {
                        final placeData = json.decode(detailRes.body);
                        final fullPlace = Place.fromJson(placeData);
                        
                        if (mounted) {
                          showPlaceDetail(context, fullPlace);
                        }
                      }
                    } catch (e) {
                      debugPrint("Error fetching place details: $e");
                    }
                  },
                  child: Icon(
                    Icons.location_on,
                    color: markerColor,
                    size: 32,
                  ),
                ),
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _markers = newMarkers;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching clusters: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(14.5829, 120.9786), // Rizal Park
        initialZoom: 13.5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.taralets.app',
        ),
        MarkerLayer(
          markers: _markers,
        ),
      ],
    );
  }
}