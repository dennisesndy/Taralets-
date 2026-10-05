import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:taralets_mobile/core/utils/geo_boundary.dart';
import 'package:taralets_mobile/features/trip/data/models/trip_models.dart';
import 'package:taralets_mobile/repositories/trip_repository.dart';

void main() {
  late MockTripRepository repo;

  setUp(() {
    repo = MockTripRepository(latency: Duration.zero);
  });

  test('finds the Manila demo trip, ignoring case and spaces', () async {
    final trip = await repo.findTripByCode(' tara-88 ');
    expect(trip.code, 'TARA-88');
    expect(trip.title, 'Intramuros & Binondo Day Out');
    expect(trip.meetupFull, 'Plaza Roma, Intramuros');
    expect(trip.memberCount, 4);
  });

  test('throws TripCodeExpiredException for OLD-01', () {
    expect(
      repo.findTripByCode('OLD-01'),
      throwsA(isA<TripCodeExpiredException>()),
    );
  });

  test('throws InvalidTripCodeException for unknown or empty codes', () {
    expect(
      repo.findTripByCode('ZZZ-99'),
      throwsA(isA<InvalidTripCodeException>()),
    );
    expect(repo.findTripByCode(''), throwsA(isA<InvalidTripCodeException>()));
  });

  test('error messages match the Figma ErrorNote copy', () {
    const invalid = InvalidTripCodeException();
    expect(invalid.title, 'Invalid room code');
    const expired = TripCodeExpiredException();
    expect(expired.title, 'Room code expired');
  });

  test('joining twice does not duplicate the trip', () async {
    final before = (await repo.getMyTrips()).length;
    final trip = await repo.findTripByCode('TARA-88');
    await repo.joinTrip(trip);
    await repo.joinTrip(trip);
    expect(await repo.getMyTrips(), hasLength(before));
  });

  test('all mock trips are Manila meetups (no other cities)', () async {
    const banned = ['Bohol', 'Palawan', 'Baguio', 'BGC', 'Makati', 'Cebu'];
    for (final t in await repo.getMyTrips()) {
      final text = '${t.title} ${t.meetup} ${t.meetupFull}';
      for (final b in banned) {
        expect(text.contains(b), isFalse, reason: '$b found in "$text"');
      }
    }
  });

  test('generated room codes look like TARA-88', () {
    for (var i = 0; i < 50; i++) {
      expect(generateRoomCode(), matches(RegExp(r'^[A-Z]{4}-\d{2}$')));
    }
  });

  test(
    'createTrip adds an upcoming Manila trip that can be found by code',
    () async {
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
      expect(trip.status, TripStatus.upcoming);
      expect(trip.arrivalTarget, '2:30 PM');
      expect(trip.dateLabel, 'Nov 14, 2026');
      expect((await repo.getMyTrips()).first.code, 'TEST-42');
      expect(
        (await repo.findTripByCode('test-42')).title,
        'Binondo Food Crawl',
      );
      expect((await repo.getGroupPreferences(trip.id))?.budget, '₱₱');
    },
  );

  test('Manila meetup presets are inside the boundary; Tagaytay is not', () {
    expect(GeoBoundary.isWithinMetroManila(14.5896, 120.9753), isTrue);
    expect(GeoBoundary.isWithinMetroManila(14.1153, 120.9621), isFalse);
    expect(GeoBoundary.mentionsOutside('Tagaytay ridge'), isTrue);
    expect(GeoBoundary.mentionsOutside('Intramuros'), isFalse);
  });
}
