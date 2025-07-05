class User {
  final String id;
  final String email;
  final String fullName;
  final String userType;
  final String? profilePic;
  final Map<String, dynamic>? companyDetails;
  final int points;
  String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Add other fields as needed

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    this.profilePic,
    this.companyDetails,
    required this.points,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      userType: json['userType'] ?? 'user',
      profilePic: json['profilePic'],
      companyDetails: json['companyDetails'],
      points: json['points'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'userType': userType,
      'profilePic': profilePic,
      'companyDetails': companyDetails,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper method to check if user is a company
  bool get isCompany => userType == 'company';

  // Helper method to check if user is an admin
  bool get isAdmin => userType == 'admin';

  // Create a copy of the user with updated fields
  User copyWith({
    String? name,
    String? email,
    String? profileImage,
    Map<String, dynamic>? companyDetails,
  }) {
    return User(
      id: this.id,
      fullName: name ?? this.fullName,
      email: email ?? this.email,
      userType: this.userType,
      profilePic: profileImage ?? this.profilePic,
      companyDetails: companyDetails ?? this.companyDetails,
      createdAt: this.createdAt,
      points: this.points,
      updatedAt: DateTime.now(),
    );
  }
}
