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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController(text: 'Kochi');

  bool _useLocation = true;
  Position? _lastPos;
  StreamSubscription<Position>? _posSub;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _rainbowController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rainbowAnimation;
  late Animation<double> _floatingAnimation;

  // Advanced controls
  int _days = 3;
  String _lang = 'en';
  bool _alerts = true;
  bool _aqi = true;
  bool _useForecastDate = false;
  DateTime _forecastDate = DateTime.now();
  bool _useForecastHour = false;
  int _forecastHour = 12;

  DateTime _futureDate = DateTime.now().add(const Duration(days: 30));

  DateTime _historyStart = DateTime.now().subtract(const Duration(days: 1));
  bool _useHistoryEnd = false;
  DateTime _historyEnd = DateTime.now();
  bool _useHistoryHour = false;
  int _historyHour = 9;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
    _rainbowController = AnimationController(duration: const Duration(seconds: 5), vsync: this)..repeat();
    _floatingController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _rainbowAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _rainbowController, curve: Curves.linear));
    _floatingAnimation = Tween<double>(begin: -10.0, end: 10.0)
        .animate(CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut));

    _animationController.forward();
    _enableLocationIfNeeded();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _rainbowController.dispose();
    _floatingController.dispose();
    _posSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // helpers
  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _currentQ() {
    if (_useLocation && _lastPos != null) return '${_lastPos!.latitude},${_lastPos!.longitude}';
    final q = _controller.text.trim();
    return q.isEmpty ? 'Kochi' : q;
  }

  Future<void> _enableLocationIfNeeded() async {
    if (!_useLocation) return;
    final ok = await _ensureLocationPermission();
    if (!ok) return;
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _lastPos = pos;
    if (mounted) {
      context.read<WeatherBloc>().add(FetchWeatherByCoords(pos.latitude, pos.longitude));
    }
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 200),
    ).listen((p) {
      _lastPos = p;
      context.read<WeatherBloc>().add(FetchWeatherByCoords(p.latitude, p.longitude));
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { _snack('Turn on Location Services'); return false; }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) { perm = await Geolocator.requestPermission(); }
    if (perm == LocationPermission.denied) { _snack('Location permission denied'); return false; }
    if (perm == LocationPermission.deniedForever) { _snack('Permission permanently denied. Enable in Settings.'); return false; }
    return true;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF667eea),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 10,
    ));
  }

  void _fetchManual() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _useLocation = false);
    _posSub?.cancel();
    context.read<WeatherBloc>().add(FetchWeather(q));
  }

  void _refresh() => context.read<WeatherBloc>().add(const RefreshWeather());

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _rainbowAnimation,
          builder: (context, child) => ShaderMask(
            shaderCallback: (bounds) {
              final colors = [
                HSVColor.fromAHSV(1.0, (_rainbowAnimation.value * 360) % 360, 0.8, 1.0).toColor(),
                HSVColor.fromAHSV(1.0, ((_rainbowAnimation.value * 360) + 60) % 360, 0.8, 1.0).toColor(),
                HSVColor.fromAHSV(1.0, ((_rainbowAnimation.value * 360) + 120) % 360, 0.8, 1.0).toColor(),
                HSVColor.fromAHSV(1.0, ((_rainbowAnimation.value * 360) + 180) % 360, 0.8, 1.0).toColor(),
              ];
              return LinearGradient(colors: colors).createShader(bounds);
            },
            child: const Text(
              'Weather Studio ✨',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark),
        actions: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3CAC), Color(0xFFFFD95C), Color(0xFF00F5FF)],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF3CAC).withOpacity(0.4), blurRadius: 15, spreadRadius: 3, offset: const Offset(0, 5)),
                    BoxShadow(color: const Color(0xFF00F5FF).withOpacity(0.3), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, -2)),
                  ],
                ),
                child: IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb),
                Color(0xFFf5576c), Color(0xFF4facfe), Color(0xFF00f2fe)
              ],
              stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _enhancedAnimatedBackground(),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _enhancedSearchBar(),
                      _enhancedLocationToggle(),
                      _enhancedAdvancedPanel(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: BlocBuilder<WeatherBloc, WeatherState>(
                          builder: (context, state) {
                            if (state is WeatherLoading) return _enhancedLoading();
                            if (state is WeatherError) return _enhancedErrorCard(state.message);
                            if (state is WeatherLoaded) return _buildResults(state.data, state.source);
                            return _enhancedWelcomeCard();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced animated background
  Widget _enhancedAnimatedBackground() => Stack(children: [
    AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _floatingController]),
      builder: (context, child) => Stack(children: [
        Positioned(
          left: -80 + (_pulseAnimation.value - 1) * 25 + _floatingAnimation.value,
          top: -50 + (_pulseAnimation.value - 1) * 20,
          child: _enhancedAnimatedBlob(350, const Color(0xFF7C4DFF), 0.9),
        ),
        Positioned(
          right: -140 + (_pulseAnimation.value - 1) * 35 - _floatingAnimation.value * 0.8,
          top: 100 + (_pulseAnimation.value - 1) * 30,
          child: _enhancedAnimatedBlob(450, const Color(0xFFFFAB40), 0.7),
        ),
        Positioned(
          left: 40 + _floatingAnimation.value * 0.5,
          bottom: -120 + (_pulseAnimation.value - 1) * 25,
          child: _enhancedAnimatedBlob(300, const Color(0xFF26C6DA), 0.8),
        ),
        Positioned(
          right: 60 - _floatingAnimation.value * 0.3,
          bottom: 200 + (_pulseAnimation.value - 1) * 15,
          child: _enhancedAnimatedBlob(200, const Color(0xFFE91E63), 0.6),
        ),
        Positioned(
          left: MediaQuery.of(context).size.width * 0.3 + _floatingAnimation.value * 0.4,
          top: MediaQuery.of(context).size.height * 0.4 + (_pulseAnimation.value - 1) * 10,
          child: _enhancedAnimatedBlob(180, const Color(0xFF00E676), 0.5),
        ),
      ]),
    ),
    BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.05),
              Colors.black.withOpacity(0.1),
              Colors.black.withOpacity(0.05),
            ],
          ),
        ),
      ),
    ),
  ]);

  Widget _enhancedAnimatedBlob(double size, Color color, double intensity) => Container(
    height: size,
    width: size,
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [
          color.withOpacity(intensity * 0.9),
          color.withOpacity(intensity * 0.6),
          color.withOpacity(intensity * 0.3),
          color.withOpacity(intensity * 0.1),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ),
      shape: BoxShape.circle,
    ),
  );

  // Enhanced panel decoration
  BoxDecoration _enhancedPanelDeco() => BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Colors.white.withOpacity(0.25),
        Colors.white.withOpacity(0.15),
        Colors.white.withOpacity(0.1)
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    borderRadius: BorderRadius.circular(25),
    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.white.withOpacity(0.1),
        blurRadius: 20,
        spreadRadius: 2,
        offset: const Offset(0, 5),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        spreadRadius: 1,
        offset: const Offset(0, -2),
      ),
    ],
  );

  InputDecoration _enhancedInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 17, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: Colors.white.withOpacity(0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: Color(0xFF00F5FF), width: 3),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    prefixIcon: Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.9), size: 26),
    ),
  );

  Widget _enhancedGradientButton({required String label, required VoidCallback onTap, List<Color>? colors}) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colors ?? [const Color(0xFF667eea), const Color(0xFF764ba2), const Color(0xFFf093fb)],
        stops: const [0.0, 0.5, 1.0],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: (colors?.first ?? const Color(0xFF667eea)).withOpacity(0.5),
          blurRadius: 18,
          spreadRadius: 3,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.1),
          blurRadius: 5,
          spreadRadius: 1,
          offset: const Offset(0, -1),
        ),
      ],
    ),
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );

  Widget _enhancedSearchBar() => Container(
    padding: const EdgeInsets.all(6),
    decoration: _enhancedPanelDeco(),
    child: Row(children: [
      Expanded(
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
            decoration: _enhancedInputDecoration('🌍 Enter city, ZIP, or coordinates...'),
            onSubmitted: (_) => _fetchManual(),
          )),
      const SizedBox(width: 12),
      _enhancedGradientButton(
        label: 'Search',
        onTap: _fetchManual,
        colors: const [Color(0xFF00F5FF), Color(0xFF667eea), Color(0xFFFF3CAC)],
      ),
    ]),
  );

  Widget _enhancedLocationToggle() => Container(
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.all(8),
    decoration: _enhancedPanelDeco(),
    child: SwitchListTile.adaptive(
      value: _useLocation,
      onChanged: (v) async {
        setState(() => _useLocation = v);
        if (v) {
          await _enableLocationIfNeeded();
        } else {
          _posSub?.cancel();
        }
      },
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D), Color(0xFF4ECDC4)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.4), blurRadius: 8, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        const Text(
          'Real-time GPS Location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      activeColor: const Color(0xFF00F5FF),
      activeTrackColor: const Color(0xFF00F5FF).withOpacity(0.3),
    ),
  );

  // Enhanced Advanced Panel
