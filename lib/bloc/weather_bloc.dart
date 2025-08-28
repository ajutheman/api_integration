import 'package:bloc/bloc.dart';
import 'weather_event.dart';
import 'weather_state.dart';
import '../services/weather_api.dart';

class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final WeatherApi api;

  // Keep last “input” so Refresh can re-fetch
  String? _lastQuery;
  String? _lastLatLon; // "lat,lon"

  WeatherBloc(this.api) : super(WeatherInitial()) {
    on<FetchWeather>(_onFetchWeather);
    on<FetchWeatherByCoords>(_onFetchWeatherByCoords);
    on<RefreshWeather>(_onRefresh);
  }

  Future<void> _onFetchWeather(FetchWeather e, Emitter<WeatherState> emit) async {
    _lastQuery = e.query;
    _lastLatLon = null;
    await _fetchAll(emit, q: e.query, source: 'query');
  }

  Future<void> _onFetchWeatherByCoords(FetchWeatherByCoords e, Emitter<WeatherState> emit) async {
    _lastLatLon = '${e.lat},${e.lon}';
    _lastQuery = null;
    await _fetchAll(emit, q: _lastLatLon!, source: 'coords');
  }

  Future<void> _onRefresh(RefreshWeather e, Emitter<WeatherState> emit) async {
    final q = _lastLatLon ?? _lastQuery;
    if (q == null) return;
    await _fetchAll(emit, q: q, source: _lastLatLon != null ? 'coords' : 'query');
  }

  Future<void> _fetchAll(Emitter<WeatherState> emit, {required String q, required String source}) async {
    emit(WeatherLoading());
    try {
      final current = await api.current(q: q, aqi: 'yes');

      // If q was city, extract lat,lon for timezone/marine
      final loc = current['location'] as Map<String, dynamic>;
      final latlon = '${(loc['lat'] as num).toString()},${(loc['lon'] as num).toString()}';

      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final today = fmt(now);
      final yesterday = fmt(now.subtract(const Duration(days: 1)));
      final plus30 = fmt(now.add(const Duration(days: 30)));

      final results = await Future.wait([
        api.forecast(q: q, days: 3, alerts: 'yes', aqi: 'yes'),
        api.astronomy(q: q, dt: today),
        api.timeZone(q: latlon),
        api.history(q: q, dt: yesterday),
        api.future(q: q, dt: plus30),
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
      }, source: source));
    } catch (e) {
      emit(WeatherError(e.toString()));
    }
  }
}
