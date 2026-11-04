import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/repository_providers.dart';
import '../../../repositories/trip_repository.dart';

/// Mirrors the flow: enter code -> trip found -> join request sent.
enum JoinPhase { enter, found, joined }

class JoinTripState {
  const JoinTripState({
    this.phase = JoinPhase.enter,
    this.trip,
    this.errorTitle,
    this.errorMessage,
    this.isLoading = false,
  });

  final JoinPhase phase;
  final Trip? trip;
  final String? errorTitle;
  final String? errorMessage;
  final bool isLoading;

  bool get hasError => errorTitle != null;
}

class JoinTripController extends Notifier<JoinTripState> {
  @override
  JoinTripState build() => const JoinTripState();

  /// "Find Trip ->"
  Future<void> findTrip(String code) async {
    if (state.isLoading) return;
    state = const JoinTripState(isLoading: true);
    try {
      final trip = await ref.read(tripRepositoryProvider).findTripByCode(code);
      state = JoinTripState(phase: JoinPhase.found, trip: trip);
    } on TripException catch (e) {
      state = JoinTripState(errorTitle: e.title, errorMessage: e.message);
    } catch (_) {
      state = const JoinTripState(
        errorTitle: 'Something went wrong',
        errorMessage: 'Check your connection and try again.',
      );
    }
  }

  /// "Request to Join ->". Membership starts only after leader approval.
  Future<void> confirmJoin() async {
    final trip = state.trip;
    if (trip == null || state.isLoading) return;
    state = JoinTripState(phase: JoinPhase.found, trip: trip, isLoading: true);
    try {
      await ref.read(tripRepositoryProvider).joinTrip(trip);
      // This is a request only. The leader's approval creates membership.
      state = JoinTripState(phase: JoinPhase.joined, trip: trip);
    } on TripException catch (e) {
      // Masalo ang errors mula sa API tulad ng "Already a member"
      state = JoinTripState(
        phase: JoinPhase.found,
        trip: trip,
        errorTitle: e.title,
        errorMessage: e.message,
      );
    } catch (_) {
      state = JoinTripState(
        phase: JoinPhase.found,
        trip: trip,
        errorTitle: 'Join Failed',
        errorMessage: 'Unable to join the trip. Please try again.',
      );
    }
  }

  /// Hides the inline error as soon as the user edits the code.
  void clearError() {
    if (state.hasError) state = const JoinTripState();
  }

  /// "Cancel" / back arrow on the Trip Found step.
  void backToEnter() => state = const JoinTripState();
}

final joinTripControllerProvider =
    NotifierProvider<JoinTripController, JoinTripState>(JoinTripController.new);
