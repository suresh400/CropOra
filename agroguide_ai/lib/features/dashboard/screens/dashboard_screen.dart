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
import '../../../services/database_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/glass_container.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoadingReminders = true;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoadingReminders = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final trackedIds = prefs.getStringList('tracked_crops') ?? [];
    
    final allReminders = await dbService.getReminders();
    if (mounted) {
      setState(() {
        _reminders = allReminders.where((r) => trackedIds.contains(r['id'].toString())).toList();
        _isLoadingReminders = false;
      });
    }
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              );
              _loadReminders();
            },
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
        onRefresh: () async {
          await _fetchWeather();
          await _loadReminders();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _openWeatherDetails,
                child: _buildFarmHealthCard(context),
              ).animate().fade(duration: 800.ms, curve: Curves.easeOut).slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
              if (!_isLoadingReminders && _reminders.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Active Crops',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ).animate().fade(delay: 150.ms),
                const SizedBox(height: 12),
                _buildActiveCropsTracking(),
              ],
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
                    icon: PhosphorIconsFill.plant,
                    color: Colors.green.shade100,
                    iconColor: Colors.green.shade800,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecommendationsScreen(initialIndex: 0)),
                    ),
                  ).animate().fade(delay: 300.ms).scale(curve: Curves.easeOutBack),
                  _buildActionCard(
                    context,
                    title: TranslationService.translate(context, 'fertilizer'),
                    icon: PhosphorIconsFill.flask,
                    color: Colors.blue.shade100,
                    iconColor: Colors.blue.shade800,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecommendationsScreen(initialIndex: 1)),
                    ),
                  ).animate().fade(delay: 400.ms).scale(curve: Curves.easeOutBack),
                  _buildActionCard(
                    context,
                    title: TranslationService.translate(context, 'weather'),
                    icon: PhosphorIconsFill.cloudSun,
                    color: Colors.orange.shade100,
                    iconColor: Colors.orange.shade800,
                    onTap: _openWeatherDetails,
                  ).animate().fade(delay: 500.ms).scale(curve: Curves.easeOutBack),
                  _buildActionCard(
                    context,
                    title: 'Active Crops',
                    icon: PhosphorIconsFill.plant,
                    color: Colors.purple.shade100,
                    iconColor: Colors.purple.shade800,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RemindersScreen()),
                      );
                      _loadReminders();
                    },
                  ).animate().fade(delay: 600.ms).scale(curve: Curves.easeOutBack),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: GlassContainer(
        blur: 20,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsFill.mapPin, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _weatherData != null ? _weatherData!['city'] ?? 'My Farm' : 'Detecting Location...',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(PhosphorIconsFill.checkCircle, color: Colors.lightGreenAccent, size: 16),
                      SizedBox(width: 4),
                      Text('Optimal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _weatherData != null
                  ? (_weatherData!['condition'] ?? TranslationService.translate(context, 'optimal_status'))
                  : TranslationService.translate(context, 'optimal_status'),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            if (_weatherData?['description'] != null)
              Text(
                (_weatherData!['description'] as String).toUpperCase(),
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, letterSpacing: 1),
              ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHealthStat(
                  PhosphorIconsFill.thermometerHot,
                  TranslationService.translate(context, 'temp'),
                  _isLoadingWeather ? '...' : '${_weatherData?['temperature'] ?? 28}°C',
                ),
                _buildHealthStat(
                  PhosphorIconsFill.drop,
                  TranslationService.translate(context, 'humidity'),
                  _isLoadingWeather ? '...' : '${_weatherData?['humidity'] ?? 65}%',
                ),
                _buildHealthStat(
                  PhosphorIconsFill.wind,
                  'Wind',
                  _isLoadingWeather ? '...' : '${_weatherData?['wind_speed'] ?? '--'} m/s',
                ),
                _buildHealthStat(
                  PhosphorIconsFill.mountains,
                  TranslationService.translate(context, 'soil'),
                  'Good',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500)),
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
      borderRadius: BorderRadius.circular(24),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withOpacity(0.4),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.8), 
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCropsTracking() {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          final crop = reminder['crop_type'] ?? 'Crop';
          final days = reminder['cultivation_days'] ?? 0;
          final timestamp = reminder['timestamp'] as String?;

          int daysCompleted = 0;
          if (timestamp != null) {
            try {
              daysCompleted = DateTime.now().difference(DateTime.parse(timestamp)).inDays;
              if (daysCompleted < 0) daysCompleted = 0;
              if (daysCompleted > days) daysCompleted = days;
            } catch (_) {}
          }
          final progress = days > 0 ? daysCompleted / days : 0.0;

          return Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentBrown,
                    AppColors.earthDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBrown.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: GlassContainer(
                blur: 20,
                opacity: 0.15,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(PhosphorIconsFill.plant, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              crop,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$daysCompleted / $days Days',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.black.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.amberAccent : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cultivation Phase',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                        Text(
                          progress < 0.33 ? 'Initial' : (progress < 0.66 ? 'Vegetative' : (progress >= 1.0 ? 'Harvest Ready' : 'Flowering/Fruiting')),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ).animate().fade(delay: (200 + index * 100).ms).slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }
}


