import '../../../../core/utils/geo_boundary.dart';

/// A Metro Manila meetup option (name + coordinates).
class MeetupPreset {
  const MeetupPreset(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;
}

/// Manila-only meetup presets, same list as the Create Trip Meetup step.
const List<MeetupPreset> meetupPresets = [
  MeetupPreset('Plaza Roma, Intramuros', 14.5896, 120.9753),
  MeetupPreset('Luneta Park / Rizal Park', 14.5831, 120.9794),
  MeetupPreset('Binondo Church', 14.6004, 120.9742),
  MeetupPreset('National Museum Plaza', 14.5870, 120.9815),
  MeetupPreset('Baywalk Promenade', 14.5740, 120.9760),
  MeetupPreset(
    'Use my current location',
    GeoBoundary.defaultLat,
    GeoBoundary.defaultLng,
  ),
];
