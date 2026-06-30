class InvitableUser {
  const InvitableUser({
    required this.id,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.emailHint,
  });

  final String id;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? emailHint;

  String get label {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (username != null) return '@$username';
    return 'User';
  }

  String? get subtitle {
    if (username != null && displayName != null) return '@$username';
    return emailHint;
  }

  factory InvitableUser.fromJson(Map<String, dynamic> json) {
    return InvitableUser(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      emailHint: json['email_hint'] as String?,
    );
  }

  String get initials {
    final name = displayName ?? username ?? emailHint ?? 'U';
    return name[0].toUpperCase();
  }
}
