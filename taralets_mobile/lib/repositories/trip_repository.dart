import 'dart:async';
import 'dart:math';

import '../core/utils/formatters.dart';
import '../core/utils/geo_boundary.dart';
import '../features/trip/data/models/member.dart';
import '../features/trip/data/models/trip_models.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Trip phase. `lobby` = created, group is still gathering (shows as
/// "Upcoming" in My Trips), `active` = the leader pressed Start Trip.
enum TripStatus { lobby, active, completed, cancelled }

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
    required this.leaderId,
    required this.members,
    this.description = '',
    this.date,
    this.wrapUp = '8:00 PM',
    this.latitude = 14.5896,
    this.longitude = 120.9753,
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

  /// `Member.id` of the trip leader (host).
  final String leaderId;
  final List<Member> members;

  final String description;

  /// Real date when known (trips created or edited in the app).
  final DateTime? date;

  /// Wrap-up time, e.g. "8:00 PM".
  final String wrapUp;
  final double latitude;
  final double longitude;
  final int spotsOpen;
  final int onWayCount;

  // --- derived (keeps older screens such as Join Trip working) -------------
  int get memberCount => members.length;
  List<String> get memberNames => [for (final m in members) m.name];

  Member? get leaderMember {
    for (final m in members) {
      if (m.id == leaderId) return m;
    }
    return null;
  }

  String get leader => leaderMember?.name ?? '';
  int get readyCount => members.where((m) => m.isReady).length;
  bool get everyoneReady => members.every((m) => m.isReady);

  bool isLeader(String? userId) => userId != null && userId == leaderId;

  Trip copyWith({
    String? title,
    TripStatus? status,
    String? dateLabel,
    String? longDate,
    String? meetup,
    String? meetupFull,
    String? arrivalTarget,
    List<Member>? members,
    String? description,
    DateTime? date,
    String? wrapUp,
    double? latitude,
    double? longitude,
    int? onWayCount,
  }) {
    return Trip(
      id: id,
      code: code,
      title: title ?? this.title,
      status: status ?? this.status,
      dateLabel: dateLabel ?? this.dateLabel,
      longDate: longDate ?? this.longDate,
      meetup: meetup ?? this.meetup,
      meetupFull: meetupFull ?? this.meetupFull,
      arrivalTarget: arrivalTarget ?? this.arrivalTarget,
      leaderId: leaderId,
      members: members ?? this.members,
      description: description ?? this.description,
      date: date ?? this.date,
      wrapUp: wrapUp ?? this.wrapUp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      spotsOpen: spotsOpen,
      onWayCount: onWayCount ?? this.onWayCount,
    );
  }

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
    leaderId: json['leader_id'].toString(),
    members: [
      for (final m in json['members'] as List)
        Member.fromJson(m as Map<String, dynamic>),
    ],
    description: json['description'] as String? ?? '',
    date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
    wrapUp: json['wrap_up'] as String? ?? '8:00 PM',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 14.5896,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 120.9753,
    spotsOpen: (json['spots_open'] as num?)?.toInt() ?? 0,
    onWayCount: (json['on_way_count'] as num?)?.toInt() ?? 0,
  );
}

// ---------------------------------------------------------------------------
// Exceptions. `title` + `message` are shown in the Figma ErrorNote.
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

/// Thrown when a non-leader tries a leader-only action (edit, invite, start).
class LeaderOnlyException extends TripException {
  const LeaderOnlyException([String action = 'edit this trip'])
    : super('LEADER PERMISSION REQUIRED', 'Only the trip leader can $action.');
}

// ---------------------------------------------------------------------------
// Contract
// ---------------------------------------------------------------------------

abstract class TripRepository {
  /// Step 1 of Join Trip ("Find Trip"): look up the trip that owns [code].
  Future<Trip> findTripByCode(String code);

  /// Step 2 ("Join This Trip"): join the trip returned by [findTripByCode].
  Future<void> joinTrip(Trip trip);

  /// Trips the current user belongs to (Trips tab, Home active-trip card).
  Future<List<Trip>> getMyTrips();

  /// Create Trip wizard, final step.
  Future<Trip> createTrip(CreateTripDto dto);

  Future<GroupPreferences?> getGroupPreferences(String tripId);
  Future<void> updateGroupPreferences(String tripId, GroupPreferences prefs);

  // --- Day 3: lobby, edit, invite, start ------------------------------------

  Future<Trip> getTrip(String tripId);

  /// Leader only. Validates the Metro Manila boundary.
  Future<Trip> updateTrip(Trip updatedTrip);

  /// Flips a member between ready / not ready. The leader is always ready.
  Future<Trip> toggleMemberStatus(String tripId, String userId);

  /// Leader only. Adds [username] to the lobby as `notReady`.
  Future<Trip> inviteMember(String tripId, String username);

  /// Leader only. Requires everyone to be ready. `lobby` -> `active`.
  Future<Trip> startTrip(String tripId);

