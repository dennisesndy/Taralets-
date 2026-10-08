import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'trip_repository.dart';
import '../core/network/dio_client.dart';
import '../core/services/secure_storage_service.dart';

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => ApiTripRepository(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  ),
);

final myTripsProvider = FutureProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).getMyTrips(),
);

final currentUserProvider = FutureProvider<AuthUser>(
  (ref) => ref.watch(authRepositoryProvider).me(),
);
