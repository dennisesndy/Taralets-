import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_card.dart';

class _Item {
  const _Item({
    required this.id,
    required this.time,
    required this.end,
    required this.name,
    required this.icon,
    required this.cat,
    required this.walk,
    required this.budget,
  });

  final int id;
  final String time, end, name, icon, cat, walk, budget;

  _Item copyWith({String? name, String? icon}) => _Item(
    id: id,
    time: time,
    end: end,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    cat: cat,
    walk: walk,
    budget: budget,
  );
}

class _Alt {
  const _Alt(this.name, this.icon, this.dist, this.match, this.budget);
  final String name, icon, dist, match, budget;
}

/// Mock itinerary: all stops are in the City of Manila (from Figma).
const _initial = [
  _Item(
    id: 1,
    time: '2:30 PM',
    end: '2:45 PM',
    name: 'Plaza Roma',
    icon: '📍',
    cat: 'Meetup',
    walk: '',
    budget: 'Free',
  ),
  _Item(
    id: 2,
    time: '2:45 PM',
    end: '3:45 PM',
    name: 'Fort Santiago',
    icon: '🏛',
    cat: 'Heritage',
    walk: '10 min walk · Free',
    budget: '₱75',
  ),
  _Item(
    id: 3,
    time: '4:00 PM',
    end: '4:45 PM',
    name: 'San Agustin Church',
    icon: '⛪',
    cat: 'Heritage',
    walk: '9 min walk · Free',
    budget: 'Free',
  ),
  _Item(
    id: 4,
    time: '5:15 PM',
    end: '6:30 PM',
    name: 'Binondo Food Crawl',
    icon: '🍜',
    cat: 'Food',
    walk: '24 min travel · ₱13–₱20',
    budget: '₱350',
  ),
  _Item(
    id: 5,
    time: '7:00 PM',
    end: '8:00 PM',
    name: 'Manila Baywalk',
    icon: '🌅',
    cat: 'Leisure',
    walk: '26 min travel · ₱15–₱20',
    budget: 'Free',
  ),
];

const _alternatives = <int, List<_Alt>>{
  2: [
    _Alt('Casa Manila', '🏠', '5 min', '85%', '₱60'),
    _Alt('Baluarte de San Diego', '🏰', '8 min', '78%', 'Free'),
    _Alt('National Museum', '🏛', '15 min', '82%', '₱50'),
  ],
  3: [
    _Alt('Rizal Shrine', '⛩', '10 min', '80%', 'Free'),
    _Alt('Manila Cathedral', '⛪', '3 min', '76%', 'Free'),
  ],
};

class _Cluster {
  const _Cluster(this.label, this.color, this.bg, this.items);
  final String label;
  final Color color, bg;
  final List<int> items;
}

const _clusters = [
  _Cluster('Explore: Intramuros Area', AppColors.orange, AppColors.orangeSoft, [
    1,
    2,
    3,
  ]),
  _Cluster('Explore: Binondo Food Scene', AppColors.navy, AppColors.blueSoft, [
    4,
  ]),
  _Cluster('Explore: Manila Baywalk', AppColors.green, AppColors.greenSoft, [
    5,
  ]),
];

