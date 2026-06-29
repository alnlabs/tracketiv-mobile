class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'avatar_url': avatarUrl,
      };

  String get initials {
    final name = displayName ?? 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
