import 'dart:async';
import 'dart:math';

import '../core/utils/formatters.dart';
import '../features/trip/data/models/trip_models.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

enum TripStatus { active, upcoming, done }

class Trip {
  const Trip({
    required this.id,
    required this.code,
    required this.title,
    required this.status,
    required this.dateLabel,
    required this.longDate,
    required this.meetup,
    required this.meetupFull,
    required this.arrivalTarget,
    required this.memberNames,
    required this.leader,
    this.spotsOpen = 0,
    this.onWayCount = 0,
  });

  final String id;

  /// Invite code, e.g. `TARA-88`.
  final String code;
  final String title;
  final TripStatus status;

  /// Short label used on cards, e.g. "Today, Aug 29" / "Sep 12, 2026".
  final String dateLabel;

  /// e.g. "Saturday, August 29, 2026".
  final String longDate;

  /// e.g. "Plaza Roma".
  final String meetup;

  /// e.g. "Plaza Roma, Intramuros".
  final String meetupFull;
  final String arrivalTarget;
  final List<String> memberNames;
  final String leader;
  final int spotsOpen;
  final int onWayCount;

  int get memberCount => memberNames.length;

  /// JSON keys are a guess (snake_case, FastAPI style). Adjust when the real
  /// API exists.
  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'].toString(),
    code: json['code'] as String,
    title: json['title'] as String,
    status: TripStatus.values.byName(json['status'] as String),
    dateLabel: json['date_label'] as String,
    longDate: json['long_date'] as String,
    meetup: json['meetup'] as String,
    meetupFull: json['meetup_full'] as String,
    arrivalTarget: json['arrival_target'] as String,
    memberNames: List<String>.from(json['member_names'] as List),
    leader: json['leader'] as String,
    spotsOpen: (json['spots_open'] as num?)?.toInt() ?? 0,
    onWayCount: (json['on_way_count'] as num?)?.toInt() ?? 0,
  );
}

// ---------------------------------------------------------------------------
// Exceptions. `title` + `message` are the exact strings from the Figma
// ErrorNote and are safe to show directly in the UI.
// ---------------------------------------------------------------------------

class TripException implements Exception {
  const TripException(this.title, this.message);
  final String title;
  final String message;

  @override
  String toString() => '$title: $message';
}

class InvalidTripCodeException extends TripException {
  const InvalidTripCodeException()
    : super(
        'Invalid room code',
        'We could not find a trip with that code. Check the code and try again.',
      );
}

class TripCodeExpiredException extends TripException {
  const TripCodeExpiredException()
    : super(
        'Room code expired',
        'This trip has ended or the code is no longer active. Ask the leader for a new one.',
      );
}

// ---------------------------------------------------------------------------
// Contract
// ---------------------------------------------------------------------------

abstract class TripRepository {
  /// Step 1 of Join Trip ("Find Trip"): look up the trip that owns [code].
  /// Throws a [TripException] on failure.
  Future<Trip> findTripByCode(String code);

  /// Step 2 ("Join This Trip"): join the trip returned by [findTripByCode].
  Future<void> joinTrip(Trip trip);

  /// Trips the current user belongs to (Trips tab, Home active-trip card).
  Future<List<Trip>> getMyTrips();

  /// Create Trip wizard, final step ("Create Trip 🎉").
  Future<Trip> createTrip(CreateTripDto dto);

  /// Preferences saved for a trip (Group Preferences screen).
  Future<GroupPreferences?> getGroupPreferences(String tripId);

  Future<void> updateGroupPreferences(String tripId, GroupPreferences prefs);
}

/// Room codes look like Figma's `TARA-88`: four letters, a dash, two digits.
String generateRoomCode([Random? random]) {
  final rnd = random ?? Random();
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // no I / O
  final head = String.fromCharCodes(
    List.generate(4, (_) => letters.codeUnitAt(rnd.nextInt(letters.length))),
  );
  final digits = (10 + rnd.nextInt(90)).toString();
  return '$head-$digits';
}

// ---------------------------------------------------------------------------
// Mock implementation (Metro Manila content only)
// ---------------------------------------------------------------------------

