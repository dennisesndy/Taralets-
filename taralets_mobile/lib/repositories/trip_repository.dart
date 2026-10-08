import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../core/network/api_endpoints.dart';
import '../core/utils/geo_boundary.dart';
import '../features/trip/data/models/member.dart';
import '../features/trip/data/models/trip_models.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

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
  final String code;
  final String title;
  final TripStatus status;
  final String dateLabel;
  final String longDate;
  final String meetup;
  final String meetupFull;
  final String arrivalTarget;
  final String leaderId;
  final List<Member> members;
  final String description;
  final DateTime? date;
  final String wrapUp;
  final double latitude;
  final double longitude;
  final int spotsOpen;
  final int onWayCount;

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

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'].toString(),
    code: json['code'] as String,
    title: json['title'] as String,
    status: TripStatus.values.byName(json['status'] as String),
    dateLabel: json['date_label'] as String? ?? '',
    longDate: json['long_date'] as String? ?? '',
    meetup: json['meetup'] as String,
    meetupFull: json['meetup_full'] as String,
    arrivalTarget: json['arrival_target'] as String,
    leaderId: json['leader_id'].toString(),
    members: [
      if (json['members'] != null)
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
// Exceptions
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

class LeaderOnlyException extends TripException {
  const LeaderOnlyException([String action = 'edit this trip'])
    : super('LEADER PERMISSION REQUIRED', 'Only the trip leader can $action.');
}

// ---------------------------------------------------------------------------
// Contract
// ---------------------------------------------------------------------------

abstract class TripRepository {
  Future<Trip> findTripByCode(String code);
  Future<void> joinTrip(Trip trip);
  Future<List<Trip>> getMyTrips();
  Future<Trip> createTrip(CreateTripDto dto);
  Future<GroupPreferences?> getGroupPreferences(String tripId);
  Future<void> updateGroupPreferences(String tripId, GroupPreferences prefs);
  Future<Trip> getTrip(String tripId);
  Future<Trip> updateTrip(Trip updatedTrip);
  Future<Trip> toggleMemberStatus(String tripId, String userId);
  Future<Trip> inviteMember(String tripId, String username);
  Future<Trip> startTrip(String tripId);
  Future<Trip> completeTrip(String tripId);
}

String generateRoomCode([Random? random]) {
  final rnd = random ?? Random();
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  final head = String.fromCharCodes(
    List.generate(4, (_) => letters.codeUnitAt(rnd.nextInt(letters.length))),
  );
  final digits = (10 + rnd.nextInt(90)).toString();
  return '$head-$digits';
}

// ---------------------------------------------------------------------------
// Live API Implementation
// ---------------------------------------------------------------------------

class ApiTripRepository implements TripRepository {
  final Dio _dio;

  ApiTripRepository(this._dio);

  String _handleError(DioException e, String defaultMessage) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response?.data['detail'].toString() ?? defaultMessage;
    }
    return defaultMessage;
  }

  @override
  Future<Trip> findTripByCode(String code) async {
    try {
      final res = await _dio.get(
        '${ApiEndpoints.apiPrefix}/trips/code/${code.toUpperCase()}',
      );
      return Trip.fromJson(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const InvalidTripCodeException();
      } else if (e.response?.statusCode == 410) {
        throw const TripCodeExpiredException();
      }
      throw TripException(
        'SEARCH FAILED',
        _handleError(e, 'Could not find trip'),
      );
    }
  }

  @override
  Future<void> joinTrip(Trip trip) async {
    try {
      await _dio.post('${ApiEndpoints.apiPrefix}/trips/${trip.code}/join');
    } on DioException catch (e) {
      throw TripException(
        'JOIN FAILED',
        _handleError(e, 'Could not join trip'),
      );
    }
  }

  @override
  Future<List<Trip>> getMyTrips() async {
    try {
      final res = await _dio.get('${ApiEndpoints.apiPrefix}/trips/me');
      return (res.data as List).map((e) => Trip.fromJson(e)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      throw TripException(
        'LOAD FAILED',
        _handleError(e, 'Could not load your trips'),
      );
    }
  }

  @override
  Future<Trip> createTrip(CreateTripDto dto) async {
    try {
      final res = await _dio.post(
        '${ApiEndpoints.apiPrefix}/trips',
        data: {
          'code': dto.code,
          'title': dto.title,
          'description': dto.description,
          'date': dto.date.toIso8601String(),
          'meetup_time': '${dto.meetupTime.hour}:${dto.meetupTime.minute}',
          'wrap_up_time': '${dto.wrapUpTime.hour}:${dto.wrapUpTime.minute}',
          'meetup_name': dto.meetupName,
          'latitude': dto.latitude,
          'longitude': dto.longitude,
          'member_names': dto.memberNames,
          'preferences': {
            'categories': dto.preferences.categories,
            'budget': dto.preferences.budget,
            'walking': dto.preferences.walking,
          },
        },
      );
      return Trip.fromJson(res.data);
    } on DioException catch (e) {
      throw TripException(
        'CREATE FAILED',
        _handleError(e, 'Could not create trip'),
      );
    }
  }

  @override
  Future<GroupPreferences?> getGroupPreferences(String tripId) async {
    final response = await _dio.get(
      '${ApiEndpoints.apiPrefix}/trips/$tripId/preferences',
    );

    return GroupPreferences.fromJson(response.data);
  }

  @override
  Future<void> updateGroupPreferences(
    String tripId,
    GroupPreferences preferences,
  ) async {
    await _dio.put(
      '${ApiEndpoints.apiPrefix}/trips/$tripId/preferences',
      data: {
        'categories': preferences.categories,
        'budget': preferences.budget,
        'walking': preferences.walking,
      },
    );
  }

  @override
  Future<Trip> getTrip(String tripId) async {
    try {
      final res = await _dio.get('${ApiEndpoints.apiPrefix}/trips/$tripId');
      return Trip.fromJson(res.data);
    } on DioException catch (e) {
      throw TripException(
        'LOAD FAILED',
        _handleError(e, 'Could not load trip details'),
      );
    }
  }

  @override
  Future<Trip> updateTrip(Trip updatedTrip) async {
    if (!GeoBoundary.isWithinMetroManila(
      updatedTrip.latitude,
      updatedTrip.longitude,
    )) {
      throw const TripException(
        'OUT OF BOUNDARY',
        'This meetup location is outside the supported Metro Manila area.',
      );
    }

    try {
      final res = await _dio.put(
        '${ApiEndpoints.apiPrefix}/trips/${updatedTrip.id}',
        data: {
          'title': updatedTrip.title,
          'description': updatedTrip.description,
          'date': updatedTrip.date?.toIso8601String(),
          'date_label': updatedTrip.dateLabel,
          'long_date': updatedTrip.longDate,
          'arrival_target': updatedTrip.arrivalTarget,
          'wrap_up': updatedTrip.wrapUp,
          'meetup': updatedTrip.meetup,
          'meetup_full': updatedTrip.meetupFull,
          'latitude': updatedTrip.latitude,
          'longitude': updatedTrip.longitude,
        },
      );
      return Trip.fromJson(res.data);
    } on DioException catch (e) {
      throw TripException(
        'UPDATE FAILED',
        _handleError(e, 'Could not update the trip'),
      );
    }
  }

  @override
  Future<Trip> toggleMemberStatus(String tripId, String userId) async {
    try {
      final res = await _dio.post(
        '${ApiEndpoints.apiPrefix}/trips/$tripId/members/$userId/toggle-ready',
      );
      return Trip.fromJson(res.data);
    } on DioException catch (e) {
      throw TripException(
        'STATUS FAILED',
        _handleError(e, 'Could not change readiness status'),
      );
    }
  }

  @override
  Future<Trip> inviteMember(String tripId, String username) async {
    try {
      final res = await _dio.post(
        '${ApiEndpoints.apiPrefix}/trips/$tripId/invite',
        data: {'username': username},
      );
      return Trip.fromJson(res.data);
    } on DioException catch (e) {
      throw TripException(
        'INVITE FAILED',
        _handleError(e, 'Could not invite user'),
      );
    }
  }

  @override
  Future<Trip> startTrip(String tripId) async {
    try {
      final res = await _dio.post(
        '${ApiEndpoints.apiPrefix}/trips/$tripId/start',
      );
      return Trip.fromJson(res.data);
    } on DioException catch (e) {
      throw TripException(
        'START FAILED',
        _handleError(e, 'Could not start the trip'),
      );
    }
  }

  @override
  Future<Trip> completeTrip(String tripId) async {
    try {
      final res = await _dio.post(
        '${ApiEndpoints.apiPrefix}/trips/$tripId/complete',
      );
      return Trip.fromJson(res.data);
    } on DioException catch (e) {
      throw TripException(
        'COMPLETE FAILED',
        _handleError(e, 'Could not complete the trip'),
      );
    }
  }
}

