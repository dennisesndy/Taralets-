import 'place.dart';

class ItineraryItem {
  final String id;
  final Place place;
  final String timeSlot;
  final int durationMinutes;
  final int sequenceOrder;

  ItineraryItem({
    required this.id,
    required this.place,
    required this.timeSlot,
    required this.durationMinutes,
    required this.sequenceOrder,
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      id: json['id'] as String,
      place: Place.fromJson(json['place'] as Map<String, dynamic>),
      timeSlot: json['time_slot'] as String,
      durationMinutes: json['duration_minutes'] as int,
      sequenceOrder: json['sequence_order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'place': place.toJson(),
      'time_slot': timeSlot,
      'duration_minutes': durationMinutes,
      'sequence_order': sequenceOrder,
    };
  }
}