  /// Leader only. `active` -> `completed`.
  Future<Trip> completeTrip(String tripId);
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
/// Demo codes: TARA-88 (active), HERI-12 (lobby, you lead), NITE-20 (lobby,
/// Ana leads), OLD-01 -> expired, anything else -> invalid.
///
/// Searchable usernames for Invite: dennise, ana, paola, jewelle, mika, carlo,
/// rhea, miguel, bea.
class MockTripRepository implements TripRepository {
  MockTripRepository({
    this.latency = const Duration(milliseconds: 400),
    this.currentUserId = 'user_001',
  });

  final Duration latency;

  /// Matches `MockAuthRepository`'s signed-in user (Dennise).
  final String currentUserId;

  /// username -> (id, display name). Mock user search.
  static const Map<String, (String, String)> _directory = {
    'dennise': ('user_001', 'Dennise'),
    'ana': ('user_002', 'Ana'),
    'paola': ('user_003', 'Paola'),
    'jewelle': ('user_004', 'Jewelle'),
    'mika': ('user_005', 'Mika'),
    'carlo': ('user_006', 'Carlo'),
    'rhea': ('user_007', 'Rhea'),
    'miguel': ('user_008', 'Miguel'),
    'bea': ('user_009', 'Bea'),
  };

  Member _member(String username, {bool leader = false, bool ready = false}) {
    final entry = _directory[username]!;
    return Member(
      id: entry.$1,
      username: username,
      name: entry.$2,
      isLeader: leader,
      status: leader || ready ? MemberStatus.ready : MemberStatus.notReady,
    );
  }

  late final List<Trip> _trips = _seedTrips();

  List<Trip> _seedTrips() {
    final crewReady = [
      _member('dennise', leader: true),
      _member('ana', ready: true),
      _member('paola', ready: true),
      _member('jewelle', ready: true),
    ];

    return [
      Trip(
        id: 'trip_001',
        code: 'TARA-88',
        title: 'Intramuros & Binondo Day Out',
        status: TripStatus.active,
        dateLabel: 'Today, Aug 29',
        longDate: 'Saturday, August 29, 2026',
        meetup: 'Plaza Roma',
        meetupFull: 'Plaza Roma, Intramuros',
        arrivalTarget: '2:30 PM',
        leaderId: 'user_001',
        members: crewReady,
        spotsOpen: 1,
        onWayCount: 3,
      ),
      Trip(
        id: 'trip_002',
        code: 'HERI-12',
        title: 'Manila Heritage Weekend',
        status: TripStatus.lobby,
        dateLabel: 'Sep 12, 2026',
        longDate: 'Saturday, September 12, 2026',
        meetup: 'Intramuros',
        meetupFull: 'Intramuros, Manila',
        arrivalTarget: '9:00 AM',
        leaderId: 'user_001',
        members: [
          _member('dennise', leader: true),
          _member('ana', ready: true),
          _member('paola'),
          _member('jewelle', ready: true),
          _member('mika'),
          _member('carlo'),
        ],
      ),
      Trip(
        id: 'trip_003',
        code: 'NITE-20',
        title: 'Binondo Night Market',
        status: TripStatus.lobby,
        dateLabel: 'Sep 20, 2026',
        longDate: 'Sunday, September 20, 2026',
        meetup: 'Binondo Church',
        meetupFull: 'Binondo Church, Binondo',
        arrivalTarget: '6:00 PM',
        leaderId: 'user_002',
        latitude: 14.6004,
        longitude: 120.9742,
        members: [
          _member('ana', leader: true),
          _member('dennise'),
          _member('paola', ready: true),
        ],
      ),
      Trip(
        id: 'trip_004',
        code: 'FOOD-10',
        title: 'Ermita Food Crawl',
        status: TripStatus.completed,
        dateLabel: 'Aug 10, 2026',
        longDate: 'Monday, August 10, 2026',
        meetup: 'Remedios Circle',
        meetupFull: 'Remedios Circle, Malate',
        arrivalTarget: '5:00 PM',
        leaderId: 'user_001',
        members: crewReady,
      ),
      Trip(
        id: 'trip_005',
        code: 'LUNE-28',
        title: 'Rizal Park Visit',
        status: TripStatus.completed,
        dateLabel: 'Jul 28, 2026',
        longDate: 'Tuesday, July 28, 2026',
        meetup: 'Luneta',
        meetupFull: 'Rizal Park (Luneta), Ermita',
        arrivalTarget: '8:00 AM',
        leaderId: 'user_003',
        members: [
          _member('paola', leader: true),
          _member('dennise', ready: true),
          _member('ana', ready: true),
          _member('jewelle', ready: true),
          _member('mika', ready: true),
        ],
      ),
    ];
  }

  int _indexOf(String tripId) {
    final i = _trips.indexWhere((t) => t.id == tripId);
    if (i < 0) {
      throw const TripException(
        'TRIP NOT FOUND',
        'This trip is no longer available.',
      );
    }
    return i;
  }

  void _requireLeader(Trip trip, [String action = 'edit this trip']) {
    if (!trip.isLeader(currentUserId)) throw LeaderOnlyException(action);
  }

  // --- Join / list ----------------------------------------------------------

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

  // --- Create ---------------------------------------------------------------

