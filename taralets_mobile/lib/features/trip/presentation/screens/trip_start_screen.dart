import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/step_bar.dart';
import '../../../../shared/widgets/taralets_field.dart';
import '../../../routing/data/routing_repository.dart';

class TripStartScreen extends ConsumerStatefulWidget {
  const TripStartScreen({super.key});

  @override
  ConsumerState<TripStartScreen> createState() => _TripStartScreenState();
}

class _TripStartScreenState extends ConsumerState<TripStartScreen> {
  static const _locations = <(String, double, double)>[
    ('Plaza Roma, Intramuros', 14.5896, 120.9753),
    ('Luneta Park / Rizal Park', 14.5831, 120.9794),
    ('Binondo Church', 14.6004, 120.9742),
    ('National Museum Plaza', 14.5870, 120.9815),
    ('Baywalk Promenade', 14.5740, 120.9760),
  ];

  final _mapController = MapController();
  final _queryController = TextEditingController();
  Timer? _debounce;
  LatLng _point = const LatLng(14.5896, 120.9753);
  String _locationName = 'Plaza Roma, Intramuros';
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _locating = false;
  bool _choosingOption = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final results = await ref
            .read(routingRepositoryProvider)
            .searchPlaces(value.trim());
        if (!mounted) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _select(String name, double lat, double lng) {
    final point = LatLng(lat, lng);
    setState(() {
      _locationName = name;
      _point = point;
      _queryController.text = name;
      _results = [];
      FocusScope.of(context).unfocus();
    });
    _mapController.move(point, 15.5);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final point = await ref
        .read(routingRepositoryProvider)
        .getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (point == null || !_isInManila(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a location within the City of Manila.'),
        ),
      );
      return;
    }
    _select('My Current Location', point.latitude, point.longitude);
  }

  bool _isInManila(LatLng point) =>
      point.latitude >= 14.55 &&
      point.latitude <= 14.63 &&
      point.longitude >= 120.95 &&
      point.longitude <= 121.03;

  bool get _outsideManila => !_isInManila(_point);

  Map<String, Object> get _locationExtra => {
    'locationName': _locationName,
    'latitude': _point.latitude,
    'longitude': _point.longitude,
  };

  void _openOption(String route) {
    context.push(route, extra: _locationExtra);
  }

  Widget _searchPanel() {
    final query = _queryController.text.trim().toLowerCase();
    final presets = _locations
        .where(
          (location) =>
              query.isEmpty || location.$1.toLowerCase().contains(query),
        )
        .toList();
    final height = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.43),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaraletsField(
            hint: 'Search location',
            controller: _queryController,
            icon: const Icon(Icons.search_rounded, color: AppColors.muted),
            onChanged: _search,
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _locating ? null : _useCurrentLocation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  if (_locating)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.my_location, color: AppColors.orange),
                  const SizedBox(width: 10),
                  Text(
                    'Use my current location',
                    style: AppText.ui(
                      13,
                      FontWeight.w600,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            child: _searching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: AppColors.orange),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      if (_results.isNotEmpty)
                        for (final result in _results)
                          _locationTile(
                            result['name']?.toString() ?? 'Manila location',
                            result['full_address']?.toString() ?? '',
                            () => _select(
                              result['name']?.toString() ?? 'Manila location',
                              (result['lat'] as num).toDouble(),
                              (result['lng'] as num).toDouble(),
                            ),
                          )
                      else
                        for (final item in presets)
                          _locationTile(
                            item.$1,
                            'City of Manila',
                            () => _select(item.$1, item.$2, item.$3),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _locationTile(String name, String subtitle, VoidCallback onTap) {
    final selected = name == _locationName;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: onTap,
      leading: Icon(
        Icons.place_outlined,
        color: selected ? AppColors.orange : AppColors.muted,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.ui(13, FontWeight.w700, color: AppColors.text),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
      ),
      trailing: selected
          ? const Icon(Icons.check, size: 18, color: AppColors.orange)
          : null,
    );
  }

  Widget _optionPanel() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.place, color: AppColors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationName,
                style: AppText.ui(14, FontWeight.w800, color: AppColors.navy),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _choosingOption = false),
              child: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _openOption(AppRoutes.createTrip),
          icon: const Icon(Icons.group_add_rounded),
          label: const Text('Create a New Group'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openOption(AppRoutes.friendsTrips),
          icon: const Icon(Icons.people_alt_outlined),
          label: const Text('Browse Friends’ Itineraries'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.joinTrip),
          child: const Text('Have a friend’s invite code?'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 15,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && position.center != null) {
                    setState(() {
                      _point = position.center!;
                      _locationName = 'Pinned location';
                      _queryController.clear();
                      _results = [];
                      FocusScope.of(context).unfocus();
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.taralets.app',
                ),
              ],
            ),
          ),
          Center(
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📍', style: TextStyle(fontSize: 40)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .16),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      _outsideManila
                          ? 'OUT OF BOUNDARY'
                          : _locationName.split(',').first,
                      style: AppText.ui(
                        11,
                        FontWeight.w700,
                        color: _outsideManila
                            ? AppColors.errorTitle
                            : AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 12,
                20,
                48,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: .96),
                    Colors.white.withValues(alpha: .8),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0, .65, 1],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      BackButtonTile(onTap: () => context.pop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _choosingOption
                              ? 'Choose an Option'
                              : 'Meetup Location',
                          style: AppText.ui(
                            18,
                            FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const StepBar(
                    current: 1,
                    labels: [
                      'Location',
                      'Details',
                      'Invite',
                      'Prefs',
                      'Review',
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _choosingOption ? _optionPanel() : _searchPanel(),
                if (!_choosingOption) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _outsideManila
                          ? null
                          : () => setState(() => _choosingOption = true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Confirm Location →',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
