import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/geo_boundary.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/error_note.dart';
import '../../../../shared/widgets/map_background.dart';
import '../../../../shared/widgets/pref_card.dart';
import '../../../../shared/widgets/step_bar.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_field.dart';
import '../../data/models/trip_models.dart';

/// 5-step Create Trip wizard, matching Figma Create1 .. Create5.
class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _Member {
  _Member(this.name, this.role, this.joined);
  final String name;
  final String role;
  bool joined;
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  static const _titles = [
    'Create a Trip',
    'Meetup Location',
    'Invite Members',
    'Group Preferences',
    'Review Trip',
  ];

  /// Manila-only meetup presets (Figma `options`) with coordinates.
  static const _presets = <(String, double, double)>[
    ('Plaza Roma, Intramuros', 14.5896, 120.9753),
    ('Luneta Park / Rizal Park', 14.5831, 120.9794),
    ('Binondo Church', 14.6004, 120.9742),
    ('National Museum Plaza', 14.5870, 120.9815),
    ('Baywalk Promenade', 14.5740, 120.9760),
    ('Use my current location', GeoBoundary.defaultLat, GeoBoundary.defaultLng),
  ];

  static const _prefOptions = <(String, String)>[
    ('🏛', 'Heritage & Culture'),
    ('🍜', 'Food & Street Food'),
    ('☕', 'Cafés'),
    ('🌿', 'Parks & Outdoors'),
    ('🛍', 'Shopping'),
    ('📸', 'Photo Spots'),
    ('🎨', 'Arts & Museums'),
    ('🌅', 'Scenic / Sunset'),
    ('🚶', 'Walking-friendly'),
    ('💰', 'Budget-friendly'),
  ];

  static const _shortLabel = {
    'Heritage & Culture': 'Heritage',
    'Food & Street Food': 'Food',
    'Arts & Museums': 'Museums',
    'Parks & Outdoors': 'Parks',
    'Scenic / Sunset': 'Scenic',
  };

  int _step = 1;
  bool _submitting = false;
  late final String _code = generateRoomCode();

  // Step 1
  final _name = TextEditingController(text: 'Intramuros & Binondo Day Out');
  final _desc = TextEditingController();
  DateTime? _date;
  TimeOfDay _meetupTime = const TimeOfDay(hour: 14, minute: 30);
  TimeOfDay _wrapTime = const TimeOfDay(hour: 20, minute: 0);

  // Step 2
  String _selected = 'Plaza Roma, Intramuros';
  final _query = TextEditingController();
  bool _pinMoved = false;

  // Step 3
  final _username = TextEditingController();
  final List<_Member> _members = [
    _Member('Dennise', 'Leader', true),
    _Member('Ana', 'Member', true),
    _Member('Paola', 'Member', false),
    _Member('Jewelle', 'Member', true),
  ];
  bool _simulated = false;

