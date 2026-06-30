class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.bio,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.country,
    this.city,
    this.phone,
    this.weightUnit = 'kg',
    this.isAdmin = false,
    this.isSystemAdmin = false,
    required this.createdAt,
  });

  final String id;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final DateTime? dateOfBirth;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? country;
  final String? city;
  final String? phone;
  final String weightUnit;
  final bool isAdmin;
  final bool isSystemAdmin;
  final DateTime createdAt;

  String? get handle => username != null ? '@$username' : null;
  String get publicName => displayName ?? handle ?? 'User';

  String? get location {
    if (city != null && country != null) return '$city, $country';
    return city ?? country;
  }

  String? get genderLabel {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return null;
    }
  }

  String? get weightDisplay {
    if (weightKg == null) return null;
    final value = weightUnit == 'lbs' ? weightKg! * 2.2046226218 : weightKg!;
    return '${value.toStringAsFixed(1)} $weightUnit';
  }

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      country: json['country'] as String?,
      city: json['city'] as String?,
      phone: json['phone'] as String?,
      weightUnit: json['weight_unit'] as String? ?? 'kg',
      isAdmin: json['is_admin'] as bool? ?? false,
      isSystemAdmin: json['is_system_admin'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'display_name': displayName,
        'username': username,
        'avatar_url': avatarUrl,
        'bio': bio,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'country': country,
        'city': city,
        'phone': phone,
        'weight_unit': weightUnit,
      };

  String get initials {
    final name = displayName ?? username ?? 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
