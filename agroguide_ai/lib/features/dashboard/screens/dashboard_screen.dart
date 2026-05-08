import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../notifications/notifications_screen.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/notification_storage.dart';
import '../../../services/translation_service.dart';
import '../../crop_recommendation/screens/recommendations_screen.dart';
import 'weather_details_screen.dart';
import 'reminders_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() => _isLoadingWeather = true);
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final position = await notificationService.getCurrentLocation();
      if (position != null) {
        final weather = await apiService.getWeather(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _weatherData = weather;
            _isLoadingWeather = false;
          });
        }
      } else {
        // Load simulated weather so the card always shows data
        final weather = await apiService.getWeather(0, 0);
        if (mounted) {
          setState(() {
            _weatherData = weather;
            _isLoadingWeather = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  void _openWeatherDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeatherDetailsScreen(initialData: _weatherData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(TranslationService.translate(context, 'app_title')),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.calendarCheck),
            tooltip: 'Reminders',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: Hive.box<Map>(NotificationStorage.boxName).listenable(),
            builder: (context, box, child) {
              final unreadCount = Provider.of<NotificationStorage>(context, listen: false).getUnreadCount();
              return Badge(
                label: Text(unreadCount.toString()),
                isLabelVisible: unreadCount > 0,
                child: IconButton(
                  icon: const Icon(PhosphorIconsRegular.bell),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWeather,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _openWeatherDetails,
                child: _buildFarmHealthCard(context),
              ).animate().fade(duration: 500.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),
              Text(
                TranslationService.translate(context, 'quick_actions'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fade(delay: 200.ms),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    title: TranslationService.translate(context, 'crop_suggest'),
                    icon: PhosphorIconsRegular.plant,
                    color: Colors.green.shade100,
                    iconColor: Colors.green.shade800,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecommendationsScreen(initialIndex: 0)),
                    ),
                  ).animate().fade(delay: 300.ms).scale(),
                  _buildActionCard(
                    context,
                    title: TranslationService.translate(context, 'fertilizer'),
                    icon: PhosphorIconsRegular.flask,
                    color: Colors.blue.shade100,
                    iconColor: Colors.blue.shade800,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecommendationsScreen(initialIndex: 1)),
                    ),
                  ).animate().fade(delay: 400.ms).scale(),
                  _buildActionCard(
                    context,
                    title: TranslationService.translate(context, 'weather'),
                    icon: PhosphorIconsRegular.cloudSun,
                    color: Colors.orange.shade100,
                    iconColor: Colors.orange.shade800,
                    onTap: _openWeatherDetails,
                  ).animate().fade(delay: 500.ms).scale(),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmHealthCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.mapPin, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _weatherData != null ? _weatherData!['city'] ?? 'My Farm' : 'Detecting Location...',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(PhosphorIconsFill.checkCircle, color: Colors.lightGreenAccent),
                  const SizedBox(width: 6),
                  const Icon(PhosphorIconsRegular.arrowRight, color: Colors.white54, size: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _weatherData != null
                ? (_weatherData!['condition'] ?? TranslationService.translate(context, 'optimal_status'))
                : TranslationService.translate(context, 'optimal_status'),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (_weatherData?['description'] != null)
            Text(
              (_weatherData!['description'] as String).toUpperCase(),
              style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHealthStat(
                PhosphorIconsRegular.thermometerHot,
                TranslationService.translate(context, 'temp'),
                _isLoadingWeather ? '...' : '${_weatherData?['temperature'] ?? 28}°C',
              ),
              _buildHealthStat(
                PhosphorIconsRegular.drop,
                TranslationService.translate(context, 'humidity'),
                _isLoadingWeather ? '...' : '${_weatherData?['humidity'] ?? 65}%',
              ),
              _buildHealthStat(
                PhosphorIconsRegular.wind,
                'Wind',
                _isLoadingWeather ? '...' : '${_weatherData?['wind_speed'] ?? '--'} m/s',
              ),
              _buildHealthStat(
                PhosphorIconsRegular.mountains,
                TranslationService.translate(context, 'soil'),
                'Good',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}