  final Map<String, GroupPreferences> _prefs = {};

  Member _memberForName(String name, {required bool leader}) {
    final username = name.trim().toLowerCase();
    final entry = _directory[username];
    return Member(
      id: entry?.$1 ?? 'user_$username',
      username: username,
      name: entry?.$2 ?? name.trim(),
      isLeader: leader,
      status: leader ? MemberStatus.ready : MemberStatus.notReady,
    );
  }

  @override
  Future<Trip> createTrip(CreateTripDto dto) async {
    await Future<void>.delayed(latency);
    final members = [
      for (var i = 0; i < dto.memberNames.length; i++)
        _memberForName(dto.memberNames[i], leader: i == 0),
    ];
    final trip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      code: dto.code,
      title: dto.title,
      status: TripStatus.lobby,
      dateLabel: formatShortDate(dto.date),
      longDate: formatLongDate(dto.date),
      meetup: dto.meetupName.split(',').first.trim(),
      meetupFull: dto.meetupName,
      arrivalTarget: formatTimeOfDay(dto.meetupTime),
      leaderId: members.first.id,
      members: members,
      description: dto.description,
      date: dto.date,
      wrapUp: formatTimeOfDay(dto.wrapUpTime),
      latitude: dto.latitude,
      longitude: dto.longitude,
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

  // --- Day 3 ----------------------------------------------------------------

  @override
  Future<Trip> getTrip(String tripId) async {
    await Future<void>.delayed(latency ~/ 2);
    return _trips[_indexOf(tripId)];
  }

  @override
  Future<Trip> updateTrip(Trip updatedTrip) async {
    await Future<void>.delayed(latency);
    final i = _indexOf(updatedTrip.id);
    final current = _trips[i];
    _requireLeader(current);

    if (!GeoBoundary.isWithinMetroManila(
      updatedTrip.latitude,
      updatedTrip.longitude,
    )) {
      throw const TripException(
        'OUT OF BOUNDARY',
        'This meetup location is outside the supported Metro Manila area. Choose a location inside Metro Manila to continue.',
      );
    }

    // Members, status and code are not editable here.
    final saved = current.copyWith(
      title: updatedTrip.title,
      description: updatedTrip.description,
      date: updatedTrip.date,
      dateLabel: updatedTrip.dateLabel,
      longDate: updatedTrip.longDate,
      arrivalTarget: updatedTrip.arrivalTarget,
      wrapUp: updatedTrip.wrapUp,
      meetup: updatedTrip.meetup,
      meetupFull: updatedTrip.meetupFull,
      latitude: updatedTrip.latitude,
      longitude: updatedTrip.longitude,
    );
    _trips[i] = saved;
    return saved;
  }

  @override
  Future<Trip> toggleMemberStatus(String tripId, String userId) async {
    await Future<void>.delayed(latency ~/ 2);
    final i = _indexOf(tripId);
    final trip = _trips[i];

    final members = [
      for (final m in trip.members)
        if (m.id == userId && !m.isLeader)
          m.copyWith(
            status: m.isReady ? MemberStatus.notReady : MemberStatus.ready,
          )
        else
          m,
    ];
    final updated = trip.copyWith(members: members);
    _trips[i] = updated;
    return updated;
  }

  @override
  Future<Trip> inviteMember(String tripId, String username) async {
    await Future<void>.delayed(latency);
    final i = _indexOf(tripId);
    final trip = _trips[i];
    _requireLeader(trip, 'invite members');

    final u = username.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
    if (u.isEmpty) {
      throw const TripException(
        'USERNAME REQUIRED',
        'Enter the username of the friend you want to invite.',
      );
    }
    if (trip.members.any((m) => m.username == u)) {
      throw TripException(
        'ALREADY IN THIS TRIP',
        '@$u is already a member of this trip.',
      );
    }
    final entry = _directory[u];
    if (entry == null) {
      throw TripException(
        'USER NOT FOUND',
        'No Taralets user has the username @$u. Check the spelling and try again.',
      );
    }

    final updated = trip.copyWith(
      members: [
        ...trip.members,
        Member(
          id: entry.$1,
          username: u,
          name: entry.$2,
          status: MemberStatus.notReady,
        ),
      ],
    );
    _trips[i] = updated;
    return updated;
  }

  @override
  Future<Trip> startTrip(String tripId) async {
    await Future<void>.delayed(latency);
    final i = _indexOf(tripId);
    final trip = _trips[i];
    _requireLeader(trip, 'start this trip');

    if (!trip.everyoneReady) {
      throw const TripException(
        'MEMBERS NOT READY',
        'Everyone needs to be ready before the trip can start.',
      );
    }
    final started = trip.copyWith(status: TripStatus.active, onWayCount: 0);
    _trips[i] = started;
    return started;
  }

  @override
  Future<Trip> completeTrip(String tripId) async {
    await Future<void>.delayed(latency);
    final i = _indexOf(tripId);
    final trip = _trips[i];
    _requireLeader(trip, 'complete this trip');

    final done = trip.copyWith(status: TripStatus.completed);
    _trips[i] = done;
    return done;
  }
}
