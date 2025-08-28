import 'package:bloc/bloc.dart';
import 'weather_event.dart';
import 'weather_state.dart';
import '../services/weather_api.dart';

class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final WeatherApi api;
  WeatherBloc(this.api) : super(WeatherInitial()) {
    on<FetchWeather>(_onFetchWeather);
    on<FetchWeatherByCoords>(_onFetchWeatherByCoords);
    on<RefreshWeather>(_onRefresh);

    on<FetchForecastAdvanced>(_onForecastAdvanced);
    on<FetchFutureCustom>(_onFutureCustom);
    on<FetchHistoryRange>(_onHistoryRange);
  }

  String? _lastQuery;
  String? _lastLatLon;
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _merge(Map<String, dynamic> patch) {
    _data = {..._data, ...patch};
    return _data;
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

      // format some dates
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final today = fmt(now);
      final yesterday = fmt(now.subtract(const Duration(days: 1)));
      final plus30 = fmt(now.add(const Duration(days: 30)));

      final loc = current['location'] as Map<String, dynamic>;
      final latlon = '${(loc['lat'] as num)},${(loc['lon'] as num)}';

      final parts = await Future.wait([
        api.forecast(q: q, days: 3, alerts: 'yes', aqi: 'yes'),
        api.astronomy(q: q, dt: today),
        api.timeZone(q: latlon),
        api.history(q: q, dt: yesterday),
        api.future(q: q, dt: plus30),
        api.marine(q: latlon, dt: today),
      ].map((f) => f.then((v) => v).catchError((e) => {'_error': e.toString()})));

      _merge({
        'current': current,
        'forecast': parts[0],
        'astronomy': parts[1],
        'timezone': parts[2],
        'history': parts[3],
        'future': parts[4],
        'marine': parts[5],
      });

      emit(WeatherLoaded(_data, source: source));
    } catch (e) {
      emit(WeatherError(e.toString()));
    }
  }

  Future<void> _onForecastAdvanced(FetchForecastAdvanced e, Emitter<WeatherState> emit) async {
    try {
      final res = await api.forecast(
        q: e.q,
        days: e.days,
        lang: e.lang,
        alerts: e.alerts ? 'yes' : 'no',
        aqi: e.aqi ? 'yes' : 'no',
        dt: e.dt ?? '',
        hour: e.hour?.toString() ?? '',
      );
      _merge({'advForecast': res});
      emit(WeatherLoaded(_data, source: _lastLatLon != null ? 'coords' : 'query'));
    } catch (err) {
      emit(WeatherError(err.toString()));
    }
  }

  Future<void> _onFutureCustom(FetchFutureCustom e, Emitter<WeatherState> emit) async {
    try {
      final res = await api.future(q: e.q, dt: e.dt, lang: e.lang);
      _merge({'futureCustom': res});
      emit(WeatherLoaded(_data, source: _lastLatLon != null ? 'coords' : 'query'));
    } catch (err) {
      emit(WeatherError(err.toString()));
    }
  }

  Future<void> _onHistoryRange(FetchHistoryRange e, Emitter<WeatherState> emit) async {
    try {
      final res = await api.history(
        q: e.q,
        dt: e.dt,
        endDt: e.endDt ?? '',
        hour: e.hour?.toString() ?? '',
        lang: e.lang,
      );
      _merge({'historyCustom': res});
      emit(WeatherLoaded(_data, source: _lastLatLon != null ? 'coords' : 'query'));
    } catch (err) {
      emit(WeatherError(err.toString()));
    }
  }
}
