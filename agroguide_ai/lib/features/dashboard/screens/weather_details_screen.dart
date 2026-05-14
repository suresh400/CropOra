import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_service.dart';
import 'package:provider/provider.dart';

class WeatherDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const WeatherDetailsScreen({super.key, this.initialData});

  @override
  State<WeatherDetailsScreen> createState() => _WeatherDetailsScreenState();
}

class _WeatherDetailsScreenState extends State<WeatherDetailsScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _data = widget.initialData;
    } else {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final position = await notificationService.getCurrentLocation();

      if (position != null) {
        final weather = await apiService.getWeather(position.latitude, position.longitude);
        if (mounted) setState(() { _data = weather; _isLoading = false; });
      } else {
        // Use fallback simulated data
        final weather = await apiService.getWeather(0, 0);
        if (mounted) {
          setState(() {
            _data = weather;
            _isLoading = false;
            _errorMessage = 'Location unavailable. Showing estimated data.';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  String _getWindDirection(int deg) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[((deg / 45) % 8).round() % 8];
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  IconData _getWeatherIcon(String? condition) {
    switch ((condition ?? '').toLowerCase()) {
      case 'clear': return PhosphorIconsFill.sun;
      case 'clouds': return PhosphorIconsFill.cloud;
      case 'rain': case 'drizzle': return PhosphorIconsFill.cloudRain;
      case 'thunderstorm': return PhosphorIconsFill.cloudLightning;
      case 'snow': return PhosphorIconsFill.snowflake;
      case 'mist': case 'fog': case 'haze': return PhosphorIconsFill.cloudFog;
      default: return PhosphorIconsFill.cloudSun;
    }
  }

  Color _getWeatherColor(String? condition) {
    switch ((condition ?? '').toLowerCase()) {
      case 'clear': return Colors.orange.shade700;
      case 'clouds': return Colors.blueGrey.shade600;
      case 'rain': case 'drizzle': return Colors.blue.shade700;
      case 'thunderstorm': return Colors.deepPurple.shade700;
      case 'snow': return Colors.lightBlue.shade300;
      default: return AppColors.primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final condition = _data?['condition'] as String?;
    final headerColor = _getWeatherColor(condition);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: headerColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerColor, headerColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _buildHeroSection(),
              ),
            ),
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(PhosphorIconsRegular.arrowClockwise, color: Colors.white),
                onPressed: _fetchWeather,
              ),
            ],
          ),
          if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ),
          if (_data != null) ...[
            SliverToBoxAdapter(child: _buildDetailsGrid()),
            SliverToBoxAdapter(child: _buildSunriseSunsetCard()),
            SliverToBoxAdapter(child: _buildFarmingInsightsCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
          if (!_isLoading && _data == null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.cloudSlash, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('Could not load weather data', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchWeather,
                      icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final temp = _data?['temperature'] ?? '--';
    final feelsLike = _data?['feels_like'] ?? '--';
    final tempMin = _data?['temp_min'] ?? '--';
    final tempMax = _data?['temp_max'] ?? '--';
    final city = _data?['city'] ?? 'My Farm';
    final country = _data?['country'] ?? '';
    final condition = _data?['condition'] ?? 'Weather';
    final description = _data?['description'] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.mapPin, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text('$city${country.isNotEmpty ? ", $country" : ""}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(_getWeatherIcon(condition), color: Colors.white, size: 64),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$temp°C',
                      style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold, height: 1)),
                  Text(description.toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
                ],
              ),
            ],
          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat('Feels Like', '$feelsLike°C'),
              const SizedBox(width: 24),
              _buildMiniStat('L: $tempMin°', 'H: $tempMax°'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDetailsGrid() {
    final humidity = _data?['humidity'] ?? '--';
    final pressure = _data?['pressure'] ?? '--';
    final windSpeed = _data?['wind_speed'] ?? '--';
    final windDeg = _data?['wind_deg'] ?? 0;
    final visibility = _data?['visibility'] ?? '--';
    final clouds = _data?['clouds'] ?? '--';

    final items = [
      _WeatherDetailItem(icon: PhosphorIconsFill.drop, label: 'Humidity', value: '$humidity%', color: Colors.blue),
      _WeatherDetailItem(icon: PhosphorIconsFill.wind, label: 'Wind', value: '$windSpeed m/s ${_getWindDirection(windDeg)}', color: Colors.teal),
      _WeatherDetailItem(icon: PhosphorIconsFill.gauge, label: 'Pressure', value: '$pressure hPa', color: Colors.purple),
      _WeatherDetailItem(icon: PhosphorIconsFill.eye, label: 'Visibility', value: '$visibility km', color: Colors.indigo),
      _WeatherDetailItem(icon: PhosphorIconsFill.cloud, label: 'Cloud Cover', value: '$clouds%', color: Colors.blueGrey),
      _WeatherDetailItem(icon: PhosphorIconsFill.thermometerHot, label: 'Feels Like', value: '${_data?['feels_like'] ?? '--'}°C', color: Colors.orange),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Conditions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, i) {
              final item = items[i];
              return Container(
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: item.color.withOpacity(0.2)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: item.color, size: 28),
                    const SizedBox(height: 6),
                    Text(item.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: item.color, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(item.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ).animate().fade(delay: (i * 60).ms).scale(delay: (i * 60).ms);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSunriseSunsetCard() {
    final sunrise = _data?['sunrise'] ?? 0;
    final sunset = _data?['sunset'] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark ? Colors.orange.shade900.withOpacity(0.2) : Colors.orange.shade100, 
              isDark ? Colors.purple.shade900.withOpacity(0.2) : Colors.purple.shade100
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.orange.shade800 : Colors.orange.shade200),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sun Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSunTimeItem(
                  PhosphorIconsFill.sun,
                  'Sunrise',
                  sunrise > 0 ? _formatTime(sunrise) : '06:12',
                  Colors.orange.shade700,
                ),
                Container(
                  height: 50,
                  width: 1,
                  color: isDark ? Colors.orange.shade800 : Colors.orange.shade200,
                ),
                _buildSunTimeItem(
                  PhosphorIconsFill.moon,
                  'Sunset',
                  sunset > 0 ? _formatTime(sunset) : '18:45',
                  Colors.deepPurple.shade400,
                ),
              ],
            ),
          ],
        ),
      ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildSunTimeItem(IconData icon, String label, String time, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 4),
        Text(time, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildFarmingInsightsCard() {
    final temp = (_data?['temperature'] ?? 28) as num;
    final humidity = (_data?['humidity'] ?? 65) as num;
    final windSpeed = (_data?['wind_speed'] ?? 4) as num;
    final condition = _data?['condition'] ?? 'Clear';

    final insights = <String>[];
    if (temp > 35) {
      insights.add('🌡️ High temperature — water crops early morning or evening to reduce evaporation.');
    } else if (temp < 15) {
      insights.add('❄️ Cool temperature — protect sensitive plants from frost at night.');
    } else {
      insights.add('✅ Temperature is in an ideal range for most crops right now.');
    }

    if (humidity > 80) {
      insights.add('💧 High humidity — risk of fungal disease. Ensure proper ventilation.');
    } else if (humidity < 30) {
      insights.add('🏜️ Very dry conditions — increase irrigation frequency.');
    } else {
      insights.add('✅ Humidity levels are good for plant health and growth.');
    }

    if (condition.toLowerCase().contains('rain')) {
      insights.add('🌧️ Rain expected — delay pesticide application to avoid washout.');
    } else if (windSpeed > 10) {
      insights.add('💨 Strong winds — secure tall crops and avoid spraying chemicals.');
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.green.shade900.withOpacity(0.15) : Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.green.shade800 : Colors.green.shade200),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsFill.plant, color: isDark ? Colors.green.shade400 : Colors.green.shade700, size: 22),
                const SizedBox(width: 8),
                const Text('Farming Insights',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(insight, style: const TextStyle(fontSize: 13, height: 1.4)),
            )),
          ],
        ),
      ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
    );
  }
}

class _WeatherDetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _WeatherDetailItem({required this.icon, required this.label, required this.value, required this.color});
}
