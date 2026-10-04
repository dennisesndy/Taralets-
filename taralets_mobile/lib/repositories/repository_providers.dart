import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'trip_repository.dart';

// To go live later, return an API-backed implementation here
// (e.g. `ApiTripRepository(ref.watch(dioProvider))`). Nothing else changes.
final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => MockTripRepository(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(),
);

/// Trips the user belongs to (Trips tab, Home active-trip card).
final myTripsProvider = FutureProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).getMyTrips(),
);

/// Signed-in user (Home header, Profile tab).
final currentUserProvider = FutureProvider<AuthUser>(
  (ref) => ref.watch(authRepositoryProvider).me(),
);
