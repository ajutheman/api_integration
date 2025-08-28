import 'package:bloc/bloc.dart';
import 'weather_event.dart';
import 'weather_state.dart';
import '../services/weather_api.dart';

class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final WeatherApi api;

  WeatherBloc(this.api) : super(WeatherInitial()) {
    on<FetchWeather>(_onFetchWeather);
  }

  Future<void> _onFetchWeather(FetchWeather event, Emitter<WeatherState> emit) async {
    emit(WeatherLoading());
    try {
      // 1) Current (also gives lat/lon)
      final current = await api.current(q: event.query, aqi: 'yes');
      final loc = current['location'] as Map<String, dynamic>;
      final lat = (loc['lat'] as num).toString();
      final lon = (loc['lon'] as num).toString();
      final latlon = '$lat,$lon';

      // Dates
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final today = fmt(now);
      final yesterday = fmt(now.subtract(const Duration(days: 1)));
      final plus30 = fmt(now.add(const Duration(days: 30)));

      // 2) Other endpoints (catch per-call errors so the UI still shows what it can)
      final results = await Future.wait([
        api.forecast(q: event.query, days: 3, alerts: 'yes', aqi: 'yes'),
        api.astronomy(q: event.query, dt: today),
        api.timeZone(q: latlon),
        api.history(q: event.query, dt: yesterday),
        api.future(q: event.query, dt: plus30),
        api.marine(q: latlon, dt: today),
      ].map((f) => f.then((v) => v).catchError((e) => {'_error': e.toString()})));

      emit(WeatherLoaded({
        'current': current,
        'forecast': results[0],
        'astronomy': results[1],
        'timezone': results[2],
        'history': results[3],
        'future': results[4],
        'marine': results[5],
      }));
    } catch (e) {
      emit(WeatherError(e.toString()));
    }
  }
}
