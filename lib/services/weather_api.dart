import 'dart:convert';
import 'package:dio/dio.dart';

class WeatherApi {
  static const _base = 'https://api.weatherapi.com/v1';
  // 👉 replace with your real key (don’t commit secrets in prod)
  static const _apiKey = '9dadf8cc30e24eafb8995930252108';

  final Dio _dio;
  WeatherApi([Dio? dio]) : _dio = dio ?? Dio(BaseOptions(baseUrl: _base, connectTimeout: const Duration(seconds: 20)));

  Future<Map<String, dynamic>> current({required String q, String aqi = 'no'}) =>
      _get('/current.json', {'key': _apiKey, 'q': q, 'aqi': aqi});

  Future<Map<String, dynamic>> forecast({
    required String q,
    int days = 3,
    String lang = 'en',
    String alerts = 'no',
    String aqi = 'no',
    String dt = '',
    String hour = '',
  }) {
    final params = <String, String>{
      'key': _apiKey,
      'q': q,
      'days': days.toString(),
      'lang': lang,
      'alerts': alerts,
      'aqi': aqi,
    };
    if (dt.isNotEmpty) params['dt'] = dt;
    if (hour.isNotEmpty) params['hour'] = hour;
    return _get('/forecast.json', params);
  }

  Future<Map<String, dynamic>> future({required String q, required String dt, String lang = 'en'}) =>
      _get('/future.json', {'key': _apiKey, 'q': q, 'dt': dt, 'lang': lang});

  Future<Map<String, dynamic>> history({
    required String q,
    required String dt,
    String endDt = '',
    String lang = 'en',
    String hour = '',
  }) {
    final params = <String, String>{'key': _apiKey, 'q': q, 'dt': dt, 'lang': lang};
    if (endDt.isNotEmpty) params['end_dt'] = endDt;
    if (hour.isNotEmpty) params['hour'] = hour;
    return _get('/history.json', params);
  }

  Future<Map<String, dynamic>> astronomy({required String q, required String dt}) =>
      _get('/astronomy.json', {'key': _apiKey, 'q': q, 'dt': dt});

  Future<Map<String, dynamic>> timeZone({required String q}) =>
      _get('/timezone.json', {'key': _apiKey, 'q': q});

  Future<Map<String, dynamic>> marine({required String q, required String dt}) =>
      _get('/marine.json', {'key': _apiKey, 'q': q, 'dt': dt});

  Future<Map<String, dynamic>> _get(String path, Map<String, String> qp) async {
    try {
      final res = await _dio.get(path, queryParameters: qp);
      if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
      if (res.data is String) return json.decode(res.data as String) as Map<String, dynamic>;
      return {'_error': 'Unexpected response'};
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.response!.data['error'] ?? e.message)
          : e.message;
      throw Exception(msg ?? 'Network error');
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
