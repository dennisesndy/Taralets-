class Trip {
  final String id;
  final String title;
  final DateTime targetArrivalTime;
  final String destinationPlaceId;
  final String status;

  Trip({
    required this.id,
    required this.title,
    required this.targetArrivalTime,
    required this.destinationPlaceId,
    required this.status,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      title: json['title'] as String,
      targetArrivalTime: DateTime.parse(json['target_arrival_time'] as String),
      destinationPlaceId: json['destination_place_id'] as String,
      status: json['status'] as String? ?? 'PLANNING',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'target_arrival_time': targetArrivalTime.toIso8601String(),
      'destination_place_id': destinationPlaceId,
      'status': status,
    };
  }
}