class User {
  final String id;
  final String email;
  final String fullName;
  final bool isDiscountEligible;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isDiscountEligible,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      isDiscountEligible: json['is_discount_eligible'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'is_discount_eligible': isDiscountEligible,
    };
  }
}