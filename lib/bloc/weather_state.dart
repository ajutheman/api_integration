import 'package:equatable/equatable.dart';

abstract class WeatherState extends Equatable {
  const WeatherState();
  @override
  List<Object?> get props => [];
}

class WeatherInitial extends WeatherState {}
class WeatherLoading extends WeatherState {}

class WeatherLoaded extends WeatherState {
  final Map<String, dynamic> data;   // {current, forecast, astronomy, timezone, history, future, marine, advForecast, futureCustom, historyCustom}
  final String source;               // 'query' or 'coords'
  const WeatherLoaded(this.data, {required this.source});
  @override
  List<Object?> get props => [data, source];
}

class WeatherError extends WeatherState {
  final String message;
  const WeatherError(this.message);
  @override
  List<Object?> get props => [message];
}
