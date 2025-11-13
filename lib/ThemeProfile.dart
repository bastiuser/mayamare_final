class ThemeProfile {
  final int videoIndex;
  final int musicIndex;
  ThemeProfile({required this.videoIndex, required this.musicIndex});

  Map<String, dynamic> toMap() => {
    'videoIndex': videoIndex,
    'musicIndex': musicIndex,
  };
  factory ThemeProfile.fromMap(Map<String, dynamic> m) =>
      ThemeProfile(videoIndex: m['videoIndex'] ?? 0, musicIndex: m['musicIndex'] ?? 0);
}