class User {
  final String id;
  final String email;
  final String? avatarUrl;
  final String? name;
  final Map<String, dynamic>? profileData;
  final String role;

  User({
    required this.id,
    required this.email,
    this.avatarUrl,
    this.name,
    this.profileData,
    this.role = 'user',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      avatarUrl: json['profile_data']?['avatar_url'],
      name: json['profile_data']?['name'],
      profileData: json['profile_data'],
      role: json['role'] ?? 'user',
    );
  }
}
