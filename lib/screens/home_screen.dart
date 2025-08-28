import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../bloc/weather_bloc.dart';
import '../bloc/weather_event.dart';
import '../bloc/weather_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController(text: 'Kochi');

  bool _useLocation = true;
  Position? _lastPos;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    // Try to start with location
    _enableLocationIfNeeded();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enableLocationIfNeeded() async {
    if (!_useLocation) return;
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    // Single fetch first
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _lastPos = pos;
    if (mounted) {
      context.read<WeatherBloc>().add(FetchWeatherByCoords(pos.latitude, pos.longitude));
    }

    // Then subscribe for movement changes (~200m+)
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 200, // re-fetch when user moves 200+ meters
      ),
    ).listen((p) {
      _lastPos = p;
      context.read<WeatherBloc>().add(FetchWeatherByCoords(p.latitude, p.longitude));
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _snack('Turn on Location Services');
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      _snack('Location permission denied');
      return false;
    }
    if (perm == LocationPermission.deniedForever) {
      _snack('Location permission permanently denied. Enable in Settings.');
      return false;
    }
    return true;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _fetchManual() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _useLocation = false);
    _posSub?.cancel();
    context.read<WeatherBloc>().add(FetchWeather(q));
  }

  void _refresh() {
    final bloc = context.read<WeatherBloc>();
    bloc.add(const RefreshWeather());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Weather Demo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(left: -60, top: -40, child: _blob(300, const Color(0xFF7C4DFF))),
          Positioned(right: -120, top: 120, child: _blob(400, const Color(0xFFFFAB40))),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'City / ZIP / "lat,lon"',
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (_) => _fetchManual(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _fetchManual, child: const Text('Fetch')),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    value: _useLocation,
                    onChanged: (v) async {
                      setState(() => _useLocation = v);
                      if (v) {
                        await _enableLocationIfNeeded();
                      } else {
                        _posSub?.cancel();
                      }
                    },
                    title: const Text('Use my location (realtime)', style: TextStyle(color: Colors.white)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 6),

                  Expanded(
                    child: BlocBuilder<WeatherBloc, WeatherState>(
                      builder: (context, state) {
                        if (state is WeatherLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (state is WeatherError) {
                          return Center(
                            child: Text(state.message,
                                style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                          );
                        }
                        if (state is WeatherLoaded) {
                          return _buildResults(state.data, state.source);
                        }
                        return const Center(
                          child: Text('Choose location or enter a city', style: TextStyle(color: Colors.white70)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) =>
      Container(height: size, width: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _buildResults(Map<String, dynamic> data, String source) {
    Map<String, dynamic>? mapOf(dynamic x) => x is Map<String, dynamic> ? x : null;
    final current = mapOf(data['current']);
    final forecast = mapOf(data['forecast']);
    final astronomy = mapOf(data['astronomy']);
    final timezone = mapOf(data['timezone']);
    final history = mapOf(data['history']);
    final future = mapOf(data['future']);
    final marine = mapOf(data['marine']);

    final loc = current?['location'] as Map<String, dynamic>?;
    final cur = current?['current'] as Map<String, dynamic>?;
    final fcDays = (forecast?['forecast']?['forecastday'] as List?) ?? const [];
    final alerts = (forecast?['alerts']?['alert'] as List?) ?? const [];
    final hours = (fcDays.isNotEmpty ? (fcDays[0]['hour'] as List?) : const []) ?? const [];

    return ListView(
      children: [
        if (loc != null && cur != null)
          _section(
            title: 'Current — ${loc['name']} (${source == 'coords' ? 'GPS' : 'Search'})',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (cur['condition']?['icon'] != null)
                  Image.network('https:${cur['condition']['icon']}', width: 64, height: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${cur['temp_c']}°C • ${cur['condition']?['text'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                      Text('Feels: ${cur['feelslike_c']}°C   Humidity: ${cur['humidity']}%   Wind: ${cur['wind_kph']} kph',
                          style: const TextStyle(color: Colors.white70)),
                      if (cur['air_quality'] != null)
                        Text('US EPA AQI: ${cur['air_quality']['us-epa-index']}',
                            style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

        if (hours.isNotEmpty)
          _section(
            title: 'Hourly (today)',
            child: SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hours.length.clamp(0, 12),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final h = hours[i];
                  final time = (h['time'] ?? '').toString().split(' ').last;
                  final icon = h['condition']?['icon'];
                  return Container(
                    width: 90,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 6),
                        if (icon != null) Image.network('https:$icon', width: 36, height: 36),
                        const SizedBox(height: 6),
                        Text('${h['temp_c']}°C', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        if (fcDays.isNotEmpty)
          _section(
            title: 'Forecast (next ${fcDays.length} days)',
            child: Column(
              children: fcDays.take(3).map<Widget>((d) {
                final day = d['day'] ?? {};
                final cond = day['condition'] ?? {};
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: (cond['icon'] != null)
                      ? Image.network('https:${cond['icon']}', width: 40, height: 40)
                      : null,
                  title: Text('${d['date']}', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Min ${day['mintemp_c']}°C / Max ${day['maxtemp_c']}°C • ${cond['text'] ?? ''}',
                      style: const TextStyle(color: Colors.white70)),
                );
              }).toList(),
            ),
          ),

        if (alerts.isNotEmpty)
          _section(
            title: 'Alerts',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: alerts.take(2).map<Widget>((a) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '${a['headline'] ?? a['event'] ?? 'Alert'}\n${a['desc'] ?? ''}',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                );
              }).toList(),
            ),
          ),

        if (astronomy?['astronomy']?['astro'] != null)
          _section(
            title: 'Astronomy',
            child: Text(
              'Sunrise: ${astronomy!['astronomy']['astro']['sunrise']}   '
                  'Sunset: ${astronomy['astronomy']['astro']['sunset']}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),

        if (timezone?['location'] != null)
          _section(
            title: 'Time Zone',
            child: Text(
              'TZ: ${timezone!['location']['tz_id']}   Local: ${timezone['location']['localtime']}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),

        if (history?['forecast'] != null)
          _section(
            title: 'History (yesterday)',
            child: Text(
              'Avg temp: ${history!['forecast']['forecastday']?[0]?['day']?['avgtemp_c']}°C',
              style: const TextStyle(color: Colors.white70),
            ),
          ),

        if (future?['forecast'] != null)
          _section(
            title: 'Future (+30 days)',
            child: Text(
              'Day: ${future!['forecast']['forecastday']?[0]?['day']?['condition']?['text'] ?? '—'}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),

        _section(
          title: 'Marine',
          child: (marine == null || marine['_error'] != null)
              ? const Text('Not available for this location.', style: TextStyle(color: Colors.white54))
              : const Text('Marine data fetched.', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}
