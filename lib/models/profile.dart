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
    id: json['id'],
    fullName: json['full_name'],
    position: json['position'],
    avatarColor: json['avatar_color'],
    initials: json['initials'],
  );

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'position': position,
    'avatar_color': avatarColor,
    'initials': initials,
  };
}