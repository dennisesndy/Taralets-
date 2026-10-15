import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/ticket_card.dart';

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
    // Gagamitin natin ang primary (Rose) instead of generic orange
    final borderColor = (len >= 5 || _focus.hasFocus)
        ? AppColors.primary
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
                style: AppText.ui(18, FontWeight.w900, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // TICKET CARD PARA SA CODE ENTRY
          TicketCard(
            fillColor: Colors.white,
            lineColor: AppColors.border,
            notchAxis: TicketNotchAxis.leftRight,
            notchOffset: 165, // Sakto bago mag text field
            cornerRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- UPPER TICKET: Instructions ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.airplane_ticket_outlined,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Have an Invite Code?',
                        style: AppText.ui(20, FontWeight.w900, color: AppColors.navy),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter the room code shared by the organizer to access the itinerary.',
                        textAlign: TextAlign.center,
                        style: AppText.ui(13, FontWeight.w500, color: AppColors.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),

                // --- LOWER TICKET: Input Field ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _focus.hasFocus
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    spreadRadius: 4,
                                    blurRadius: 12,
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
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                            const UpperCaseTextFormatter(),
                            LengthLimitingTextInputFormatter(12),
                          ],
                          cursorColor: AppColors.primary,
                          style: AppText.mono(
                            26,
                            FontWeight.w900,
                            color: AppColors.navy,
                            letterSpacing: 4,
                          ),
                          onChanged: (_) {
                            ref.read(joinTripControllerProvider.notifier).clearError();
                            setState(() {});
                          },
                          onSubmitted: (_) => _find(),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.bg, // Clean off-white inner bg
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            hintText: 'TARA-88',
                            hintStyle: AppText.mono(
                              26,
                              FontWeight.w900,
                              color: AppColors.placeholder.withValues(alpha: 0.5),
                              letterSpacing: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: borderColor, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: borderColor, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: borderColor, width: 2),
                            ),
                          ),
                        ),
                      ),
                      if (state.hasError) ...[
                        const SizedBox(height: 16),
                        ErrorNote(
                          title: state.errorTitle!,
                          message: state.errorMessage!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          TaraletsButton.orange(
            label: 'Search Trip',
            icon: const Icon(Icons.search_rounded, size: 20, color: Colors.white),
            isLoading: state.isLoading,
            onPressed: _find,
          ),
          
          const SizedBox(height: 24),
          
          // Cleaned up "How it works" section
          GestureDetector(
            onTap: () => setState(() => _showHowItWorks = !_showHowItWorks),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcons.users(color: AppColors.navy, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'How does the invite code work?',
                    style: AppText.ui(13, FontWeight.w700, color: AppColors.navy),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showHowItWorks ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.navy,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showHowItWorks) ...[
            const SizedBox(height: 12),
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
      '🧍',
      'Organizer creates a trip',
      'Sets trip name, date, meetup point, and invites members.',
    ),
    (
      '2',
      '🎟️',
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
      '📲',
      'Friend enters the code here',
      'They instantly see trip details and join with one tap.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in _steps)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.only(bottom: s.$1 == '4' ? 0 : 16),
              decoration: BoxDecoration(
                border: s.$1 == '4'
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(s.$2, style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.$1}. ${s.$3}',
                          style: AppText.ui(14, FontWeight.w800, color: AppColors.navy),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.$4,
                          style: AppText.ui(12, FontWeight.w500, color: AppColors.muted, height: 1.5),
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
      (' ', 'Destination', trip.meetupFull),
      (' ', 'Date', trip.dateLabel.replaceFirst('Aug', 'August')),
      (' ', 'Arrival Target', trip.arrivalTarget),
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
                style: AppText.ui(18, FontWeight.w900, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // THE BOARDING PASS TICKET CARD
          TicketCard(
            fillColor: Colors.white,
            lineColor: AppColors.border,
            notchAxis: TicketNotchAxis.leftRight,
            notchOffset: 130, // Dito mapupunta ang "punit" ng ticket
            cornerRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- UPPER TICKET (Header) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.greenText, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'MATCH FOUND',
                              style: AppText.ui(11, FontWeight.w800, color: AppColors.greenText, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        trip.title,
                        textAlign: TextAlign.center,
                        style: AppText.ui(22, FontWeight.w900, color: AppColors.navy),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Organized by ${trip.leader}',
                        textAlign: TextAlign.center,
                        style: AppText.ui(13, FontWeight.w600, color: AppColors.primary), // Rose color
                      ),
                    ],
                  ),
                ),

                // --- LOWER TICKET (Details) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in rows) ...[
                        Row(
                          children: [
                            Text(r.$1, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.$2.toUpperCase(),
                                    style: AppText.ui(10, FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.$3,
                                    style: AppText.ui(15, FontWeight.w700, color: AppColors.navy),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // MEMBERS SECTION
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bg, // Clean off-white
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            AvatarStack(
                              names: trip.memberNames,
                              size: 32,
                              ringColor: AppColors.bg,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TRIP MEMBERS',
                                    style: AppText.ui(10, FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${trip.memberCount} going',
                                    style: AppText.ui(14, FontWeight.w800, color: AppColors.navy),
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
              ],
            ),
          ),
          const SizedBox(height: 24),
          TaraletsButton.orange(
            label: 'Join This Trip',
            isLoading: state.isLoading,
            onPressed: () async {
              await ctrl.confirmJoin();
              if (!context.mounted) return;
              final currentState = ref.read(joinTripControllerProvider);
              if (currentState.phase == JoinPhase.joined) {
                context.go(
                  AppRoutes.tripPreferences,
                  extra: {
                    'tripId': currentState.trip!.id,
                    'returnRoute': AppRoutes.trips,
                  },
                );
              }
            },
          ),
          const SizedBox(height: 12),
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
                          '${trip.dateLabel.replaceFirst('Today, ', '')} • ${trip.meetup} •${trip.memberCount} members',
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
