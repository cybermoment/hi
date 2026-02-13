import 'package:equatable/equatable.dart';

enum BalloonType { text, audio }

class BalloonModel extends Equatable {
  final String id;
  final double latitude;
  final double longitude;
  final String content;
  final BalloonType type;
  final DateTime timestamp;
  final double windSpeed;
  final double windDirection;

  const BalloonModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.windSpeed,
    required this.windDirection,
  });

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        content,
        type,
        timestamp,
        windSpeed,
        windDirection,
      ];

  BalloonModel copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? content,
    BalloonType? type,
    DateTime? timestamp,
    double? windSpeed,
    double? windDirection,
  }) {
    return BalloonModel(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
    );
  }
}