const _blocks = [
  ('Afternoon Block', '2:30 PM – 5:00 PM', '☀️', [1, 2, 3]),
  ('Evening Block', '5:00 PM – 8:00 PM', '🌆', [4, 5]),
];

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  List<_Item> _items = List.of(_initial);
  int? _swapTarget;
  bool _confirmed = false;
  bool _cluster = false;
  final Map<String, bool> _reviewed = {
    'Dennise': true,
    'Ana': true,
    'Paola': true,
    'Jewelle': false,
  };

  bool get _allConfirmed => _reviewed.values.every((v) => v);

  void _move(int idx, int delta) {
    final to = idx + delta;
    if (to < 1 || to >= _items.length) return;
    setState(() {
      final a = List.of(_items);
      final t = a[idx];
      a[idx] = a[to];
      a[to] = t;
      _items = a;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: AppColors.navy,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Itinerary',
                    style: AppText.ui(17, FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Intramuros & Binondo Day Out',
                    style: AppText.ui(
                      13,
                      FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text('🕑', style: TextStyle(fontSize: 13)),
                        Text(
                          'Trip Schedule: 2:30 PM – 8:00 PM',
                          style: AppText.ui(
                            12,
                            FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '5.5 hrs total',
                            style: AppText.ui(
                              11,
                              FontWeight.w600,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // View toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _Toggle(
                    label: '📅 Timeline',
                    on: !_cluster,
                    left: true,
                    onTap: () => setState(() => _cluster = false),
                  ),
                  _Toggle(
                    label: '🗺 Nearby Spots',
                    on: _cluster,
                    left: false,
                    onTap: () => setState(() => _cluster = true),
                  ),
                ],
              ),
            ),

            if (_cluster) _clusterView() else _timeline(),
          ],
        ),
      ),
    );
  }

  Widget _clusterView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          for (final z in _clusters) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: z.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: z.color.withValues(alpha: 0.125)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: z.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        z.label,
                        style: AppText.ui(12, FontWeight.w800, color: z.color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final i in _items.where(
                        (i) => z.items.contains(i.id),
                      ))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: z.color.withValues(alpha: 0.19),
                            ),
                          ),
                          child: Text(
                            '${i.icon} ${i.name} · ${i.time}',
                            style: AppText.ui(11, FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _timeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in _blocks)
            if (_items.any((i) => b.$4.contains(i.id))) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Row(
                  children: [
                    Text(b.$3, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.$1,
                          style: AppText.ui(
                            12,
                            FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          b.$2,
                          style: AppText.mono(
                            10,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(height: 1, color: AppColors.border),
                    ),
                  ],
                ),
              ),
              for (final item in _items.where((i) => b.$4.contains(i.id)))
                _stop(item),
              const SizedBox(height: 10),
            ],

          // Wrap-up
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🏠', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wrap-Up & Head Home',
                        style: AppText.ui(
                          13,
                          FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '8:00 PM — Trip completed · Return commute guide ready.',
                        style: AppText.ui(
                          11,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '8:00 PM',
                  style: AppText.mono(
                    12,
                    FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          // Group review
          const SizedBox(height: 6),
          TaraletsCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Final Itinerary — Group Review',
                  style: AppText.ui(13, FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (final e in _reviewed.entries) ...[
                  Row(
                    children: [
                      Avatar(name: e.key, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.key,
                          style: AppText.ui(13, FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _reviewed[e.key] = !e.value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: e.value
                                ? AppColors.greenSoft
                                : AppColors.amberSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            e.value ? '✓ Reviewed' : '⏳ Pending',
                            style: AppText.ui(
                              11,
                              FontWeight.w700,
                              color: e.value
                                  ? AppColors.greenText
                                  : AppColors.amberText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                if (!_confirmed)
                  TaraletsButton.orange(
                    label: _allConfirmed
                        ? '🔒 Confirm Final Itinerary'
                        : 'Waiting... ${_reviewed.values.where((v) => v).length}/4 confirmed',
                    onPressed: () {
                      if (_allConfirmed) setState(() => _confirmed = true);
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('🔒', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(
                          'Itinerary Confirmed!',
                          style: AppText.ui(
                            14,
                            FontWeight.w800,
                            color: AppColors.greenText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your group plan is ready for trip day.',
                          style: AppText.ui(
                            12,
                            FontWeight.w400,
                            color: AppColors.greenDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stop(_Item item) {
    final idx = _items.indexOf(item);
    final meetup = item.cat == 'Meetup';
    final dot = meetup ? AppColors.navy : AppColors.orange;
    final cluster = _clusters
        .where((z) => z.items.contains(item.id))
        .firstOrNull;
    final alts = _alternatives[item.id];
    final swapping = _swapTarget == item.id;

    Widget small(String label, Color fg, VoidCallback onTap, {Color? bg}) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bg ?? Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppText.ui(11, FontWeight.w600, color: fg),
              ),
            ),
          ),
        );

    Widget arrow(String t, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          t,
          style: const TextStyle(fontSize: 12, color: Colors.black),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (idx > 0 && item.walk.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 0, 4),
            child: Row(
              children: [
                Container(
                  width: 1,
                  height: 16,
                  margin: const EdgeInsets.only(left: 8),
                  color: AppColors.border,
                ),
                const SizedBox(width: 8),
                Text(
                  item.walk,
                  style: AppText.ui(
                    11,
                    FontWeight.w400,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  border: Border.all(color: dot, width: 2),
                ),
                alignment: Alignment.center,
                child: meetup
                    ? null
                    : Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: AppText.ui(14, FontWeight.w700),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${item.time} – ${item.end}',
                                style: AppText.ui(
                                  11,
                                  FontWeight.w400,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (idx > 1) ...[
                          arrow('↑', () => _move(idx, -1)),
                          arrow('↓', () => _move(idx, 1)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orangeSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            item.cat,
                            style: AppText.ui(
                              11,
                              FontWeight.w600,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                        Text(
                          item.budget,
                          style: AppText.ui(
                            12,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                        if (cluster != null && !meetup)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cluster.bg,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: cluster.color.withValues(alpha: 0.19),
                              ),
                            ),
                            child: Text(
                              cluster.label,
                              style: AppText.ui(
                                10,
                                FontWeight.w700,
                                color: cluster.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.id != 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (alts != null) ...[
                            small(
                              '⇄ Swap',
                              swapping
                                  ? const Color(0xFF4F46E5)
                                  : AppColors.text,
                              () => setState(
                                () => _swapTarget = swapping ? null : item.id,
                              ),
                              bg: swapping ? const Color(0xFFEEF2FF) : null,
                            ),
                            const SizedBox(width: 6),
                          ],
                          small('× Remove', AppColors.red, () {
                            setState(
                              () => _items = _items
                                  .where((x) => x.id != item.id)
                                  .toList(),
                            );
                          }),
                          const SizedBox(width: 6),
                          small('Details', AppColors.muted, () {}),
                        ],
                      ),
                    ],
                    if (swapping && alts != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replace ${item.name}',
                              style: AppText.ui(12, FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            for (final a in alts) ...[
                              GestureDetector(
                                onTap: () => setState(() {
                                  _items = [
                                    for (final x in _items)
                                      x.id == item.id
                                          ? x.copyWith(
                                              name: a.name,
                                              icon: a.icon,
                                            )
                                          : x,
                                  ];
                                  _swapTarget = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        a.icon,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              a.name,
                                              style: AppText.ui(
                                                12,
                                                FontWeight.w700,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  a.dist,
                                                  style: AppText.ui(
                                                    10,
                                                    FontWeight.w400,
                                                    color: AppColors.muted,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${a.match} match',
                                                  style: AppText.ui(
                                                    10,
                                                    FontWeight.w400,
                                                    color: AppColors.green,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  a.budget,
                                                  style: AppText.ui(
                                                    10,
                                                    FontWeight.w400,
                                                    color: AppColors.muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Select',
                                        style: AppText.ui(
                                          11,
                                          FontWeight.w700,
                                          color: AppColors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.on,
    required this.left,
    required this.onTap,
  });

  final String label;
  final bool on;
  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.horizontal(
      left: left ? const Radius.circular(10) : Radius.zero,
      right: left ? Radius.zero : const Radius.circular(10),
    );
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: on ? AppColors.orangeSoft : Colors.white,
            borderRadius: r,
            border: Border(
              top: BorderSide(
                color: on ? AppColors.orange : AppColors.border,
                width: 1.5,
              ),
              bottom: BorderSide(
                color: on ? AppColors.orange : AppColors.border,
                width: 1.5,
              ),
              left: BorderSide(
                color: on ? AppColors.orange : AppColors.border,
                width: 1.5,
              ),
              right: left
                  ? BorderSide.none
                  : BorderSide(
                      color: on ? AppColors.orange : AppColors.border,
                      width: 1.5,
                    ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.ui(
              12,
              FontWeight.w700,
              color: on ? AppColors.orange : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
