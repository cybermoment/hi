import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'balloon_model.dart';
import '../../core/weather_service.dart';

class BalloonState extends Equatable {
  final List<BalloonModel> balloons;

  const BalloonState({this.balloons = const []});

  @override
  List<Object> get props => [balloons];
}

class BalloonCubit extends Cubit<BalloonState> {
  Timer? _driftTimer;
  Timer? _weatherTimer;
  final Map<String, ({double speed, double direction, DateTime at})> _weatherCache = {};
  static const _cacheExpiry = Duration(minutes: 2);

  BalloonCubit() : super(const BalloonState()) {
    _startDrifting();
    _startWeatherUpdates();
  }

  void addBalloon(BalloonModel balloon) {
    emit(BalloonState(balloons: [...state.balloons, balloon]));
  }

  String _gridKey(double lat, double lon) =>
      '${(lat * 10).round() / 10}_${(lon * 10).round() / 10}';

  void _startWeatherUpdates() {
    _weatherTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (state.balloons.isEmpty) return;
      for (final b in state.balloons) {
        final key = _gridKey(b.latitude, b.longitude);
        if (_weatherCache[key] != null &&
            DateTime.now().difference(_weatherCache[key]!.at) < _cacheExpiry) {
          continue;
        }
        final wind = await WeatherService.getWindAt(b.latitude, b.longitude);
        _weatherCache[key] = (speed: wind.windSpeed, direction: wind.windDirection, at: DateTime.now());
      }
      _applyCachedWeather();
    });
  }

  void _applyCachedWeather() {
    if (state.balloons.isEmpty) return;
    final updated = state.balloons.map((b) {
      final key = _gridKey(b.latitude, b.longitude);
      final cached = _weatherCache[key];
      if (cached == null) return b;
      return b.copyWith(windSpeed: cached.speed, windDirection: cached.direction);
    }).toList();
    emit(BalloonState(balloons: updated));
  }

  void _startDrifting() {
    _driftTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (state.balloons.isEmpty) return;

      final newBalloons = <BalloonModel>[];
      for (final b in state.balloons) {
        final key = _gridKey(b.latitude, b.longitude);
        var speed = b.windSpeed;
        var direction = b.windDirection;
        final cached = _weatherCache[key];
        if (cached != null) {
          speed = cached.speed;
          direction = cached.direction;
        } else {
          final wind = await WeatherService.getWindAt(b.latitude, b.longitude);
          speed = wind.windSpeed;
          direction = wind.windDirection;
          _weatherCache[key] = (speed: speed, direction: direction, at: DateTime.now());
        }

        const double speedFactor = 0.00001;
        final double trigAngle = (90 - direction) * (math.pi / 180.0);
        final double dLat = speed * speedFactor * math.sin(trigAngle);
        final double dLon = speed * speedFactor * math.cos(trigAngle);

        newBalloons.add(b.copyWith(
          latitude: b.latitude + dLat,
          longitude: b.longitude + dLon,
          windSpeed: speed,
          windDirection: direction,
        ));
      }
      emit(BalloonState(balloons: newBalloons));
    });
  }

  @override
  Future<void> close() {
    _driftTimer?.cancel();
    _weatherTimer?.cancel();
    return super.close();
  }
}
