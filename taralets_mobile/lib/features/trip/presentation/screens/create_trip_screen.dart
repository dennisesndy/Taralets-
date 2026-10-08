import 'dart:async';
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
import '../../../../shared/widgets/step_bar.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_field.dart';
import '../../../profile/providers/preferences_provider.dart';
import '../../data/models/trip_models.dart';

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

  static const _presets = <(String, double, double)>[
    ('Plaza Roma, Intramuros', 14.5896, 120.9753),
    ('Luneta Park / Rizal Park', 14.5831, 120.9794),
    ('Binondo Church', 14.6004, 120.9742),
    ('National Museum Plaza', 14.5870, 120.9815),
    ('Baywalk Promenade', 14.5740, 120.9760),
    ('Use my current location', GeoBoundary.defaultLat, GeoBoundary.defaultLng),
  ];

  final List<String> _activityOptions = [
    "Accommodation",
    "Cafe",
    "Restaurant / Eatery",
    "Museum",
    "Church / Religious Site",
    "Park / Plaza",
    "Historical / Tourist Site",
    "Shop / Retail",
    "Health & Wellness",
    "Entertainment",
    "Recreation & Arts",
    "Community & Events",
  ];

  final List<String> _dietaryOptions = [
    'None',
    'Halal',
    'Vegan',
    'Budget-Friendly',
  ];

  final List<String> _paceOptions = ['Fast', 'Moderate', 'Leisure'];

  final List<String> _accessibilityOptions = [
    'Good for children',
    'Pet friendly',
    'Wheelchair accessible',
  ];

  static const Map<String, String> _activityEmoji = {
    "Accommodation": '🏨',
    "Cafe": '☕',
    "Restaurant / Eatery": '🍽️',
    "Museum": '🏛️',
    "Church / Religious Site": '⛪',
    "Park / Plaza": '🌳',
    "Historical / Tourist Site": '🗺️',
    "Shop / Retail": '🛍️',
    "Health & Wellness": '💆',
    "Entertainment": '🎭',
    "Recreation & Arts": '🎨',
    "Community & Events": '🎪',
  };

  static const Map<String, String> _dietaryEmoji = {
    'None': '🍽️',
    'Halal': '🥙',
    'Vegan': '🥗',
    'Budget-Friendly': '💸',
  };

  static const Map<String, String> _paceEmoji = {
    'Fast': '🏃',
    'Moderate': '👟',
    'Leisure': '🚶',
  };

  int _step = 1;
  bool _submitting = false;
  late final String _code = generateRoomCode();
  String? _createdTripId;
  Trip? _createdTrip;
  Timer? _membersPollTimer;

  final _name = TextEditingController(text: '');
  final _desc = TextEditingController();
  DateTime? _date;
  TimeOfDay _meetupTime = const TimeOfDay(hour: 14, minute: 30);
  TimeOfDay _wrapTime = const TimeOfDay(hour: 20, minute: 0);

  String _selected = 'Plaza Roma, Intramuros';
  final _query = TextEditingController();
  bool _pinMoved = false;

  final _username = TextEditingController();
  final List<_Member> _members = [];

  late List<String> _cats;
  late List<String> _dietary;
  double _budget = 2500.0;
  String? _pace;
  final List<String> _accessibility = [];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(userPreferencesProvider);
    _cats = List.of(prefs.activityTags);
    _dietary = List.of(prefs.dietary);

    final user = ref
        .read(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    if (user != null) {
      _members.add(_Member(user.firstName, 'Leader', true));
    }
  }

  @override
  void dispose() {
    _membersPollTimer?.cancel();
    _name.dispose();
    _desc.dispose();
    _query.dispose();
    _username.dispose();
    super.dispose();
  }

  void _startPollingMembers() {
    _membersPollTimer?.cancel();
    _membersPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_createdTripId == null || !mounted || _step != 3) return;

      try {
        final updatedTrip = await ref
            .read(tripRepositoryProvider)
            .getTrip(_createdTripId!);

        if (mounted && updatedTrip.members.isNotEmpty) {
          setState(() {
            _members.clear();
            for (final m in updatedTrip.members) {
              final displayName = m.name.isNotEmpty ? m.name : m.username;
              _members.add(
                _Member(
                  displayName.isNotEmpty ? displayName : 'Member',
                  m.isLeader ? 'Leader' : 'Member',
                  true,
                ),
              );
            }
          });
        }
      } catch (_) {}
    });
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
      if (_step == 4) {
        _startPollingMembers();
      }
      setState(() => _step--);
    }
  }

  Future<void> _next() async {
    if (_step == 2 && _outOfBoundary) return;

    if (_step == 2 && _createdTrip == null) {
      setState(() => _submitting = true);

      try {
        final p = _presets.firstWhere((p) => p.$1 == _selected);
        final dto = CreateTripDto(
          code: _code,
          title: _name.text.trim().isEmpty
              ? 'New Taralets Trip'
              : _name.text.trim(),
          description: _desc.text.trim(),
          date: _date ?? DateTime.now(),
          meetupTime: _meetupTime,
          wrapUpTime: _wrapTime,
          meetupName: _selected,
          latitude: p.$2,
          longitude: p.$3,
          memberNames: _members.map((m) => m.name).toList(),
          preferences: const GroupPreferences(
            categories: [],
            budget: '₱0',
            walking: 'Not specified',
          ),
        );

        final trip = await ref.read(tripRepositoryProvider).createTrip(dto);
        _createdTrip = trip;
        _createdTripId = trip.id;
        ref.invalidate(myTripsProvider);
        _startPollingMembers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Couldn't initialize room code. Try again. Error: $e",
              ),
            ),
          );
        }
        setState(() => _submitting = false);
        return;
      }
      setState(() => _submitting = false);
    }

    if (_step == 3) {
      _membersPollTimer?.cancel();
    }

    setState(() => _step++);
  }

  Future<void> _submit() async {
    if (_submitting || _createdTripId == null) return;
    setState(() => _submitting = true);

    try {
      final preferences = GroupPreferences(
        categories: [..._cats, ..._dietary, ..._accessibility],
        budget: '₱${_budget.toInt()}',
        walking: _pace ?? 'Not specified',
      );

      await ref
          .read(tripRepositoryProvider)
          .updateGroupPreferences(_createdTripId!, preferences);

      if (mounted) {
        final trip = await ref
            .read(tripRepositoryProvider)
            .getTrip(_createdTripId!);

        ref.invalidate(myTripsProvider);
        if (mounted) {
          context.go(AppRoutes.tripCreated, extra: trip);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save final preferences. Try again."),
          ),
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
        isLoading: _submitting,
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
              hint: 'My Gala',
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
                      _date == null ? 'Select Date' : formatInputDate(_date!),
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
              hint: 'Weekend trip details...',
              controller: _desc,
              height: 70,
            ),
          ],
        ),
      ),
    ];
  }

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
              onTap: () async {
                final n = _username.text.trim();

                if (n.isEmpty) return;

                if (_createdTripId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Create the trip first before adding members.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  await ref
                      .read(tripRepositoryProvider)
                      .inviteMember(_createdTripId!, n);

                  if (!mounted) return;

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

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$n was added to the trip.')),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Unable to add $n.')));
                }
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
            if (_members.isEmpty)
              Text(
                "Share the code to start adding members.",
                style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _step4() {
    return [
      Text('What do you want to do?', style: AppText.ui(15, FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        "Modify your choices for this specific trip without altering your profile defaults.",
        style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
      ),
      const SizedBox(height: 14),

      _SectionCard(
        emoji: '🎯',
        title: 'What do you enjoy?',
        subtitle: 'Select interests for this specific trip.',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activityOptions
              .map(
                (tag) => _SelectChip(
                  emoji: _activityEmoji[tag],
                  label: tag,
                  selected: _cats.contains(tag),
                  onTap: () => setState(() {
                    if (_cats.contains(tag)) {
                      _cats.remove(tag);
                    } else {
                      _cats.add(tag);
                    }
                  }),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 16),

      _SectionCard(
        emoji: '🍽️',
        title: 'Dietary & dining',
        subtitle: 'Set dining restrictions for this trip.',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dietaryOptions
              .map(
                (d) => _SelectChip(
                  emoji: _dietaryEmoji[d],
                  label: d,
                  selected: _dietary.contains(d),
                  onTap: () => setState(() {
                    if (_dietary.contains(d)) {
                      _dietary.remove(d);
                    } else if (d == 'None') {
                      _dietary.clear();
                      _dietary.add('None');
                    } else {
                      _dietary.remove('None');
                      _dietary.add(d);
                    }
                  }),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 16),

      _SectionCard(
        emoji: '💰',
        title: 'Spending budget',
        subtitle: 'Your preferred budget for this trip.',
        child: Column(
          children: [
            Text(
              '₱${_budget.toInt()}',
              style: AppText.ui(24, FontWeight.w800, color: AppColors.orange),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _budget,
              min: 1,
              max: 10000,
              activeColor: AppColors.orange,
              inactiveColor: AppColors.orangeSoft,
              onChanged: (val) {
                setState(() {
                  _budget = val;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₱1',
                  style: AppText.ui(
                    12,
                    FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  '₱10,000',
                  style: AppText.ui(
                    12,
                    FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      _SectionCard(
        emoji: '🚶',
        title: 'Trip Pace',
        subtitle: 'How much walking is okay for the group?',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paceOptions
              .map(
                (p) => _SelectChip(
                  emoji: _paceEmoji[p],
                  label: p,
                  selected: _pace == p,
                  onTap: () => setState(() {
                    if (_pace == p) {
                      _pace = null;
                    } else {
                      _pace = p;
                    }
                  }),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 16),

      _SectionCard(
        emoji: '♿',
        title: 'Accessibility',
        subtitle: 'Any specific accessibility needs?',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _accessibilityOptions
              .map(
                (a) => _SelectChip(
                  label: a,
                  selected: _accessibility.contains(a),
                  onTap: () => setState(() {
                    if (_accessibility.contains(a)) {
                      _accessibility.remove(a);
                    } else {
                      _accessibility.add(a);
                    }
                  }),
                ),
              )
              .toList(),
        ),
      ),
    ];
  }

  List<Widget> _step5() {
    final title = _name.text.trim().isEmpty
        ? 'New Taralets Trip'
        : _name.text.trim();
    final rows = [
      ('📍', 'Meetup', _selected),
      ('⏰', 'Target Arrival', formatTimeOfDay(_meetupTime)),
      ('👥', 'Members', '${_members.length} people'),
    ];

    final combinedPrefs = [
      ..._cats,
      ..._dietary,
      '₱${_budget.toInt()}',
      ?_pace,
      ..._accessibility,
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
                  if (combinedPrefs.isEmpty)
                    Text(
                      'No specific preferences selected.',
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in combinedPrefs)
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
                              t,
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

class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.ui(
                        16,
                        FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
  });

  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.bg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: 1.5,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.orangeSoft,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: AppText.ui(
                13,
                FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy,
              ),
              child: Text(label),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: selected
                  ? const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
