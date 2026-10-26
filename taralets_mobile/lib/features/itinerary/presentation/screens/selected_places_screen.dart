import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_card.dart';
import '../../data/itinerary_api_mapper.dart';
import '../../data/models/itinerary_draft_models.dart';
import '../controllers/itinerary_draft_controller.dart';

class SelectedPlacesScreen extends ConsumerStatefulWidget {
  const SelectedPlacesScreen({
    super.key,
    this.draft,
    this.tripId,
  });

  /// Shared with Group Recommendations so added places and votes survive
  /// navigation between the two screens.
  final ItineraryDraftController? draft;

  /// Actual trip that owns the selected places.
  final String? tripId;

  @override
  ConsumerState<SelectedPlacesScreen> createState() =>
      _SelectedPlacesScreenState();
}

class _SelectedPlacesScreenState
    extends ConsumerState<SelectedPlacesScreen> {
  late final ItineraryDraftController _draft;
  late final bool _ownsDraft;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _ownsDraft = widget.draft == null;
    _draft = widget.draft ??
        ItineraryDraftController(tripId: widget.tripId);
  }

  @override
  void dispose() {
    if (_ownsDraft) _draft.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.trips);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _generateItinerary() async {
    if (_generating) return;

    final tripId = (widget.tripId?.trim().isNotEmpty ?? false)
        ? widget.tripId!.trim()
        : _draft.tripId;

    if (tripId == null || tripId.trim().isEmpty) {
      _showMessage(
        'Missing trip context. Go back to Group Recommendations and try again.',
      );
      return;
    }

    final placeIds = <String>[];

    for (final candidate in _draft.selected) {
      if (!_draft.makesTheCut(candidate)) continue;

      final backendId = candidate.backendId.trim();
      if (backendId.isEmpty) {
        _showMessage(
          'Could not identify one of the selected places. Refresh '
          'recommendations and try again.',
        );
        return;
      }

      placeIds.add(backendId);
    }

    if (placeIds.isEmpty) {
      _showMessage('Vote on at least one place first.');
      return;
    }

    setState(() => _generating = true);

    try {
      final data = await ref
          .read(tripRepositoryProvider)
          .generateItinerary(tripId, placeIds);
      final plan = itineraryPlanFromApi(data);

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      context.go(AppRoutes.itinerary, extra: plan);
    } on TripException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (error, stackTrace) {
      debugPrint('ITINERARY GENERATION ERROR: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        _showMessage(
          'Could not generate the itinerary. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to recommendations',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Places',
              style: AppText.ui(17, FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 1),
            Text(
              'Vote before the final itinerary',
              style: AppText.ui(
                10.5,
                FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  'Step 2 of 3',
                  style: AppText.ui(
                    10,
                    FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _draft,
        builder: (context, _) {
          final selected = _draft.selected;

          if (selected.isEmpty) {
            return _EmptySelectedState(onBack: _back);
          }

          return Column(
            children: [
              Expanded(
                child: IgnorePointer(
                  ignoring: _generating,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    children: [
                      _VotingSummary(draft: _draft),
                      const SizedBox(height: 14),
                      for (final candidate in selected) ...[
                        _SelectedPlaceCard(
                          candidate: candidate,
                          draft: _draft,
                          onRemove: () {
                            HapticFeedback.selectionClick();
                            _draft.remove(candidate.id);
                          },
                          onVote: () {
                            HapticFeedback.selectionClick();
                            _draft.toggleCurrentUserVote(candidate.id);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              _GenerateBar(
                draft: _draft,
                isLoading: _generating,
                onGenerate: !_generating && _draft.canGenerate
                    ? _generateItinerary
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

class _VotingSummary extends StatelessWidget {
  const _VotingSummary({required this.draft});

  final ItineraryDraftController draft;

  @override
  Widget build(BuildContext context) {
    final selected = draft.selected;
    final voted = draft.currentUserVoteCount;
    final total = selected.length;
    final progress = total == 0 ? 0.0 : (voted / total).clamp(0.0, 1.0);

    return TaraletsCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppColors.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.how_to_vote_rounded,
                  size: 21,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Group voting is open',
                      style: AppText.ui(15, FontWeight.w800,
                          color: AppColors.navy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Places with ${draft.requiredVotes}+ votes make the '
                      'final cut. Vote for your favorites.',
                      style: AppText.ui(
                        11.5,
                        FontWeight.w500,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _VoteProgressPill(voted: voted, total: total),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AvatarStack(
                names: draft.members.map((member) => member.name).toList(),
                size: 25,
                ringColor: Colors.white,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${draft.memberCount} members · '
                  '$voted of $total of your votes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(
                    10.5,
                    FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteProgressPill extends StatelessWidget {
  const _VoteProgressPill({required this.voted, required this.total});

  final int voted;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = voted == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: complete ? AppColors.greenSoft : AppColors.blueSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$voted/$total',
        style: AppText.ui(
          10.5,
          FontWeight.w800,
          color: complete ? AppColors.greenText : AppColors.navy,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selected place card
// ---------------------------------------------------------------------------

class _SelectedPlaceCard extends StatelessWidget {
  const _SelectedPlaceCard({
    required this.candidate,
    required this.draft,
    required this.onRemove,
    required this.onVote,
  });

  final ItineraryCandidate candidate;
  final ItineraryDraftController draft;
  final VoidCallback onRemove;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final votes = draft.votesFor(candidate.id);
    final voteCount = votes.length;
    final voted = draft.currentUserVoted(candidate.id);
    final makesCut = voteCount >= draft.requiredVotes;
    final remaining = draft.requiredVotes - voteCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlaceThumb(candidate: candidate),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(15, FontWeight.w800,
                            color: AppColors.navy, height: 1.25),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        candidate.locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(11.5, FontWeight.w500,
                            color: AppColors.muted),
                      ),
                      if (candidate.address.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                candidate.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.ui(
                                  10.5,
                                  FontWeight.w400,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Tooltip(
                    message: 'Remove from selection',
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (candidate.activityTags.isNotEmpty ||
                candidate.dietaryTags.isNotEmpty ||
                candidate.accessibilityTags.isNotEmpty) ...[
              const SizedBox(height: 11),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final tag in candidate.activityTags.take(3))
                    _MiniTag(
                      label: tag,
                      color: AppColors.primary,
                      bg: AppColors.primarySoft,
                      icon: Icons.local_activity_outlined,
                    ),
                  for (final tag in candidate.dietaryTags.take(1))
                    _MiniTag(
                      label: tag,
                      color: AppColors.greenText,
                      bg: AppColors.greenSoft,
                      icon: Icons.restaurant_outlined,
                    ),
                  for (final tag in candidate.accessibilityTags.take(1))
                    _MiniTag(
                      label: tag,
                      color: AppColors.indigo,
                      bg: AppColors.blueSoft,
                      icon: Icons.accessible_rounded,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (votes.isNotEmpty)
                            AvatarStack(
                              names: votes.toList(),
                              size: 22,
                              ringColor: Colors.white,
                            )
                          else
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 13,
                                color: AppColors.muted,
                              ),
                            ),
                          const SizedBox(width: 7),
                          Text(
                            '$voteCount/${draft.memberCount} votes',
                            style: AppText.ui(
                              10.5,
                              FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        makesCut
                            ? 'Makes the final cut'
                            : 'Needs $remaining more '
                                  '${remaining == 1 ? 'vote' : 'votes'}',
                        style: AppText.ui(
                          10,
                          FontWeight.w600,
                          color: makesCut
                              ? AppColors.greenText
                              : AppColors.amberText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _VoteButton(voted: voted, onTap: onVote),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceThumb extends StatelessWidget {
  const _PlaceThumb({required this.candidate});

  final ItineraryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        candidate.icon,
        style: const TextStyle(fontSize: 25),
      ),
    );

    if (!(candidate.imageUrl.startsWith('http://') ||
        candidate.imageUrl.startsWith('https://'))) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            fallback,
            Image.network(
              candidate.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color bg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppText.ui(9.5, FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.voted, required this.onTap});

  final bool voted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: voted ? AppColors.greenSoft : null,
          gradient: voted
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
          borderRadius: BorderRadius.circular(10),
          border: voted
              ? Border.all(
                  color: AppColors.green.withValues(alpha: 0.25),
                )
              : null,
          boxShadow: voted
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              voted
                  ? Icons.check_circle_rounded
                  : Icons.how_to_vote_rounded,
              size: 14,
              color: voted ? AppColors.greenText : Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              voted ? 'Voted' : 'Vote',
              style: AppText.ui(
                11.5,
                FontWeight.w800,
                color: voted ? AppColors.greenText : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generate bar / empty state
// ---------------------------------------------------------------------------

class _GenerateBar extends StatelessWidget {
  const _GenerateBar({
    required this.draft,
    required this.onGenerate,
    this.isLoading = false,
  });

  final ItineraryDraftController draft;
  final VoidCallback? onGenerate;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final voted = draft.currentUserVoteCount;
    final total = draft.selected.length;
    final ready = onGenerate != null || isLoading;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.border),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your votes: $voted/$total',
                    style: AppText.ui(12, FontWeight.w800,
                        color: AppColors.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLoading
                        ? 'Building the real itinerary…'
                        : ready
                        ? 'Ready to generate the final plan'
                        : 'Vote on at least one place',
                    style: AppText.ui(
                      10.5,
                      FontWeight.w500,
                      color: ready ? AppColors.greenText : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            TaraletsButton.orange(
              small: true,
              full: false,
              isLoading: isLoading,
              label: 'Generate Itinerary',
              icon: const Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: Colors.white,
              ),
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySelectedState extends StatelessWidget {
  const _EmptySelectedState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.playlist_add_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No places added yet',
              textAlign: TextAlign.center,
              style: AppText.ui(17, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Go back to Group Recommendations and add places before '
              'starting the group vote.',
              textAlign: TextAlign.center,
              style: AppText.ui(
                12.5,
                FontWeight.w400,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 280,
              child: TaraletsButton.orange(
                label: 'Back to Recommendations',
                onPressed: onBack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
