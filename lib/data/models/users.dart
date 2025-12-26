class User {
  final int id;
  final String email;
  final String? name;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _asInt(json["id"]),
      email: (json["email"] ?? "").toString(),
      name: json["name"]?.toString(),
      avatarUrl: json["avatarUrl"]?.toString(),
    );
  }
}
