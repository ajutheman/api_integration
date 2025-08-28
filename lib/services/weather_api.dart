import 'dart:convert';
import 'package:dio/dio.dart';

/// Reads your key from --dart-define=WEATHER_API_KEY=xxxx
const _apiKey = String.fromEnvironment('WEATHER_API_KEY', defaultValue: '');

class WeatherApiException implements Exception {
  final int? code; // WeatherAPI error code (e.g., 1002, 1003, 2007)
  final String msg;
  WeatherApiException(this.msg, {this.code});
  @override
  String toString() => 'WeatherApiException(code: $code, msg: $msg)';
}

class WeatherApi {
  static const _baseUrl = 'https://api.weatherapi.com/v1';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ),
  );

  WeatherApi() {
    if (_apiKey.isEmpty) {
      throw WeatherApiException(
        'API key missing. Start with --dart-define=WEATHER_API_KEY=YOUR_KEY',
      );
    }
    // Optional: uncomment for detailed logs
    // _dio.interceptors.add(LogInterceptor(
    //   request: true, responseBody: true, error: true,
    // ));
  }

  Map<String, String> _withKey(Map<String, String> params) =>
      {'key': _apiKey, ...params}..removeWhere((k, v) => v.isEmpty);

  dynamic _decoded(Response res) {
    var data = res.data;
    if (data is String && data.isNotEmpty) {
      try { data = json.decode(data); } catch (_) {}
    }
    return data;
  }

  Never _throwFrom(dynamic data, int? status) {
    if (data is Map) {
      if (data['error'] is Map) {
        final err = data['error'] as Map;
        throw WeatherApiException(
          err['message']?.toString() ?? 'Request failed',
          code: (err['code'] as num?)?.toInt(),
        );
      }
      if (data['code'] != null && data['message'] != null) {
        throw WeatherApiException(
          data['message'].toString(),
          code: (data['code'] as num?)?.toInt(),
        );
      }
    }
    throw WeatherApiException('Request failed (HTTP $status).');
  }

  Future<Map<String, dynamic>> _getMap(String path, Map<String, String> params) async {
    final res = await _dio.get(path, queryParameters: _withKey(params));
    final data = _decoded(res);
    if (res.statusCode != null && res.statusCode! >= 400) _throwFrom(data, res.statusCode);
    if (data is Map && data['error'] != null) _throwFrom(data, res.statusCode);
    if (data is! Map<String, dynamic>) {
      throw WeatherApiException('Unexpected response type (expected Map).');
    }
    return data;
  }

  Future<List<dynamic>> _getList(String path, Map<String, String> params) async {
    final res = await _dio.get(path, queryParameters: _withKey(params));
    final data = _decoded(res);
    if (res.statusCode != null && res.statusCode! >= 400) _throwFrom(data, res.statusCode);
    if (data is Map && data['error'] != null) _throwFrom(data, res.statusCode);
    if (data is! List<dynamic>) {
      throw WeatherApiException('Unexpected response type (expected List).');
    }
    return data;
  }

  // ---- Endpoints ----

  Future<Map<String, dynamic>> current({
    required String q,
    String lang = '',
    String aqi = 'yes',
  }) => _getMap('/current.json', {'q': q, 'lang': lang, 'aqi': aqi});

  Future<Map<String, dynamic>> forecast({
    required String q,
    required int days,
    String dt = '',
    String unixdt = '',
    String hour = '',
    String lang = '',
    String alerts = 'no',
    String aqi = 'no',
    String tp = '',
  }) => _getMap('/forecast.json', {
    'q': q,
    'days': days.toString(),
    'dt': dt,
    'unixdt': unixdt,
    'hour': hour,
    'lang': lang,
    'alerts': alerts,
    'aqi': aqi,
    'tp': tp,
  });

  Future<Map<String, dynamic>> future({
    required String q,
    required String dt,
    String lang = '',
  }) => _getMap('/future.json', {'q': q, 'dt': dt, 'lang': lang});

  Future<Map<String, dynamic>> history({
    required String q,
    required String dt,
    String endDt = '',
    String unixdt = '',
    String unixendDt = '',
    String hour = '',
    String lang = '',
  }) => _getMap('/history.json', {
    'q': q,
    'dt': dt,
    'end_dt': endDt,
    'unixdt': unixdt,
    'unixend_dt': unixendDt,
    'hour': hour,
    'lang': lang,
  });

  Future<Map<String, dynamic>> marine({
    required String q, // "lat,lon"
    String dt = '',
    String endDt = '',
    String lang = '',
  }) => _getMap('/marine.json', {'q': q, 'dt': dt, 'end_dt': endDt, 'lang': lang});

  Future<List<dynamic>> search({required String q}) =>
      _getList('/search.json', {'q': q});

  Future<Map<String, dynamic>> ipLookup({String q = ''}) =>
      _getMap('/ip.json', {'q': q});

  Future<Map<String, dynamic>> timeZone({required String q}) =>
      _getMap('/timezone.json', {'q': q});

  Future<Map<String, dynamic>> astronomy({
    required String q,
    String dt = '',
  }) => _getMap('/astronomy.json', {'q': q, 'dt': dt});
}
