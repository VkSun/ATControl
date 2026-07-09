class Profile {
  final String id;
  final String fullName;
  final String position;
  final String avatarColor;
  final String initials;

  Profile({
    required this.id,
    required this.fullName,
    required this.position,
    required this.avatarColor,
    required this.initials,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    position: json['position'] as String,
    avatarColor: json['avatar_color'] as String,
    initials: json['initials'] as String,
  );

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'position': position,
    'avatar_color': avatarColor,
    'initials': initials,
  };
}