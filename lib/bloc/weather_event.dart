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
