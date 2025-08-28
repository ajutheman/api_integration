import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                          onSubmitted: (_) => _fetch(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _fetch(context), child: const Text('Fetch')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: BlocBuilder<WeatherBloc, WeatherState>(
                      builder: (context, state) {
                        if (state is WeatherLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (state is WeatherError) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(state.message)),
                            );
                          });
                          return Center(
                            child: Text(state.message,
                                style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                          );
                        }
                        if (state is WeatherLoaded) {
                          return _buildResults(state.data);
                        }
                        return const Center(
                          child: Text('Enter a city and press Fetch', style: TextStyle(color: Colors.white70)),
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

  void _fetch(BuildContext context) {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    context.read<WeatherBloc>().add(FetchWeather(q));
  }

  Widget _blob(double size, Color color) =>
      Container(height: size, width: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _buildResults(Map<String, dynamic> data) {
    Map<String, dynamic>? mapOf(dynamic x) => x is Map<String, dynamic> ? x : null;
    final current = mapOf(data['current']);
    final forecast = mapOf(data['forecast']);
    final astronomy = mapOf(data['astronomy']);
    final timezone = mapOf(data['timezone']);
    final history = mapOf(data['history']);
    final future = mapOf(data['future']);
    final marine = mapOf(data['marine']); // may contain "_error"

    final loc = current?['location'] as Map<String, dynamic>?;
    final cur = current?['current'] as Map<String, dynamic>?;
    final fcDays = (forecast?['forecast']?['forecastday'] as List?) ?? const [];

    return ListView(
      children: [
        if (loc != null && cur != null)
          _section(
            title: 'Current — ${loc['name']}, ${loc['region'] ?? ''} ${loc['country'] ?? ''}'.trim(),
            child: Row(
              children: [
                if (cur['condition']?['icon'] != null)
                  Image.network('https:${cur['condition']['icon']}', width: 64, height: 64),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${cur['temp_c']}°C • ${cur['condition']?['text'] ?? ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                    Text('Feels: ${cur['feelslike_c']}°C   Humidity: ${cur['humidity']}%',
                        style: const TextStyle(color: Colors.white70)),
                    if (cur['air_quality'] != null)
                      Text('US EPA AQI: ${cur['air_quality']['us-epa-index']}',
                          style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
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
              'Day condition: ${future!['forecast']['forecastday']?[0]?['day']?['condition']?['text'] ?? '—'}',
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
