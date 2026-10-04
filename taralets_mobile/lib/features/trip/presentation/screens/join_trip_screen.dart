import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/error_note.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_card.dart';
import '../../providers/join_trip_controller.dart';

/// Full-screen Join Trip flow (no bottom bar), matching the Figma `JoinTrip`.
class JoinTripScreen extends ConsumerStatefulWidget {
  const JoinTripScreen({super.key});

  @override
  ConsumerState<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends ConsumerState<JoinTripScreen> {
  @override
  void initState() {
    super.initState();
    // Start from "enter code" every time the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(joinTripControllerProvider.notifier).backToEnter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinTripControllerProvider);

    final Widget body = switch (state.phase) {
      JoinPhase.enter => const _EnterStep(),
      JoinPhase.found => _FoundStep(state: state),
      JoinPhase.joined => _JoinedStep(trip: state.trip!),
    };

    return Scaffold(
      backgroundColor: state.phase == JoinPhase.joined
          ? Colors.white
          : AppColors.bg,
      body: SafeArea(child: body),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: enter code
// ---------------------------------------------------------------------------

class _EnterStep extends ConsumerStatefulWidget {
  const _EnterStep();

  @override
  ConsumerState<_EnterStep> createState() => _EnterStepState();
}

class _EnterStepState extends ConsumerState<_EnterStep> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _showHowItWorks = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _find() {
    FocusScope.of(context).unfocus();
    ref.read(joinTripControllerProvider.notifier).findTrip(_controller.text);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinTripControllerProvider);
    final len = _controller.text.length;
    final borderColor = (len >= 5 || _focus.hasFocus)
        ? AppColors.orange
        : AppColors.border;

    return SingleChildScrollView(
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
                'Join a Trip',
                style: AppText.ui(18, FontWeight.w800, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Hero
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('🎟', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'Have an Invite Code?',
                  style: AppText.ui(18, FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the code shared by your trip organizer to join their itinerary.',
                  textAlign: TextAlign.center,
                  style: AppText.ui(
                    13,
                    FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Code entry
          TaraletsCard(
            radius: 16,
            blur: 8,
            shadowAlpha: 0.06,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter Invite Code',
                  style: AppText.ui(13, FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _focus.hasFocus
                        ? [
                            BoxShadow(
                              color: AppColors.orange.withValues(alpha: 0.12),
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: !state.isLoading,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9-]'),
                      ),
                      const UpperCaseTextFormatter(),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    cursorColor: AppColors.orange,
                    style: AppText.mono(
                      24,
                      FontWeight.w900,
                      color: AppColors.navy,
                      letterSpacing: 3,
                    ),
                    onChanged: (_) {
                      ref
                          .read(joinTripControllerProvider.notifier)
                          .clearError();
                      setState(() {});
                    },
                    onSubmitted: (_) => _find(),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      hintText: 'e.g. TARA-88',
                      hintStyle: AppText.mono(
                        24,
                        FontWeight.w900,
                        color: AppColors.placeholder.withValues(alpha: 0.6),
                        letterSpacing: 3,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.orange,
                          width: 2,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: AppText.ui(
                      12,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                    children: [
                      const TextSpan(text: 'Tip: Try '),
                      TextSpan(
                        text: 'TARA-88',
                        style: AppText.mono(
                          12,
                          FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                      const TextSpan(text: ' to demo a trip lookup'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (state.hasError) ...[
                  const SizedBox(height: 12),
                  ErrorNote(
                    title: state.errorTitle!,
                    message: state.errorMessage!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          TaraletsButton.orange(
            label: 'Find Trip →',
            isLoading: state.isLoading,
            onPressed: _find,
          ),

          // How does the invite code work?
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _showHowItWorks = !_showHowItWorks),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcons.users(size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'How does the invite code work? ${_showHowItWorks ? '▲' : '▼'}',
                    style: AppText.ui(
                      13,
                      FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showHowItWorks) ...[
            const SizedBox(height: 8),
            const _HowItWorks(),
          ],
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      '1',
      '✏️',
      'Organizer creates a trip',
      'Sets trip name, date, meetup point, and invites members.',
    ),
    (
      '2',
      '🔑',
      'A unique code is generated',
      'After setup, a short code like TARA-88 is automatically created.',
    ),
    (
      '3',
      '📤',
      'Organizer shares the code',
      'Via chat, SMS, or the built-in Share button.',
    ),
    (
      '4',
      '✅',
      'Friend enters the code here',
      'They instantly see trip details and join with one tap.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TaraletsCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📖 How it works',
            style: AppText.ui(13, FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 12),
          for (final s in _steps)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.only(bottom: s.$1 == '4' ? 0 : 12),
              decoration: BoxDecoration(
                border: s.$1 == '4'
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(s.$2, style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.$1}. ${s.$3}',
                          style: AppText.ui(13, FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.$4,
                          style: AppText.ui(
                            12,
                            FontWeight.w400,
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ORGANIZER'S SHARE SCREEN",
                  style: AppText.ui(
                    11,
                    FontWeight.w700,
                    color: AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                TaraletsCard(
                  radius: 10,
                  blur: 4,
                  shadowAlpha: 0.06,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TRIP INVITE CODE',
                        style: AppText.ui(
                          11,
                          FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TARA-88',
                        style: AppText.mono(
                          28,
                          FontWeight.w900,
                          color: AppColors.navy,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  const ClipboardData(text: 'TARA-88'),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Code copied')),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(9),
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
                                  '📋 Copy',
                                  style: AppText.ui(12, FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '📤 Share',
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
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: trip found
// ---------------------------------------------------------------------------

class _FoundStep extends ConsumerWidget {
  const _FoundStep({required this.state});
  final JoinTripState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = state.trip!;
    final ctrl = ref.read(joinTripControllerProvider.notifier);

    final rows = [
      ('📍', 'Meetup', trip.meetupFull),
      ('⏰', 'Arrival Target', trip.arrivalTarget),
      (
        '👥',
        'Members',
        '${trip.memberCount} going (${trip.spotsOpen} spot${trip.spotsOpen == 1 ? '' : 's'} open)',
      ),
      ('🗓', 'Date', trip.dateLabel.replaceFirst('Aug', 'August')),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BackButtonTile(onTap: ctrl.backToEnter),
              const SizedBox(width: 12),
              Text(
                'Trip Found!',
                style: AppText.ui(18, FontWeight.w800, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: AppColors.navy,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TRIP FOUND',
                            style: AppText.ui(
                              10,
                              FontWeight.w700,
                              color: AppColors.green,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trip.title,
                        style: AppText.ui(
                          18,
                          FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip.longDate,
                        style: AppText.ui(
                          13,
                          FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in rows) ...[
                        Row(
                          children: [
                            Text(r.$1, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
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
                                  Text(
                                    r.$3,
                                    style: AppText.ui(13, FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'TRIP MEMBERS',
                              style: AppText.ui(
                                11,
                                FontWeight.w400,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                AvatarStack(
                                  names: trip.memberNames,
                                  size: 30,
                                  ringColor: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Led by ${trip.leader}',
                                  style: AppText.ui(
                                    12,
                                    FontWeight.w400,
                                    color: AppColors.muted,
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          TaraletsButton.orange(
            label: 'Join This Trip →',
            isLoading: state.isLoading,
            onPressed: ctrl.confirmJoin,
          ),
          const SizedBox(height: 10),
          TaraletsButton.ghost(label: 'Cancel', onPressed: ctrl.backToEnter),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: joined
// ---------------------------------------------------------------------------

class _JoinedStep extends StatelessWidget {
  const _JoinedStep({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 16),
            Text(
              "You're in!",
              textAlign: TextAlign.center,
              style: AppText.ui(24, FontWeight.w900, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                style: AppText.ui(14, FontWeight.w400, color: AppColors.muted),
                children: [
                  const TextSpan(text: "You've joined "),
                  TextSpan(
                    text: trip.title,
                    style: AppText.ui(
                      14,
                      FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.title,
                          style: AppText.ui(
                            14,
                            FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${trip.dateLabel.replaceFirst('Today, ', '')} • ${trip.meetup} • ${trip.memberCount} members',
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
            ),
            const SizedBox(height: 16),
            Center(
              child: AvatarStack(
                names: trip.memberNames,
                size: 32,
                ringColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TaraletsButton.orange(
              label: 'View Trip Details →',
              onPressed: () => context.go(AppRoutes.trips),
            ),
            const SizedBox(height: 16),
            TaraletsButton.ghost(
              label: 'Back to Home',
              onPressed: () => context.go(AppRoutes.home),
            ),
          ],
        ),
      ),
    );
  }
}
