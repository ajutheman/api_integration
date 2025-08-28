import 'package:equatable/equatable.dart';

abstract class WeatherEvent extends Equatable {
  const WeatherEvent();
  @override
  List<Object?> get props => [];
}

class FetchWeather extends WeatherEvent {
  final String query; // city / zip / "lat,lon"
  const FetchWeather(this.query);
  @override
  List<Object?> get props => [query];
}

class FetchWeatherByCoords extends WeatherEvent {
  final double lat;
  final double lon;
  const FetchWeatherByCoords(this.lat, this.lon);
  @override
  List<Object?> get props => [lat, lon];
}

class RefreshWeather extends WeatherEvent {
  const RefreshWeather();
}

// Advanced: /forecast.json fully controlled
class FetchForecastAdvanced extends WeatherEvent {
  final String q;
  final int days;          // 1..14
  final String lang;       // e.g., "en"
  final bool alerts;       // yes/no
  final bool aqi;          // yes/no
  final String? dt;        // optional YYYY-MM-DD
  final int? hour;         // optional 0..23
  const FetchForecastAdvanced({
    required this.q,
    required this.days,
    required this.lang,
    required this.alerts,
    required this.aqi,
    this.dt,
    this.hour,
  });
  @override
  List<Object?> get props => [q, days, lang, alerts, aqi, dt, hour];
}

// Advanced: /future.json
class FetchFutureCustom extends WeatherEvent {
  final String q;
  final String dt;    // 14..300 days ahead
  final String lang;
  const FetchFutureCustom({required this.q, required this.dt, required this.lang});
  @override
  List<Object?> get props => [q, dt, lang];
}

// Advanced: /history.json, single day or 30-day max range
class FetchHistoryRange extends WeatherEvent {
  final String q;
  final String dt;       // start
  final String? endDt;   // optional end
  final int? hour;       // optional
  final String lang;
  const FetchHistoryRange({required this.q, required this.dt, this.endDt, this.hour, required this.lang});
  @override
  List<Object?> get props => [q, dt, endDt, hour, lang];
}
