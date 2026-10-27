import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/auth_repository.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/error_note.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/invite_member_sheet.dart';
import '../../../../shared/widgets/ticket_card.dart'; // IDINAGDAG: TicketCard
import '../../data/models/member.dart';

class TripLobbyScreen extends ConsumerStatefulWidget {
  const TripLobbyScreen({
    super.key,
    required this.trip,
    this.showCreatedOverlay = false,
  });

  final Trip trip;
  final bool showCreatedOverlay;

  @override
  ConsumerState<TripLobbyScreen> createState() => _TripLobbyScreenState();
}

class _WaitingForMembers extends StatelessWidget {
  const _WaitingForMembers({required this.ready, required this.total});

  final int ready;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.amberSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.hourglass_top_rounded,
          color: AppColors.amberText,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Waiting for everyone to be ready',
            style: AppText.ui(13, FontWeight.w700, color: AppColors.amberText),
          ),
        ),
        Text(
          '$ready/$total ready',
          style: AppText.ui(11, FontWeight.w800, color: AppColors.amberText),
        ),
      ],
    ),
  );
}

class _TripLobbyScreenState extends ConsumerState<TripLobbyScreen> {
  late Trip _trip = widget.trip;
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _toggling = false;
  bool _hasItinerary = false;
  bool _itineraryFinalized = false;
  bool _cancellingOrLeaving = false;
  String? _errorTitle;
  String? _errorMessage;

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshItineraryAvailability);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshTrip(),
    );

    if (widget.showCreatedOverlay) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showSuccessOverlay();
      });
    }
  }

  Future<void> _refreshItineraryAvailability() async {
    try {
      final itinerary = await _repo.getItinerary(_trip.id);
      if (!mounted) return;
      final finalized =
          itinerary['status']?.toString().toLowerCase() == 'finalized';
      if (!_hasItinerary || _itineraryFinalized != finalized) {
        setState(() {
          _hasItinerary = true;
          _itineraryFinalized = finalized;
        });
      }
    } on TripException {
      if (mounted && _hasItinerary) {
        setState(() {
          _hasItinerary = false;
          _itineraryFinalized = false;
        });
      }
    }
  }

  void _showSuccessOverlay() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "You're all set!",
                style: AppText.ui(22, FontWeight.w900, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              Text(
                "Your group trip is ready. Share the code to invite your friends.",
                textAlign: TextAlign.center,
                style: AppText.ui(
                  13,
                  FontWeight.w500,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Text(
                  _trip.code,
                  textAlign: TextAlign.center,
                  style: AppText.mono(
                    32,
                    FontWeight.w900,
                    color: AppColors.navy,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TaraletsButton.orange(
                label: 'Got it',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshTrip() async {
    if (!mounted ||
        _refreshing ||
        _toggling ||
        _cancellingOrLeaving)
      return;
    _refreshing = true;
    try {
      final latestTrip = await _repo.getTrip(_trip.id);
      if (!mounted) return;
      if (_trip.memberCount != latestTrip.memberCount ||
          _trip.readyCount != latestTrip.readyCount) {
        ref.invalidate(myTripsProvider);
      }
      setState(() => _trip = latestTrip);
      if (!_itineraryFinalized) {
        await _refreshItineraryAvailability();
      }
    } on TripException {
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.trips);

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _trip.code));
    _snack('Code copied');
  }

  void _shareInvite() {
    Clipboard.setData(
      ClipboardData(text: 'Join my Taralets trip with room code ${_trip.code}'),
    );
    _snack('Invite message copied');
  }

  Future<void> _toggleReady(AuthUser me) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      final updated = await _repo.toggleMemberStatus(_trip.id, me.id);
      if (!mounted) return;
      setState(() => _trip = updated);
      ref.invalidate(myTripsProvider);
    } on TripException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _edit() async {
    final updated = await context.push<Trip>(AppRoutes.editTrip, extra: _trip);
    if (updated != null && mounted) {
      setState(() => _trip = updated);
      _snack('Trip updated');
    }
  }

  Future<void> _invite(AuthUser me) async {
    final result = await showInviteMemberSheet(
      context,
      trip: _trip,
      myUsername: me.username,
      onInvite: (username) => _repo.inviteMember(_trip.id, username),
    );
    if (result != null && mounted) {
      setState(() => _trip = result.trip);
      ref.invalidate(myTripsProvider);
      _snack('Invite sent to @${result.username}!');
    }
  }

  Future<void> _cancelOrLeaveTrip(bool isLeader) async {
    if (_cancellingOrLeaving) return;
    final title = isLeader ? 'Cancel Trip' : 'Leave Trip';
    final content = isLeader
        ? 'Are you sure you want to cancel this trip? All members will be notified and the trip will be deleted.'
        : 'Are you sure you want to leave this trip?';
    final confirmText = isLeader ? 'Yes, Cancel' : 'Yes, Leave';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: AppText.ui(18, FontWeight.w900, color: AppColors.navy),
        ),
        content: Text(
          content,
          style: AppText.ui(
            13,
            FontWeight.w500,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'No',
              style: AppText.ui(14, FontWeight.w700, color: AppColors.navy),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              confirmText,
              style: AppText.ui(14, FontWeight.w800, color: AppColors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _cancellingOrLeaving = true);
    try {
      if (isLeader) {
        await _repo.cancelTrip(_trip.id);
      } else {
        await _repo.leaveTrip(_trip.id);
      }
      ref.invalidate(myTripsProvider);
      if (!mounted) return;
      context.go(AppRoutes.trips);
    } catch (e) {
      if (mounted) {
        _snack('Failed to process request. Please try again.');
        setState(() => _cancellingOrLeaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    final isLeader = _trip.isLeader(me?.id);
    final myMember = _trip.members.where((m) => m.id == me?.id).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                trip: _trip,
                showEdit: isLeader,
                onBack: _back,
                onEdit: _edit,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RoomCodeCard(
                      code: _trip.code,
                      onCopy: _copyCode,
                      onShare: _shareInvite,
                    ),
                    const SizedBox(height: 16),
                    _OverviewCard(trip: _trip),
                    const SizedBox(height: 16),
                    _MembersCard(trip: _trip, meId: me?.id),
                    const SizedBox(height: 16),
                    _PrefsLink(
                      onTap: () =>
                          context.push(AppRoutes.groupPrefs, extra: _trip),
                    ),
                    const SizedBox(height: 24),

                    if (_errorTitle != null) ...[
                      ErrorNote(
                        title: _errorTitle!,
                        message: _errorMessage ?? '',
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (isLeader) ...[
                      TaraletsButton.ghost(
                        label: 'Invite Member',
                        onPressed: me == null ? null : () => _invite(me),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_hasItinerary) ...[
                      TaraletsButton.orange(
                        label: 'View Itinerary',
                        onPressed: () => context.push(
                          AppRoutes.lobbyItinerary,
                          extra: {'tripId': _trip.id},
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (!_itineraryFinalized) ...[
                      if (_trip.everyoneReady)
                        TaraletsButton.orange(
                          label: 'Find Places',
                          onPressed: () {
                            context.push(
                              AppRoutes.recommendations,
                              extra: {'groupId': _trip.id},
                            );
                          },
                        )
                      else
                        _WaitingForMembers(
                          ready: _trip.readyCount,
                          total: _trip.memberCount,
                        ),
                    ],

                    if (!isLeader && myMember != null && me != null) ...[
                      const SizedBox(height: 12),
                      if (myMember.isReady)
                        TaraletsButton.ghost(
                          label: 'Mark as Not Ready',
                          onPressed: _toggling ? null : () => _toggleReady(me),
                        )
                      else
                        TaraletsButton.orange(
                          label: "I'm Ready",
                          isLoading: _toggling,
                          onPressed: _toggling ? null : () => _toggleReady(me),
                        ),
                    ],

                    if (isLeader || myMember != null) ...[
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _cancellingOrLeaving
                            ? null
                            : () => _cancelOrLeaveTrip(isLeader),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.redSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: _cancellingOrLeaving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    color: AppColors.red,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isLeader ? 'Cancel Trip' : 'Leave Trip',
                                  style: AppText.ui(
                                    14,
                                    FontWeight.w800,
                                    color: AppColors.red,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({
    required this.trip,
    required this.showEdit,
    required this.onBack,
    required this.onEdit,
  });
  final Trip trip;
  final bool showEdit;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackButtonTile(onTap: onBack),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Parehong-pareho na ng timbang at kulay sa Create Trip
                    style: AppText.ui(
                      18,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trip.dateLabel} • Target arrival ${trip.arrivalTarget}',
                    style: AppText.ui(
                      13,
                      FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showEdit)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.edit, color: AppColors.navy, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Edit',
                      style: AppText.ui(
                        12,
                        FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TICKET CARDS & SECTIONS
// ---------------------------------------------------------------------------
BoxDecoration _cardDeco() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.border),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

// BINAGO: Literal na TicketCard para sa Room Code
class _RoomCodeCard extends StatelessWidget {
  const _RoomCodeCard({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });
  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      fillColor: Colors.white,
      lineColor: AppColors.border,
      notchAxis: TicketNotchAxis.leftRight,
      notchOffset: 105,
      cornerRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ), // Rose color
                    const SizedBox(width: 8),
                    Text(
                      'TRIP INVITE CODE',
                      style: AppText.ui(
                        11,
                        FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  code,
                  style: AppText.mono(
                    36,
                    FontWeight.w900,
                    color: AppColors.navy,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: TaraletsButton.ghost(
                    label: 'Copy Code',
                    onPressed: onCopy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TaraletsButton.orange(
                    label: 'Share Invite',
                    onPressed: onShare,
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('📍', 'Destination', trip.meetupFull),
      ('🗓️', 'Date', trip.longDate),
      ('⏰', 'Schedule', '${trip.arrivalTarget} – ${trip.wrapUp}'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows) ...[
            Row(
              children: [
                Text(r.$1, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.$2.toUpperCase(),
                        style: AppText.ui(
                          10,
                          FontWeight.w800,
                          color: AppColors.muted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.$3,
                        style: AppText.ui(
                          15,
                          FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (r != rows.last || trip.description.isNotEmpty)
              const SizedBox(height: 18),
          ],
          if (trip.description.isNotEmpty) ...[
            Text(
              'ABOUT THIS TRIP',
              style: AppText.ui(
                10,
                FontWeight.w800,
                color: AppColors.muted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trip.description,
              style: AppText.ui(
                13,
                FontWeight.w500,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.trip, required this.meId});
  final Trip trip;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trip Members',
                style: AppText.ui(15, FontWeight.w900, color: AppColors.navy),
              ),
              Text(
                '${trip.readyCount}/${trip.memberCount} ready',
                style: AppText.ui(
                  13,
                  FontWeight.w800,
                  color: AppColors.primary,
                ),
              ), // Rose text
            ],
          ),
          const SizedBox(height: 16),
          for (final m in trip.members) ...[
            _MemberRow(member: m, isMe: m.id == meId),
            if (m != trip.members.last)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.isMe});
  final Member member;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final ready = member.isReady;
    return Row(
      children: [
        Avatar(name: member.name, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      isMe ? '${member.name} (You)' : member.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(
                        14,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  if (member.isLeader) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Leader',
                        style: AppText.ui(
                          10,
                          FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '@${member.username}',
                style: AppText.ui(12, FontWeight.w500, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: ready ? AppColors.greenSoft : AppColors.amberSoft,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            ready ? '✓ Ready' : 'Pending',
            style: AppText.ui(
              11,
              FontWeight.w800,
              color: ready ? AppColors.greenText : AppColors.amberText,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrefsLink extends StatelessWidget {
  const _PrefsLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDeco(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Preferences',
                    style: AppText.ui(
                      15,
                      FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'See what the group wants to do',
                    style: AppText.ui(
                      12,
                      FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 24),
          ],
        ),
      ),
    );
  }
}
