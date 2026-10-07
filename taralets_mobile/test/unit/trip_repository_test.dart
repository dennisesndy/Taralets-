import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taralets_mobile/core/utils/formatters.dart';
import 'package:taralets_mobile/core/utils/geo_boundary.dart';
import 'package:taralets_mobile/features/trip/data/models/member.dart';
import 'package:taralets_mobile/features/trip/data/models/trip_models.dart';
import 'package:taralets_mobile/repositories/trip_repository.dart';

void main() {
  late MockTripRepository repo; // signed in as user_001 (Dennise)
  late MockTripRepository asAna; // signed in as user_002 (Ana)

  setUp(() {
    repo = MockTripRepository(latency: Duration.zero);
    asAna = MockTripRepository(
      latency: Duration.zero,
      currentUserId: 'user_002',
    );
  });

  group('join / create (Day 1-2)', () {
    test('finds the Manila demo trip, ignoring case and spaces', () async {
      final trip = await repo.findTripByCode(' tara-88 ');
      expect(trip.code, 'TARA-88');
      expect(trip.title, 'Intramuros & Binondo Day Out');
      expect(trip.meetupFull, 'Plaza Roma, Intramuros');
      expect(trip.memberCount, 4);
      expect(trip.leader, 'Dennise');
    });

    test('expired and unknown codes throw', () {
      expect(
        repo.findTripByCode('OLD-01'),
        throwsA(isA<TripCodeExpiredException>()),
      );
      expect(
        repo.findTripByCode('ZZZ-99'),
        throwsA(isA<InvalidTripCodeException>()),
      );
    });

    test('generated room codes look like TARA-88', () {
      for (var i = 0; i < 50; i++) {
        expect(generateRoomCode(), matches(RegExp(r'^[A-Z]{4}-\d{2}$')));
      }
    });

    test('createTrip makes a lobby trip led by the creator', () async {
      final trip = await repo.createTrip(
        CreateTripDto(
          code: 'TEST-42',
          title: 'Binondo Food Crawl',
          date: DateTime(2026, 11, 14),
          meetupTime: const TimeOfDay(hour: 14, minute: 30),
          wrapUpTime: const TimeOfDay(hour: 20, minute: 0),
          meetupName: 'Binondo Church',
          latitude: 14.6004,
          longitude: 120.9742,
          memberNames: const ['Dennise', 'Ana'],
          preferences: const GroupPreferences(),
        ),
      );
      expect(trip.status, TripStatus.lobby);
      expect(trip.leaderId, 'user_001');
      expect(trip.arrivalTarget, '2:30 PM');
      expect(trip.dateLabel, 'Nov 14, 2026');
      expect(trip.members.first.isLeader, isTrue);
      expect(trip.members.first.isReady, isTrue);
      expect(trip.members.last.status, MemberStatus.notReady);
      expect((await repo.getMyTrips()).first.code, 'TEST-42');
    });

    test('all mock trips are Manila meetups', () async {
      const banned = ['Bohol', 'Palawan', 'Baguio', 'BGC', 'Makati', 'Cebu'];
      for (final t in await repo.getMyTrips()) {
        final text = '${t.title} ${t.meetup} ${t.meetupFull}';
        for (final b in banned) {
          expect(text.contains(b), isFalse, reason: '$b found in "$text"');
        }
      }
    });

    test('Metro Manila boundary', () {
      expect(GeoBoundary.isWithinMetroManila(14.5896, 120.9753), isTrue);
      expect(GeoBoundary.isWithinMetroManila(14.1153, 120.9621), isFalse);
      expect(GeoBoundary.mentionsOutside('Tagaytay ridge'), isTrue);
    });
  });

  group('Day 3: lobby', () {
    test(
      'toggleMemberStatus flips ready / not ready, never the leader',
      () async {
        final before = await repo.getTrip('trip_002');
        expect(
          before.members.firstWhere((m) => m.id == 'user_003').isReady,
          isFalse,
        );

        final on = await repo.toggleMemberStatus('trip_002', 'user_003');
        expect(
          on.members.firstWhere((m) => m.id == 'user_003').isReady,
          isTrue,
        );

        final off = await repo.toggleMemberStatus('trip_002', 'user_003');
        expect(
          off.members.firstWhere((m) => m.id == 'user_003').isReady,
          isFalse,
        );

        final leader = await repo.toggleMemberStatus('trip_002', 'user_001');
        expect(leader.members.first.isReady, isTrue);
      },
    );

    test(
      'inviteMember adds a not-ready member and rejects bad usernames',
      () async {
        final t = await repo.inviteMember('trip_002', ' @Rhea ');
        expect(t.members.last.username, 'rhea');
        expect(t.members.last.status, MemberStatus.notReady);

        expect(
          repo.inviteMember('trip_002', 'rhea'),
          throwsA(isA<TripException>()),
        );
        expect(
          repo.inviteMember('trip_002', 'ana'),
          throwsA(isA<TripException>()),
        );
        expect(
          repo.inviteMember('trip_002', 'nobody'),
          throwsA(isA<TripException>()),
        );
        expect(
          repo.inviteMember('trip_002', ''),
          throwsA(isA<TripException>()),
        );
      },
    );
  });

  group('Day 3: leader-only actions', () {
    test('only the leader can edit, invite or start', () async {
      final trip = await asAna.getTrip('trip_002'); // Dennise leads this one
      expect(
        asAna.updateTrip(trip.copyWith(title: 'Hacked')),
        throwsA(isA<LeaderOnlyException>()),
      );
      expect(
        asAna.inviteMember('trip_002', 'rhea'),
        throwsA(isA<LeaderOnlyException>()),
      );
      expect(asAna.startTrip('trip_002'), throwsA(isA<LeaderOnlyException>()));
    });

    test(
      'updateTrip saves edits and enforces the Metro Manila boundary',
      () async {
        final trip = await repo.getTrip('trip_002');
        final saved = await repo.updateTrip(
          trip.copyWith(
            title: 'Manila Heritage Weekend 2',
            arrivalTarget: '8:30 AM',
          ),
        );
        expect(saved.title, 'Manila Heritage Weekend 2');
        expect((await repo.getTrip('trip_002')).arrivalTarget, '8:30 AM');

        expect(
          repo.updateTrip(
            trip.copyWith(latitude: 14.1153, longitude: 120.9621),
          ),
          throwsA(isA<TripException>()),
        );
      },
    );

    test('startTrip needs everyone ready, then goes active', () async {
      expect(repo.startTrip('trip_002'), throwsA(isA<TripException>()));

      for (final id in ['user_003', 'user_005', 'user_006']) {
        await repo.toggleMemberStatus('trip_002', id);
      }
      final started = await repo.startTrip('trip_002');
      expect(started.status, TripStatus.active);

      final done = await repo.completeTrip('trip_002');
      expect(done.status, TripStatus.completed);
    });
  });

  group('formatters', () {
    test('parseTimeOfDay and formatMinutes', () {
      expect(parseTimeOfDay('2:30 PM'), const TimeOfDay(hour: 14, minute: 30));
      expect(parseTimeOfDay('12:05 AM'), const TimeOfDay(hour: 0, minute: 5));
      expect(formatMinutes(14 * 60 + 30 - 28 - 15), '1:47 PM');
    });
  });
}
