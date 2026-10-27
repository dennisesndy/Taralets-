import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/geo_boundary.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/error_note.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_field.dart';
import '../../data/meetup_presets.dart';

/// Leader-only Edit Trip form: the Create Trip "Details" and "Meetup" steps on
/// one screen, pre-filled with the current trip. Pops with the saved [Trip].
class EditTripScreen extends ConsumerStatefulWidget {
  const EditTripScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends ConsumerState<EditTripScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.trip.title,
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.trip.description,
  );
  final _query = TextEditingController();
  final _mapController = MapController();

  DateTime? _date;
  late TimeOfDay _meetupTime = parseTimeOfDay(widget.trip.arrivalTarget);
  late TimeOfDay _wrapTime = parseTimeOfDay(
    widget.trip.wrapUp,
    fallback: const TimeOfDay(hour: 20, minute: 0),
  );
  late String _selected = widget.trip.meetupFull;
  late LatLng _pin = LatLng(widget.trip.latitude, widget.trip.longitude);
  late final List<MeetupPreset> _options;
  MeetupPreset? _selectedPreset;
  bool _customPin = false;

  bool _checking = true; // leader guard still running
  bool _saving = false;
  TripException? _serverError;

  @override
  void initState() {
    super.initState();
    _date = widget.trip.date;

    final known = meetupPresets.any((p) => p.name == widget.trip.meetupFull);
    _options = [
      if (!known)
        MeetupPreset(
          widget.trip.meetupFull,
          widget.trip.latitude,
          widget.trip.longitude,
        ),
      ...meetupPresets,
    ];
    _selectedPreset = _options.where((p) => p.name == _selected).firstOrNull;

    WidgetsBinding.instance.addPostFrameCallback((_) => _guard());
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Leader-only guard: non-leaders are sent back with a SnackBar.
  Future<void> _guard() async {
    final me = await ref.read(currentUserProvider.future);
    if (!mounted) return;
    if (!widget.trip.isLeader(me.id)) {
      final messenger = ScaffoldMessenger.of(context);
      context.canPop() ? context.pop() : context.go(AppRoutes.trips);
      messenger.showSnackBar(
        const SnackBar(content: Text('Only the leader can edit this trip.')),
      );
      return;
    }
    setState(() => _checking = false);
  }

  bool get _outOfBoundary {
    return !GeoBoundary.isWithinMetroManila(_pin.latitude, _pin.longitude);
  }

  void _selectPreset(MeetupPreset place) {
    setState(() {
      _selected = place.name;
      _selectedPreset = place;
      _pin = LatLng(place.lat, place.lng);
      _customPin = false;
    });
    _mapController.move(_pin, 14.5);
  }

  void _onMapPositionChanged(MapPosition position, bool hasGesture) {
    final center = position.center;
    if (!hasGesture || center == null) return;
    _pin = center;
    _customPin = true;
    _selected =
        'Pinned location (${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)})';
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _date != null && !_date!.isBefore(today) ? _date! : today,
      firstDate: today,
      lastDate: DateTime(now.year + 3),
      builder: _pickerTheme,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool meetup) async {
    final t = await showTimePicker(
      context: context,
      initialTime: meetup ? _meetupTime : _wrapTime,
      builder: _pickerTheme,
    );
    if (t != null) setState(() => meetup ? _meetupTime = t : _wrapTime = t);
  }

  Widget _pickerTheme(BuildContext c, Widget? child) => Theme(
    data: Theme.of(c).copyWith(
      colorScheme: Theme.of(c).colorScheme.copyWith(primary: AppColors.orange),
    ),
    child: child!,
  );

  Future<void> _save() async {
    if (_saving || _outOfBoundary) return;
    final base = widget.trip;
    final preset = _options.where((p) => p.name == _selected).firstOrNull;
    final placeName = _customPin || preset == null ? _selected : preset.name;
    final title = _name.text.trim().isEmpty ? base.title : _name.text.trim();

    final updated = base.copyWith(
      title: title,
      description: _desc.text.trim(),
      date: _date,
      dateLabel: _date != null ? formatShortDate(_date!) : base.dateLabel,
      longDate: _date != null ? formatLongDate(_date!) : base.longDate,
      arrivalTarget: formatTimeOfDay(_meetupTime),
      wrapUp: formatTimeOfDay(_wrapTime),
      meetup: _customPin
          ? 'Pinned location'
          : placeName.split(',').first.trim(),
      meetupFull: placeName,
      latitude: _pin.latitude,
      longitude: _pin.longitude,
    );

    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      final saved = await ref.read(tripRepositoryProvider).updateTrip(updated);
      ref.invalidate(myTripsProvider);
      if (mounted) context.pop(saved);
    } on TripException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _serverError = e;
        });
      }
    }
  }

  BoxDecoration get _cardDeco => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 6,
        offset: const Offset(0, 1),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BackButtonTile(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.trips),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Trip',
                    style: AppText.ui(
                      18,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ..._details(),
              ..._meetup(),
              if (_serverError != null) ...[
                ErrorNote(
                  title: _serverError!.title,
                  message: _serverError!.message,
                ),
                const SizedBox(height: 14),
              ],
              Opacity(
                opacity: _outOfBoundary ? 0.45 : 1,
                child: TaraletsButton.orange(
                  label: 'Save Changes',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
              const SizedBox(height: 10),
              TaraletsButton.ghost(
                label: 'Cancel',
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.trips),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Details (Create Trip step 1)
  // -------------------------------------------------------------------------

  Widget _timeBox(
    String label,
    TimeOfDay t,
    bool meetup, {
    required bool wrap,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.ui(13, FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _pickTime(meetup),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: wrap ? AppColors.orangeSoft : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: wrap
                      ? AppColors.orange.withValues(alpha: 0.25)
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                formatTimeOfDay(t),
                style: AppText.mono(
                  13,
                  FontWeight.w400,
                  color: wrap ? AppColors.orange : AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _details() {
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: _cardDeco.copyWith(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trip details',
              style: AppText.ui(15, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            TaraletsField(
              label: 'Trip Name',
              hint: 'Intramuros & Binondo Day Out',
              controller: _name,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date', style: AppText.ui(13, FontWeight.w600)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Text(
                      _date != null
                          ? formatInputDate(_date!)
                          : widget.trip.longDate,
                      style: AppText.ui(14, FontWeight.w400),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _timeBox('Meetup Time', _meetupTime, true, wrap: false),
                const SizedBox(width: 10),
                _timeBox('Wrap-Up Time', _wrapTime, false, wrap: true),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  AppIcons.calendar(
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip window: ${formatTimeOfDay(_meetupTime)} — ${formatTimeOfDay(_wrapTime)}',
                      style: AppText.ui(
                        12,
                        FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TaraletsField(
              label: 'Description (optional)',
              hint: 'Weekend food and heritage trip with friends.',
              controller: _desc,
              height: 70,
            ),
          ],
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Meetup (Create Trip step 2, Manila presets only)
  // -------------------------------------------------------------------------

  List<Widget> _meetup() {
    final q = _query.text.toLowerCase().trim();
    final shown = q.isEmpty
        ? _options
        : _options.where((p) => p.name.toLowerCase().contains(q)).toList();
    final out = _outOfBoundary;

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          'Where should everyone meet?',
          style: AppText.ui(16, FontWeight.w700),
        ),
      ),
      Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: LayoutBuilder(
          builder: (context, c) {
            return Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pin,
                    initialZoom: 14.5,
                    minZoom: 10,
                    maxZoom: 18,
                    onPositionChanged: _onMapPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.taralets.app',
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_pin,
                          size: 42,
                          color: out ? AppColors.errorTitle : AppColors.orange,
                        ),
                        Container(
                          constraints: BoxConstraints(maxWidth: c.maxWidth * .72),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: out ? AppColors.redSoft : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .15),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            out
                                ? 'OUT OF BOUNDARY'
                                : _customPin
                                ? 'Pinned location'
                                : _selected.split(',').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              10,
                              FontWeight.w700,
                              color: out
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
                  left: 8,
                  bottom: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Drag map to adjust pin',
                        style: AppText.ui(
                          10,
                          FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_customPin)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: () {
                        final place = _selectedPreset;
                        if (place != null) {
                          _selectPreset(place);
                        } else {
                          _selectPreset(meetupPresets.first);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'Reset pin',
                          style: AppText.ui(
                            11,
                            FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaraletsField(
              hint: 'Search location',
              controller: _query,
              icon: AppIcons.search(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty && !out)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Text(
                  'No matching presets. Try a landmark in Metro Manila.',
                  style: AppText.ui(
                    12,
                    FontWeight.w400,
                    color: AppColors.muted,
                  ),
                ),
              ),
            for (final o in shown)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectPreset(o),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _selected == o.name
                        ? AppColors.orangeSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      AppIcons.pin(
                        color: _selected == o.name
                            ? AppColors.orange
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          o.name,
                          style: AppText.ui(
                            13,
                            _selected == o.name
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selected == o.name
                                ? AppColors.orange
                                : AppColors.text,
                          ),
                        ),
                      ),
                      if (_selected == o.name)
                        AppIcons.check(color: AppColors.orange, size: 14),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      if (out)
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: ErrorNote(
            title: 'OUT OF BOUNDARY',
            message:
                'This meetup location is outside the supported Metro Manila area. Choose a location inside Metro Manila to continue.',
          ),
        ),
    ];
  }
}