/// In-memory fake used until the FastAPI endpoints exist.
///
/// Demo codes (same as the Figma prototype):
///   TARA-88 -> found
///   OLD-01  -> TripCodeExpiredException
///   other   -> InvalidTripCodeException
class MockTripRepository implements TripRepository {
  MockTripRepository({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;

  static const List<String> _crew = ['Dennise', 'Ana', 'Paola', 'Jewelle'];

  static const Trip _dayOut = Trip(
    id: 'trip_001',
    code: 'TARA-88',
    title: 'Intramuros & Binondo Day Out',
    status: TripStatus.active,
    dateLabel: 'Today, Aug 29',
    longDate: 'Saturday, August 29, 2026',
    meetup: 'Plaza Roma',
    meetupFull: 'Plaza Roma, Intramuros',
    arrivalTarget: '2:30 PM',
    memberNames: _crew,
    leader: 'Dennise',
    spotsOpen: 1,
    onWayCount: 3,
  );

  static const List<Trip> _seed = [
    _dayOut,
    Trip(
      id: 'trip_002',
      code: 'HERI-12',
      title: 'Manila Heritage Weekend',
      status: TripStatus.upcoming,
      dateLabel: 'Sep 12, 2026',
      longDate: 'Saturday, September 12, 2026',
      meetup: 'Intramuros',
      meetupFull: 'Intramuros, Manila',
      arrivalTarget: '9:00 AM',
      memberNames: ['Dennise', 'Ana', 'Paola', 'Jewelle', 'Mika', 'Carlo'],
      leader: 'Dennise',
    ),
    Trip(
      id: 'trip_003',
      code: 'NITE-20',
      title: 'Binondo Night Market',
      status: TripStatus.upcoming,
      dateLabel: 'Sep 20, 2026',
      longDate: 'Sunday, September 20, 2026',
      meetup: 'Binondo Church',
      meetupFull: 'Binondo Church, Binondo',
      arrivalTarget: '6:00 PM',
      memberNames: ['Dennise', 'Ana', 'Paola'],
      leader: 'Ana',
    ),
    Trip(
      id: 'trip_004',
      code: 'FOOD-10',
      title: 'Ermita Food Crawl',
      status: TripStatus.done,
      dateLabel: 'Aug 10, 2026',
      longDate: 'Monday, August 10, 2026',
      meetup: 'Remedios Circle',
      meetupFull: 'Remedios Circle, Malate',
      arrivalTarget: '5:00 PM',
      memberNames: _crew,
      leader: 'Dennise',
    ),
    Trip(
      id: 'trip_005',
      code: 'LUNE-28',
      title: 'Rizal Park Visit',
      status: TripStatus.done,
      dateLabel: 'Jul 28, 2026',
      longDate: 'Tuesday, July 28, 2026',
      meetup: 'Luneta',
      meetupFull: "Rizal Park (Luneta), Ermita",
      arrivalTarget: '8:00 AM',
      memberNames: ['Dennise', 'Ana', 'Paola', 'Jewelle', 'Mika'],
      leader: 'Paola',
    ),
  ];

  final List<Trip> _trips = List.of(_seed);

  @override
  Future<Trip> findTripByCode(String code) async {
    await Future<void>.delayed(latency);

    final c = code.trim().toUpperCase();
    if (c == 'OLD-01') throw const TripCodeExpiredException();
    final known = _trips.where((t) => t.code == c);
    if (known.isNotEmpty) return known.first;
    throw const InvalidTripCodeException();
  }

  @override
  Future<void> joinTrip(Trip trip) async {
    await Future<void>.delayed(latency);
    if (!_trips.any((t) => t.id == trip.id)) _trips.add(trip);
  }

  @override
  Future<List<Trip>> getMyTrips() async {
    await Future<void>.delayed(latency ~/ 2);
    return List.unmodifiable(_trips);
  }

  final Map<String, GroupPreferences> _prefs = {};

  @override
  Future<Trip> createTrip(CreateTripDto dto) async {
    await Future<void>.delayed(latency);
    final trip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      code: dto.code,
      title: dto.title,
      status: TripStatus.upcoming,
      dateLabel: formatShortDate(dto.date),
      longDate: formatLongDate(dto.date),
      meetup: dto.meetupName.split(',').first.trim(),
      meetupFull: dto.meetupName,
      arrivalTarget: formatTimeOfDay(dto.meetupTime),
      memberNames: dto.memberNames,
      leader: dto.memberNames.first,
    );
    _trips.insert(0, trip);
    _prefs[trip.id] = dto.preferences;
    return trip;
  }

  @override
  Future<GroupPreferences?> getGroupPreferences(String tripId) async =>
      _prefs[tripId];

  @override
  Future<void> updateGroupPreferences(
    String tripId,
    GroupPreferences prefs,
  ) async {
    await Future<void>.delayed(latency);
    _prefs[tripId] = prefs;
  }
}
