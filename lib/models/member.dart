class Member {
  final String id;
  final String tripId;
  final String userId;
  final DateTime? requiredDepartureTime;
  final String status; // WAITING_DEPARTURE, EN_ROUTE, ARRIVED
  final String priorityCategory; // Far, Near

  Member({
    required this.id,
    required this.tripId,
    required this.userId,
    this.requiredDepartureTime,
    required this.status,
    required this.priorityCategory,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      userId: json['user_id'] as String,
      requiredDepartureTime: json['required_departure_time'] != null
          ? DateTime.parse(json['required_departure_time'] as String)
          : null,
      status: json['status'] as String? ?? 'WAITING_DEPARTURE',
      priorityCategory: json['priority_category'] as String? ?? 'Near',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'user_id': userId,
      'required_departure_time': requiredDepartureTime?.toIso8601String(),
      'status': status,
      'priority_category': priorityCategory,
    };
  }
}