class MockTripRepository implements TripRepository {
  MockTripRepository({
    this.latency = const Duration(milliseconds: 100),
    this.currentUserId = 'user_001',
  });

  final Duration latency;
  final String currentUserId;

  final List<Trip> _trips = [];

  @override
  Future<Trip> findTripByCode(String code) async {
    final match = _trips.where((t) => t.code == code.toUpperCase()).firstOrNull;
    if (match == null) throw const InvalidTripCodeException();
    return match;
  }

  @override
  Future<void> joinTrip(Trip trip) async {
    if (!_trips.any((t) => t.id == trip.id)) _trips.add(trip);
  }

  @override
  Future<List<Trip>> getMyTrips() async => List.unmodifiable(_trips);

  @override
  Future<Trip> createTrip(CreateTripDto dto) async {
    final trip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      code: dto.code,
      title: dto.title,
      status: TripStatus.lobby,
      dateLabel: 'Today',
      longDate: 'Today',
      meetup: dto.meetupName,
      meetupFull: dto.meetupName,
      arrivalTarget: '2:30 PM',
      leaderId: currentUserId,
      members: const [],
      latitude: dto.latitude,
      longitude: dto.longitude,
    );
    _trips.add(trip);
    return trip;
  }

  @override
  Future<GroupPreferences?> getGroupPreferences(String tripId) async => null;

  @override
  Future<void> updateGroupPreferences(
    String tripId,
    GroupPreferences prefs,
  ) async {}

  @override
  Future<Trip> getTrip(String tripId) async =>
      _trips.firstWhere((t) => t.id == tripId);

  @override
  Future<Trip> updateTrip(Trip updatedTrip) async => updatedTrip;

  @override
  Future<Trip> toggleMemberStatus(String tripId, String userId) async =>
      _trips.firstWhere((t) => t.id == tripId);

  @override
  Future<Trip> inviteMember(String tripId, String username) async =>
      _trips.firstWhere((t) => t.id == tripId);

  @override
  Future<Trip> startTrip(String tripId) async =>
      _trips.firstWhere((t) => t.id == tripId);

  @override
  Future<Trip> completeTrip(String tripId) async =>
      _trips.firstWhere((t) => t.id == tripId);
}
