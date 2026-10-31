class SosAlertModel {
  final int id;
  final int userId;
  final double lat;
  final double lng;
  final String? message;
  final String status; // "open" | "acknowledged" | "resolved"
  final DateTime timestamp;
  final String? userName; // filled in client-side when we can match a user

  SosAlertModel({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.message,
    required this.status,
    required this.timestamp,
    this.userName,
  });

  factory SosAlertModel.fromJson(Map<String, dynamic> json) {
    return SosAlertModel(
      id: json['id'],
      userId: json['user_id'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      message: json['message'],
      status: json['status'] ?? 'open',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  SosAlertModel copyWith({String? status, String? userName}) {
    return SosAlertModel(
      id: id,
      userId: userId,
      lat: lat,
      lng: lng,
      message: message,
      status: status ?? this.status,
      timestamp: timestamp,
      userName: userName ?? this.userName,
    );
  }
}
