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
import '../../data/models/member.dart';

/// Group Lobby: the hub the group sees before the leader starts the trip.
///
/// Leader: Edit (header), Invite Member, Start Trip (needs everyone ready).
/// Members: toggle their own Ready state.
class TripLobbyScreen extends ConsumerStatefulWidget {
  const TripLobbyScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripLobbyScreen> createState() => _TripLobbyScreenState();
}

class _TripLobbyScreenState extends ConsumerState<TripLobbyScreen> {
  late Trip _trip = widget.trip;

  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _toggling = false;
  bool _starting = false;
  bool _cancellingOrLeaving = false; 
  String? _errorTitle;
  String? _errorMessage;

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  @override
  void initState() {
    super.initState();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshTrip(),
    );
  }

  Future<void> _refreshTrip() async {
    if (!mounted || _refreshing || _toggling || _starting || _cancellingOrLeaving) return;

    _refreshing = true;

    try {
      final latestTrip = await _repo.getTrip(_trip.id);

      if (!mounted) return;

      setState(() {
        _trip = latestTrip;
      });
    } on TripException {
      // Keep the current trip data if a refresh temporarily fails.
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

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _errorTitle = null;
      _errorMessage = null;
    });
    try {
      final started = await _repo.startTrip(_trip.id);
      ref.invalidate(myTripsProvider);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.activeTrip, extra: started);
    } on TripException catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _errorTitle = e.title;
          _errorMessage = e.message;
        });
      }
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
        title: Text(title, style: AppText.ui(18, FontWeight.w800)),
        content: Text(
          content,
          style: AppText.ui(14, FontWeight.w400, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('No', style: AppText.ui(14, FontWeight.w600, color: AppColors.navy)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirmText, style: AppText.ui(14, FontWeight.w700, color: AppColors.red)),
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
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RoomCodeCard(
                      code: _trip.code,
                      onCopy: _copyCode,
                      onShare: _shareInvite,
                    ),
                    const SizedBox(height: 14),
                    _OverviewCard(trip: _trip),
                    const SizedBox(height: 14),
                    _MembersCard(trip: _trip, meId: me?.id),
                    const SizedBox(height: 14),
                    _PrefsLink(
                      onTap: () =>
                          context.push(AppRoutes.groupPrefs, extra: _trip),
                    ),
                    const SizedBox(height: 16),
                    if (_errorTitle != null) ...[
                      ErrorNote(
                        title: _errorTitle!,
                        message: _errorMessage ?? '',
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (isLeader) ...[
                      TaraletsButton.ghost(
                        label: 'Invite Member',
                        onPressed: me == null ? null : () => _invite(me),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_trip.everyoneReady) ...[
                      TaraletsButton.orange(
                        label: 'Find Places →',
                        onPressed: () {
                          context.push(
                            AppRoutes.recommendations,
                            extra: {'groupId': widget.trip.id}, // Ito ang idinagdag natin
                          );
                        },
                      ),
                    ] else if (isLeader) ...[
                      TaraletsButton.ghost(
                        label:
                            'Waiting... ${_trip.readyCount}/${_trip.memberCount} ready',
                        onPressed: null,
                      ),
                      const SizedBox(height: 10),
                      TaraletsButton.orange(
                        label: 'Start Trip',
                        isLoading: _starting,
                        onPressed: _starting ? null : _start,
                      ),
                    ] else ...[
                      TaraletsButton.orange(
                        label:
                            'Waiting... ${_trip.readyCount}/${_trip.memberCount} ready',
                        onPressed: null,
                      ),
                    ],
                    if (!isLeader && myMember != null && me != null) ...[
                      const SizedBox(height: 10),
                      if (myMember.isReady)
                        TaraletsButton.ghost(
                          label: 'Mark as Not Ready',
                          onPressed: _toggling ? null : () => _toggleReady(me),
                        )
                      else
                        TaraletsButton.orange(
                          label: "I'm Ready ✓",
                          isLoading: _toggling,
                          onPressed: _toggling ? null : () => _toggleReady(me),
                        ),
                    ],
                    
                    // BUTTON PARA SA CANCEL/LEAVE DEPENDE KUNG SINO KA
                    if (isLeader || myMember != null) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _cancellingOrLeaving ? null : () => _cancelOrLeaveTrip(isLeader),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.redSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
                          ),
                          child: _cancellingOrLeaving 
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2))
                              : Text(isLeader ? 'Cancel Trip' : 'Leave Trip', style: AppText.ui(14, FontWeight.w700, color: AppColors.red)),
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
// Header (navy, same as Figma Active Trip header)
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
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BackButtonTile(onTap: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(
                        17,
                        FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.dateLabel} • Target arrival ${trip.arrivalTarget}',
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              // Leader-only edit button (same pill as the Profile "Edit").
              if (showEdit)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.edit, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: AppText.ui(
                            12,
                            FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AppIcons.pin(color: AppColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meetup Location',
                        style: AppText.ui(
                          12,
                          FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        trip.meetupFull,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          14,
                          FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Group',
                      style: AppText.ui(
                        11,
                        FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${trip.readyCount}/${trip.memberCount} ready',
                      style: AppText.ui(
                        14,
                        FontWeight.w700,
                        color: AppColors.gold,
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

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

BoxDecoration _cardDeco() => BoxDecoration(
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  code,
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
                  onPressed: onCopy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TaraletsButton.orange(
                  label: 'Share Invite',
                  onPressed: onShare,
                ),
              ),
            ],
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
      ('🗓', 'Date', trip.longDate),
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
                ),
              ],
            ),
            if (r != rows.last || trip.description.isNotEmpty)
              const SizedBox(height: 14),
          ],
          if (trip.description.isNotEmpty) ...[
            Text(
              'ABOUT',
              style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              trip.description,
              style: AppText.ui(
                13,
                FontWeight.w400,
                color: AppColors.muted,
                height: 1.6,
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
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Trip Members', style: AppText.ui(13, FontWeight.w700)),
              Text(
                '${trip.readyCount}/${trip.memberCount} ready',
                style: AppText.ui(12, FontWeight.w700, color: AppColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final m in trip.members) ...[
            _MemberRow(member: m, isMe: m.id == meId),
            if (m != trip.members.last) const SizedBox(height: 10),
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
        Avatar(name: member.name, size: 38),
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
                      style: AppText.ui(14, FontWeight.w700),
                    ),
                  ),
                  if (member.isLeader) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Leader',
                        style: AppText.ui(
                          10,
                          FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                '@${member.username}',
                style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: ready ? AppColors.greenSoft : AppColors.amberSoft,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            ready ? '✓ Ready' : '⏳ Not Ready',
            style: AppText.ui(
              11,
              FontWeight.w700,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _cardDeco(),
        child: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Preferences',
                    style: AppText.ui(14, FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'See what the group wants to do',
                    style: AppText.ui(
                      11,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            AppIcons.chevronRight(),
          ],
        ),
      ),
    );
  }
}