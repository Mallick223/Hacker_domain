class LocationPingModel {
  final int id;
  final int userId;
  final double lat;
  final double lng;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final String? userName;

  LocationPingModel({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    this.speed,
    this.heading,
    required this.timestamp,
    this.userName,
  });

  factory LocationPingModel.fromJson(Map<String, dynamic> json) {
    return LocationPingModel(
      id: json['id'],
      userId: json['user_id'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