  // Step 4
  List<String> _cats = [
    'Heritage & Culture',
    'Food & Street Food',
    'Budget-friendly',
  ];
  String _budget = '₱₱';
  String _walking = 'Moderate';

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _query.dispose();
    _username.dispose();
    super.dispose();
  }

  bool get _outOfBoundary {
    if (_pinMoved || GeoBoundary.mentionsOutside(_query.text)) return true;
    final p = _presets.where((p) => p.$1 == _selected).firstOrNull;
    return p != null && !GeoBoundary.isWithinMetroManila(p.$2, p.$3);
  }

  void _back() {
    if (_step == 1) {
      context.canPop() ? context.pop() : context.go(AppRoutes.home);
    } else {
      setState(() => _step--);
    }
  }

  void _next() {
    if (_step == 2 && _outOfBoundary) return;
    setState(() => _step++);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final p = _presets.firstWhere((p) => p.$1 == _selected);
    final dto = CreateTripDto(
      code: _code,
      title: _name.text.trim().isEmpty
          ? 'Intramuros & Binondo Day Out'
          : _name.text.trim(),
      description: _desc.text.trim(),
      date: _date ?? DateTime.now(),
      meetupTime: _meetupTime,
      wrapUpTime: _wrapTime,
      meetupName: _selected,
      latitude: p.$2,
      longitude: p.$3,
      memberNames: _members.map((m) => m.name).toList(),
      preferences: GroupPreferences(
        categories: _cats,
        budget: _budget,
        walking: _walking,
      ),
    );
    try {
      final trip = await ref.read(tripRepositoryProvider).createTrip(dto);
      ref.invalidate(myTripsProvider);
      if (mounted) context.go(AppRoutes.tripCreated, extra: trip);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create the trip. Try again.")),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
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

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      1 => _step1(),
      2 => _step2(),
      3 => _step3(),
      4 => _step4(),
      _ => _step5(),
    };

    final button = switch (_step) {
      1 => TaraletsButton.orange(label: 'Continue →', onPressed: _next),
      2 => Opacity(
        opacity: _outOfBoundary ? 0.45 : 1,
        child: TaraletsButton.orange(
          label: 'Confirm Location →',
          onPressed: _next,
        ),
      ),
      3 => TaraletsButton.orange(
        label: 'Continue to Preferences →',
        onPressed: _next,
      ),
      4 => TaraletsButton.orange(
        label: 'Confirm Preferences →',
        onPressed: _next,
      ),
      _ => TaraletsButton.orange(
        label: 'Create Trip 🎉',
        isLoading: _submitting,
        onPressed: _submit,
      ),
    };

    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
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
                    BackButtonTile(onTap: _back),
                    const SizedBox(width: 12),
                    Text(
                      _titles[_step - 1],
                      style: AppText.ui(
                        18,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                StepBar(current: _step),
                ...body,
                button,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 1: details
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

  List<Widget> _step1() {
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Let's plan your trip",
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
                      _date == null
                          ? 'August 29, 2026'
                          : formatInputDate(_date!),
                      style: AppText.ui(
                        14,
                        FontWeight.w400,
                        color: _date == null
                            ? AppColors.placeholder
                            : AppColors.text,
                      ),
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
            const SizedBox(height: 8),
            Text(
              "Taralets! will calculate each member's leave-by time and build time blocks around your schedule.",
              style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
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
  // Step 2: meetup (Manila presets only)
  // -------------------------------------------------------------------------

  List<Widget> _step2() {
    final q = _query.text.toLowerCase().trim();
    final shown = q.isEmpty
        ? _presets
        : _presets.where((p) => p.$1.toLowerCase().contains(q)).toList();
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
                const Positioned.fill(child: MapBackground()),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                  left: (_pinMoved ? 0.85 : 0.42) * c.maxWidth,
                  top: (_pinMoved ? 0.15 : 0.35) * c.maxHeight,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 28)),
                        Transform.translate(
                          offset: const Offset(0, -4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: out ? AppColors.redSoft : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              out
                                  ? 'OUT OF BOUNDARY'
                                  : _selected.split(',').first,
                              style: AppText.ui(
                                10,
                                FontWeight.w700,
                                color: out
                                    ? AppColors.errorTitle
                                    : AppColors.navy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _pinMoved = !_pinMoved),
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
                        _pinMoved ? 'Reset pin' : 'Adjust pin',
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
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
                onTap: () => setState(() => _selected = o.$1),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _selected == o.$1
                        ? AppColors.orangeSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      AppIcons.pin(
                        color: _selected == o.$1
                            ? AppColors.orange
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          o.$1,
                          style: AppText.ui(
                            13,
                            _selected == o.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selected == o.$1
                                ? AppColors.orange
                                : AppColors.text,
                          ),
                        ),
                      ),
                      if (_selected == o.$1)
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

  // -------------------------------------------------------------------------
  // Step 3: invite
  // -------------------------------------------------------------------------

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

  List<Widget> _step3() {
    final joined = _members.where((m) => m.joined).length;

    return [
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Who's joining you?", style: AppText.ui(13, FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'ROOM CODE',
                    style: AppText.ui(
                      11,
                      FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _code,
                    style: AppText.mono(
                      30,
                      FontWeight.w900,
                      color: AppColors.navy,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TaraletsButton.ghost(
                    label: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TaraletsButton.orange(
                    label: 'Share Invite',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: 'Join my Taralets trip with room code $_code',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite message copied')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Row(
          children: [
            Expanded(
              child: TaraletsField(
                hint: 'Invite by username...',
                controller: _username,
                radius: 10,
                fontSize: 13,
                verticalPadding: 12,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final n = _username.text.trim();
                if (n.isEmpty) return;
                setState(() {
                  _members.add(
                    _Member(
                      n[0].toUpperCase() + n.substring(1),
                      'Member',
                      false,
                    ),
                  );
                  _username.clear();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Add',
                  style: AppText.ui(13, FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trip Members', style: AppText.ui(13, FontWeight.w700)),
                Text(
                  '$joined/${_members.length} joined',
                  style: AppText.ui(
                    12,
                    FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final m in _members) ...[
              Row(
                children: [
                  Avatar(name: m.name, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: AppText.ui(14, FontWeight.w700)),
                        const SizedBox(height: 1),
                        Text(
                          m.role,
                          style: AppText.ui(
                            11,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: m.joined
                          ? AppColors.greenSoft
                          : AppColors.amberSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      m.joined ? 'Joined' : 'Pending',
                      style: AppText.ui(
                        11,
                        FontWeight.w700,
                        color: m.joined
                            ? AppColors.greenText
                            : AppColors.amberText,
                      ),
                    ),
                  ),
                ],
              ),
              if (m != _members.last) const SizedBox(height: 10),
            ],
            if (!_simulated)
              GestureDetector(
                onTap: () => setState(() {
                  for (final m in _members) {
                    if (m.name == 'Paola') m.joined = true;
                  }
                  _simulated = true;
                }),
                child: Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Text(
                    '▶ Simulate: Paola joins the trip',
                    style: AppText.ui(
                      13,
                      FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      'Paola joined the trip!',
                      style: AppText.ui(
                        12,
                        FontWeight.w700,
                        color: AppColors.greenText,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Step 4: preferences
  // -------------------------------------------------------------------------

  List<Widget> _step4() {
    void toggle(String l) => setState(() {
      _cats = _cats.contains(l) ? (List.of(_cats)..remove(l)) : [..._cats, l];
    });

    final rows = <Widget>[];
    for (var i = 0; i < _prefOptions.length; i += 2) {
      final pair = _prefOptions.skip(i).take(2).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < pair.length; j++) ...[
                if (j > 0) const SizedBox(width: 10),
                Expanded(
                  child: PrefCard(
                    icon: pair[j].$1,
                    label: pair[j].$2,
                    selected: _cats.contains(pair[j].$2),
                    onTap: () => toggle(pair[j].$2),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + 2 < _prefOptions.length) rows.add(const SizedBox(height: 10));
    }

    Widget optionRow(
      List<String> opts,
      String value,
      ValueChanged<String> set,
      double font,
    ) => Row(
      children: [
        for (var i = 0; i < opts.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: OptionButton(
              label: opts[i],
              selected: value == opts[i],
              fontSize: font,
              onTap: () => setState(() => set(opts[i])),
            ),
          ),
        ],
      ],
    );

    return [
      Text('What do you want to do?', style: AppText.ui(15, FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        "Choose what you'd enjoy most. We'll find places that work for everyone.",
        style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
      ),
      const SizedBox(height: 14),
      ...rows,
      const SizedBox(height: 16),
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "What's your preferred budget?",
              style: AppText.ui(13, FontWeight.w700),
            ),
            const SizedBox(height: 10),
            optionRow(
              const ['₱', '₱₱', '₱₱₱'],
              _budget,
              (v) => _budget = v,
              14,
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How much walking is okay?',
              style: AppText.ui(13, FontWeight.w700),
            ),
            const SizedBox(height: 10),
            optionRow(
              const ['Low', 'Moderate', 'A lot'],
              _walking,
              (v) => _walking = v,
              13,
            ),
          ],
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Step 5: review
  // -------------------------------------------------------------------------

  List<Widget> _step5() {
    final title = _name.text.trim().isEmpty
        ? 'Intramuros & Binondo Day Out'
        : _name.text.trim();
    final rows = [
      ('📍', 'Meetup', _selected),
      ('⏰', 'Target Arrival', formatTimeOfDay(_meetupTime)),
      ('👥', 'Members', '${_members.length} people'),
    ];

    return [
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.navy,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.ui(18, FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatLongDate(_date ?? DateTime.now()),
                    style: AppText.ui(
                      13,
                      FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in rows) ...[
                    Row(
                      children: [
                        Text(r.$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.$2,
                              style: AppText.ui(
                                11,
                                FontWeight.w400,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(r.$3, style: AppText.ui(14, FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'PREFERENCES',
                    style: AppText.ui(
                      11,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _cats)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orangeSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _shortLabel[t] ?? t,
                            style: AppText.ui(
                              12,
                              FontWeight.w600,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in _members)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Avatar(name: m.name, size: 34),
                            const SizedBox(height: 3),
                            Text(
                              m.name,
                              style: AppText.ui(
                                9,
                                FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontSize = 13,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeSoft : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.ui(
            fontSize,
            FontWeight.w700,
            color: selected ? AppColors.orange : AppColors.text,
          ),
        ),
      ),
    );
  }
}
