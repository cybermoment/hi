import 'dart:convert';
import 'package:http/http.dart' as http;

/// 使用 Open-Meteo 免费 API 获取实时风速和风向（无需 API Key）
class WeatherService {
  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// 获取指定经纬度的当前风速和风向
  /// 返回: (windSpeed km/h, windDirection 度数 0=N 90=E)
  static Future<({double windSpeed, double windDirection})> getWindAt(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'current': 'wind_speed_10m,wind_direction_10m',
        },
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Weather API timeout'),
      );
      if (response.statusCode != 200) {
        return _defaultWind();
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) return _defaultWind();

      final speed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 5.0;
      final direction = (current['wind_direction_10m'] as num?)?.toDouble() ?? 90.0;
      return (windSpeed: speed, windDirection: direction);
    } catch (_) {
      return _defaultWind();
    }
  }

  static ({double windSpeed, double windDirection}) _defaultWind() {
    return (windSpeed: 5.0, windDirection: 90.0);
  }
}