// Enhanced Advanced Panel (scrollable body)
  Widget _enhancedAdvancedPanel() {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.white30),
      child: Container(
        decoration: _enhancedPanelDeco(),
        child: ExpansionTile(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          // we'll handle inner padding ourselves
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFFf093fb)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Advanced Settings ⚙️',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ],
          ),

          // ⬇️ Scrollable body
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                // tune this to how tall you want the open card to be
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _enhancedSubHeader('🌤️ Forecast (/forecast.json)'),
                      Row(children: [
                        Expanded(
                          child: _enhancedChipBox(
                            label: 'Days: $_days',
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF00F5FF),
                                inactiveTrackColor: Colors.white30,
                                thumbColor: const Color(0xFFFF3CAC),
                                overlayColor: const Color(0xFFFF3CAC).withOpacity(0.2),
                              ),
                              child: Slider(
                                min: 1,
                                max: 14,
                                divisions: 13,
                                value: _days.toDouble(),
                                onChanged: (v) => setState(() => _days = v.round()),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _enhancedDropdownBox<String>(
                          label: 'Lang',
                          value: _lang,
                          items: const ['en', 'hi', 'ml', 'ta', 'ar', 'es', 'fr', 'de', 'it', 'ru'],
                          onChanged: (v) => setState(() => _lang = v ?? 'en'),
                        ),
                      ]),
                      Row(children: [
                        Expanded(child: _enhancedToggleBox('Alerts', _alerts, (v) => setState(() => _alerts = v))),
                        const SizedBox(width: 12),
                        Expanded(child: _enhancedToggleBox('AQI', _aqi, (v) => setState(() => _aqi = v))),
                      ]),
                      Row(children: [
                        Expanded(child: _enhancedToggleBox('Use date', _useForecastDate, (v) => setState(() => _useForecastDate = v))),
                        if (_useForecastDate) const SizedBox(width: 12),
                        if (_useForecastDate)
                          Expanded(child: _enhancedDateButton('Pick date', _forecastDate, (d) => setState(() => _forecastDate = d))),
                      ]),
                      Row(children: [
                        Expanded(child: _enhancedToggleBox('Use hour', _useForecastHour, (v) => setState(() => _useForecastHour = v))),
                        if (_useForecastHour) const SizedBox(width: 12),
                        if (_useForecastHour)
                          Expanded(
                            child: _enhancedChipBox(
                              label: 'Hour: $_forecastHour',
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF00F5FF),
                                  inactiveTrackColor: Colors.white30,
                                  thumbColor: const Color(0xFFFF3CAC),
                                ),
                                child: Slider(
                                  min: 0,
                                  max: 23,
                                  divisions: 23,
                                  value: _forecastHour.toDouble(),
                                  onChanged: (v) => setState(() => _forecastHour = v.round()),
                                ),
                              ),
                            ),
                          ),
                      ]),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _enhancedGradientButton(
                          label: '🚀 Run Forecast',
                          colors: const [Color(0xFF667eea), Color(0xFF764ba2)],
                          onTap: () {
                            final q = _currentQ();
                            context.read<WeatherBloc>().add(FetchForecastAdvanced(
                              q: q,
                              days: _days,
                              lang: _lang,
                              alerts: _alerts,
                              aqi: _aqi,
                              dt: _useForecastDate ? _fmt(_forecastDate) : null,
                              hour: _useForecastHour ? _forecastHour : null,
                            ));
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _enhancedSubHeader('🔮 Future (/future.json)'),
                      Row(children: [
                        Expanded(child: _enhancedDateButton('Pick future date', _futureDate, (d) => setState(() => _futureDate = d))),
                        const SizedBox(width: 12),
                        _enhancedDropdownBox<String>(
                          label: 'Lang',
                          value: _lang,
                          items: const ['en', 'hi', 'ml', 'ta', 'ar', 'es', 'fr', 'de', 'it', 'ru'],
                          onChanged: (v) => setState(() => _lang = v ?? 'en'),
                        ),
                      ]),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _enhancedGradientButton(
                          label: '🔮 Run Future',
                          colors: const [Color(0xFFf093fb), Color(0xFFf5576c)],
                          onTap: () {
                            final q = _currentQ();
                            context.read<WeatherBloc>().add(
                              FetchFutureCustom(q: q, dt: _fmt(_futureDate), lang: _lang),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _enhancedSubHeader('📚 History (/history.json)'),
                      Row(children: [
                        Expanded(child: _enhancedDateButton('Start (dt)', _historyStart, (d) => setState(() => _historyStart = d))),
                        const SizedBox(width: 12),
                        Expanded(child: _enhancedToggleBox('Use end_dt', _useHistoryEnd, (v) => setState(() => _useHistoryEnd = v))),
                      ]),
                      if (_useHistoryEnd)
                        Row(children: [
                          Expanded(child: _enhancedDateButton('End (end_dt)', _historyEnd, (d) => setState(() => _historyEnd = d))),
                          const SizedBox(width: 12),
                          Expanded(child: _enhancedToggleBox('Use hour', _useHistoryHour, (v) => setState(() => _useHistoryHour = v))),
                        ])
                      else
                        Row(children: [
                          Expanded(child: _enhancedToggleBox('Use hour', _useHistoryHour, (v) => setState(() => _useHistoryHour = v))),
                        ]),
                      if (_useHistoryHour)
                        _enhancedChipBox(
                          label: 'Hour: $_historyHour',
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF00F5FF),
                              inactiveTrackColor: Colors.white30,
                              thumbColor: const Color(0xFFFF3CAC),
                            ),
                            child: Slider(
                              min: 0,
                              max: 23,
                              divisions: 23,
                              value: _historyHour.toDouble(),
                              onChanged: (v) => setState(() => _historyHour = v.round()),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _enhancedGradientButton(
                          label: '📚 Run History',
                          colors: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
                          onTap: () {
                            final q = _currentQ();
                            context.read<WeatherBloc>().add(FetchHistoryRange(
                              q: q,
                              dt: _fmt(_historyStart),
                              endDt: _useHistoryEnd ? _fmt(_historyEnd) : null,
                              hour: _useHistoryHour ? _historyHour : null,
                              lang: _lang,
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced helpers for Advanced panel
  Widget _enhancedSubHeader(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 12),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF3CAC), Color(0xFF00F5FF)]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      ],
    ),
  );

  Widget _enhancedToggleBox(String label, bool value, ValueChanged<bool> onChanged) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 8, spreadRadius: 1),
      ],
    ),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16))),
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00F5FF),
        activeTrackColor: const Color(0xFF00F5FF).withOpacity(0.3),
        inactiveThumbColor: Colors.white70,
        inactiveTrackColor: Colors.white30,
      ),
    ]),
  );

  Widget _enhancedChipBox({required String label, required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 8, spreadRadius: 1),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 8),
      child,
    ]),
  );

  Widget _enhancedDropdownBox<T>({required String label, required T value, required List<T> items, required ValueChanged<T?> onChanged}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Row(children: [
          Text('$label: ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<T>(
              value: value,
              dropdownColor: const Color(0xFF1F2937),
              items: items
                  .map((e) => DropdownMenuItem<T>(
                value: e,
                child: Text('$e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ))
                  .toList(),
              onChanged: onChanged,
              underline: const SizedBox.shrink(),
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      );

  Widget _enhancedDateButton(String label, DateTime current, ValueChanged<DateTime> onPicked) => _enhancedGradientButton(
    label: '$label • ${_fmt(current)}',
    colors: const [Color(0xFFf093fb), Color(0xFFf5576c), Color(0xFF667eea)],
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2015, 1, 1),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF667eea),
              onPrimary: Colors.white,
              surface: Color(0xFF1F2937),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
      if (d != null) onPicked(d);
    },
  );

  // ===================== RESULTS + CARDS =====================

  Widget _buildResults(Map<String, dynamic> data, String source) {
    Map<String, dynamic>? mapOf(dynamic x) => x is Map<String, dynamic> ? x : null;
    final current = mapOf(data['current']);
    final forecast = mapOf(data['forecast']);
    final astronomy = mapOf(data['astronomy']);
    final timezone = mapOf(data['timezone']);
    final history = mapOf(data['history']);
    final future = mapOf(data['future']);
    final marine = mapOf(data['marine']);

    final advForecast = mapOf(data['advForecast']);
    final futureCustom = mapOf(data['futureCustom']);
    final historyCustom = mapOf(data['historyCustom']);

    final loc = current?['location'] as Map<String, dynamic>?;
    final cur = current?['current'] as Map<String, dynamic>?;
    final fcDays = (forecast?['forecast']?['forecastday'] as List?) ?? const [];
    final alerts = (forecast?['alerts']?['alert'] as List?) ?? const [];
    final hours = (fcDays.isNotEmpty ? (fcDays[0]['hour'] as List?) : const []) ?? const [];

    return ListView(
      children: [
        if (loc != null && cur != null) _enhancedCurrentCard(loc, cur, source),
        if (hours.isNotEmpty) _enhancedHourlyStrip(hours),
        if (fcDays.isNotEmpty) _enhancedForecastList(fcDays),
        if (alerts.isNotEmpty) _enhancedAlertsList(alerts),
        if (astronomy?['astronomy']?['astro'] != null) _enhancedAstroCard(astronomy!['astronomy']['astro']),
        _enhancedMarineCard(marine),
        if (advForecast != null) _enhancedAdvForecastCard(advForecast),
        if (futureCustom != null) _enhancedFutureCard(futureCustom),
        if (historyCustom != null) _enhancedHistoryCard(historyCustom),
        if (timezone?['location'] != null) _enhancedTimezoneCard(timezone!['location']),
        if (history?['forecast'] != null) _enhancedYesterday(history!),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _enhancedCurrentCard(Map<String, dynamic> loc, Map<String, dynamic> cur, String source) =>
      _enhancedColorfulSection(
        title: '${loc['name']} • ${source == 'coords' ? 'GPS' : 'Search'}',
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          stops: [0.0, 0.5, 1.0],
        ),
        child: Column(children: [
          Row(children: [
            if (cur['condition']?['icon'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.15)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https:${cur['condition']['icon']}',
                    width: 72,
                    height: 72,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.wb_cloudy, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 20),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AnimatedBuilder(
                    animation: _rainbowAnimation,
                    builder: (context, child) => ShaderMask(
                      shaderCallback: (b) {
                        final colors = [
                          HSVColor.fromAHSV(1.0, (_rainbowAnimation.value * 360) % 360, 0.3, 1.0).toColor(),
                          Colors.white,
                          HSVColor.fromAHSV(1.0, ((_rainbowAnimation.value * 360) + 60) % 360, 0.3, 1.0).toColor(),
                        ];
                        return LinearGradient(colors: colors).createShader(b);
                      },
                      child: Text(
                        '${cur['temp_c']}°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cur['condition']?['text'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ])),
          ]),
          const SizedBox(height: 20),
          _enhancedWeatherMetrics(cur),
        ]),
      );

  Widget _enhancedHourlyStrip(List hours) => _enhancedColorfulSection(
    title: 'Today\'s Hourly Forecast',
    gradient: const LinearGradient(
      colors: [Color(0xFFf093fb), Color(0xFFf5576c), Color(0xFFFFAB40)],
      stops: [0.0, 0.6, 1.0],
    ),
    child: SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length.clamp(0, 12),
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final h = hours[i];
          final time = (h['time'] ?? '').toString().split(' ').last;
          final icon = h['condition']?['icon'];
          return AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _floatingAnimation.value * 0.3),
              child: Container(
                width: 110,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (icon != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 4, spreadRadius: 1),
                        ],
                      ),
                      child: Image.network(
                        'https:$icon',
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.wb_cloudy, color: Colors.white, size: 40),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '${h['temp_c']}°C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    ),
  );

  // ===== Your requested enhanced sections =====

  Widget _enhancedForecastList(List fcDays) => _enhancedColorfulSection(
    title: '${fcDays.length}-Day Forecast',
    gradient: const LinearGradient(
      colors: [Color(0xFF4facfe), Color(0xFF00f2fe), Color(0xFF667eea)],
      stops: [0.0, 0.5, 1.0],
    ),
    child: Column(
      children: fcDays.take(3).map<Widget>((d) {
        final day = d['day'] ?? {};
        final cond = day['condition'] ?? {};
        return AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) => Transform.translate(
            offset: Offset(_floatingAnimation.value * 0.2, 0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 15,
                    spreadRadius: 3,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(children: [
                if (cond['icon'] != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 6, spreadRadius: 1)],
                    ),
                    child: Image.network(
                      'https:${cond['icon']}',
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.wb_cloudy, color: Colors.white, size: 48),
                    ),
                  ),
                const SizedBox(width: 20),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '${d['date']}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${cond['text'] ?? ''}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${day['maxtemp_c']}°',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day['mintemp_c']}°',
                    style:
                    TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _enhancedAlertsList(List alerts) => _enhancedColorfulSection(
    title: 'Weather Alerts',
    gradient: const LinearGradient(
      colors: [Color(0xFFff6b6b), Color(0xFFff8e53), Color(0xFFFFAB40)],
      stops: [0.0, 0.7, 1.0],
    ),
    child: Column(
      children: alerts.take(2).map<Widget>((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFff6b6b).withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${a['headline'] ?? a['event'] ?? 'Alert'}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${a['desc'] ?? ''}',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ]),
        );
      }).toList(),
    ),
  );

  Widget _enhancedAstroCard(Map<String, dynamic> astro) => _enhancedColorfulSection(
    title: 'Sun & Moon',
    gradient: const LinearGradient(
      colors: [Color(0xFFfff3e0), Color(0xFFffb74d), Color(0xFFff9800)],
      stops: [0.0, 0.6, 1.0],
    ),
    child: _enhancedAstronomyWidget(astro),
  );

  Widget _enhancedMarineCard(Map<String, dynamic>? marine) => _enhancedColorfulSection(
    title: 'Marine Conditions',
    gradient: const LinearGradient(
      colors: [Color(0xFF26c6da), Color(0xFF00bcd4), Color(0xFF0097a7)],
      stops: [0.0, 0.5, 1.0],
    ),
    child: (marine == null || marine['_error'] != null)
        ? Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.info_outline, color: Colors.white.withOpacity(0.9), size: 28),
      ),
      const SizedBox(width: 16),
      const Expanded(
        child: Text(
          'Not available for this location',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      )
    ])
        : Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF26c6da), Color(0xFF00bcd4)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: const Color(0xFF26c6da).withOpacity(0.3), blurRadius: 8, spreadRadius: 2),
          ],
        ),
        child: const Icon(Icons.waves, color: Colors.white, size: 28),
      ),
      const SizedBox(width: 16),
      const Expanded(
        child: Text(
          'Marine data available',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    ]),
  );

  Widget _enhancedAdvForecastCard(Map<String, dynamic> afc) {
    final fcDays = (afc['forecast']?['forecastday'] as List?) ?? const [];
    final alerts = (afc['alerts']?['alert'] as List?) ?? const [];
    return _enhancedColorfulSection(
      title: 'Advanced Forecast',
      gradient: const LinearGradient(
        colors: [Color(0xFF00c9ff), Color(0xFF92fe9d), Color(0xFF00f2fe)],
        stops: [0.0, 0.5, 1.0],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (fcDays.isEmpty)
          const Text(
            'No forecast data',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ...fcDays.take(5).map((d) {
          final day = d['day'] ?? {};
          final cond = day['condition'] ?? {};
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                if (cond['icon'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https:${cond['icon']}',
                      width: 44,
                      height: 44,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.wb_cloudy, color: Colors.white, size: 44),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d['date']}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Min ${day['mintemp_c']}°C / Max ${day['maxtemp_c']}°C • ${cond['text'] ?? ''}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (alerts.isNotEmpty) const SizedBox(height: 12),
        if (alerts.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFff6b6b).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFff6b6b).withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alerts:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ...alerts.take(3).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${a['event'] ?? a['headline']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                )),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _enhancedFutureCard(Map<String, dynamic> f) {
    final days = (f['forecast']?['forecastday'] as List?) ?? const [];
    final d0 = days.isNotEmpty ? days[0] : null;
    final text = d0?['day']?['condition']?['text'] ?? '—';
    final temp = d0?['day']?['avgtemp_c'];
    return _enhancedColorfulSection(
      title: 'Future (custom date)',
      gradient: const LinearGradient(
        colors: [Color(0xFF536976), Color(0xFF292e49), Color(0xFF667eea)],
        stops: [0.0, 0.6, 1.0],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF536976), Color(0xFF292e49)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Condition: $text',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                if (temp != null)
                  Text('Average: ${temp}°C',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _enhancedHistoryCard(Map<String, dynamic> hist) {
    final f = hist['forecast'] as Map<String, dynamic>?;
    final fdays = (f?['forecastday'] as List?) ?? const [];
    return _enhancedColorfulSection(
      title: 'History (custom)',
      gradient: const LinearGradient(
        colors: [Color(0xFF1e3c72), Color(0xFF2a5298), Color(0xFF667eea)],
        stops: [0.0, 0.5, 1.0],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fdays.take(5).map<Widget>((d) {
          final day = d['day'] ?? {};
          final cond = day['condition'] ?? {};
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                if (cond['icon'] != null)
                  Image.network('https:${cond['icon']}', width: 36, height: 36, errorBuilder: (_, __, ___) {
                    return const Icon(Icons.wb_cloudy, color: Colors.white70, size: 36);
                  }),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${d['date']} • ${cond['text'] ?? ''}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                Text('Avg ${day['avgtemp_c']}°C',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _enhancedTimezoneCard(Map<String, dynamic> location) => _enhancedColorfulSection(
    title: 'Time Zone Info',
    gradient: const LinearGradient(
      colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
    ),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.access_time_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('Timezone: ${location['tz_id']}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('Local: ${location['localtime']}',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
        ]),
      ]),
    ),
  );

  Widget _enhancedYesterday(Map<String, dynamic> history) {
    final day = history['forecast']?['forecastday']?[0]?['day'];
    final avg = day?['avgtemp_c'];
    return _enhancedColorfulSection(
      title: 'Yesterday',
      gradient: const LinearGradient(colors: [Color(0xFF795548), Color(0xFFBCAAA4)]),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration:
              BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Average Temperature',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(avg != null ? '$avg°C' : '--',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
            ]),
          ],
        ),
      ),
    );
  }

  // ===== common section shell
  Widget _enhancedColorfulSection({
    required String title,
    required Widget child,
    required LinearGradient gradient,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                  ),
                ]),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== metrics & helper cards
  Widget _enhancedWeatherMetrics(Map<String, dynamic> cur) {
    String _fmtNum(dynamic v) => v == null ? '--' : '$v';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _metricItem(
              icon: Icons.thermostat_rounded,
              label: 'Feels like',
              value: '${_fmtNum(cur['feelslike_c'])}°C',
              color: const Color(0xFFFF6B6B),
            ),
          ),
          Expanded(
            child: _metricItem(
              icon: Icons.water_drop_rounded,
              label: 'Humidity',
              value: '${_fmtNum(cur['humidity'])}%',
              color: const Color(0xFF4FACFE),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _metricItem(
              icon: Icons.air_rounded,
              label: 'Wind',
              value: '${_fmtNum(cur['wind_kph'])} kph',
              color: const Color(0xFF4ECDC4),
            ),
          ),
          Expanded(
            child: _metricItem(
              icon: Icons.compress,
              label: 'Pressure',
              value: '${_fmtNum(cur['pressure_mb'])} mb',
              color: const Color(0xFF26C6DA),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _metricItem(
              icon: Icons.visibility_rounded,
              label: 'Visibility',
              value: '${_fmtNum(cur['vis_km'])} km',
              color: const Color(0xFF00BCD4),
            ),
          ),
          Expanded(
            child: _metricItem(
              icon: Icons.light_mode_rounded,
              label: 'UV',
              value: '${_fmtNum(cur['uv'])}',
              color: const Color(0xFFFFC107),
            ),
          ),
        ]),
        if (cur['air_quality'] != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _metricItem(
                icon: Icons.eco_rounded,
                label: 'Air Quality',
                value: 'US-EPA ${_fmtNum(cur['air_quality']['us-epa-index'])}',
                color: const Color(0xFF00E676),
              ),
            ),
            Expanded(
              child: _metricItem(
                icon: Icons.grain_rounded,
                label: 'PM2.5',
                value: '${_fmtNum(cur['air_quality']['pm2_5'])}',
                color: const Color(0xFF8E24AA),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _metricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _enhancedAstronomyWidget(Map<String, dynamic> astro) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFFFA726)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            const Text('Sunrise',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              '${astro['sunrise'] ?? '--'}',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
        Container(height: 60, width: 1, color: Colors.white.withOpacity(0.3)),
        Expanded(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFFF5722)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.wb_twilight_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            const Text('Sunset',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              '${astro['sunset'] ?? '--'}',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
      ]),
    );
  }

  // ===== loading / error / welcome =====
  Widget _enhancedLoading() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4FACFE)),
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Fetching weather data...',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );

  Widget _enhancedErrorCard(String message) => Center(
    child: Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.2),
            const Color(0xFFFF8E53).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3), width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ]),
    ),
  );

  Widget _enhancedWelcomeCard() => Center(
    child: Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration:
          BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)]), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 20),
        const Text(
          'Welcome to Weather Studio!',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enable location or search for a city to get started',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ]),
    ),
  );
}
