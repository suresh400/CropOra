import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/api_service.dart';
import '../../../../services/database_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/translation_service.dart';
import '../../../../services/recommendations_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CropRecommendationForm extends StatefulWidget {
  const CropRecommendationForm({super.key});

  @override
  State<CropRecommendationForm> createState() => _CropRecommendationFormState();
}

class _CropRecommendationFormState extends State<CropRecommendationForm> {
  double _n = 50;
  double _p = 50;
  double _k = 50;
  double _temp = 25;
  double _humidity = 60;
  double _rainfall = 100;
  double _ph = 6.5;

  bool _isLoading = false;
  List<Map<String, dynamic>>? _results;

  // Index of currently visible crop (0, 1, 2)
  int _visibleCount = 1;

  // Per-crop fertilizer loading / result state
  final Map<int, bool> _isLoadingFertilizer = {};
  final Map<int, Map<String, dynamic>?> _fertilizerResults = {};

  // Per-crop reminder scheduling state
  final Map<int, bool> _isSchedulingReminder = {};
  final Map<int, bool> _reminderDone = {};

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    try {
      final position = await notificationService.getCurrentLocation();
      if (position != null) {
        final weather = await apiService.getWeather(position.latitude, position.longitude);
        if (mounted && weather.isNotEmpty) {
          setState(() {
            if (weather.containsKey('temperature')) {
              _temp = (weather['temperature'] as num).toDouble().clamp(0.0, 50.0);
            }
            if (weather.containsKey('humidity')) {
              _humidity = (weather['humidity'] as num).toDouble().clamp(0.0, 100.0);
            }
          });
        }
      }
    } catch (e) {
      // Graceful fallback: maintain default values if offline or error occurs
      debugPrint('Failed to fetch real-time weather: $e');
    }
  }

  Map<String, dynamic> get _inputData => {
    'N': _n, 'P': _p, 'K': _k,
    'temperature': _temp,
    'humidity': _humidity,
    'rainfall': _rainfall,
    'ph': _ph,
  };

  void _submitData() async {
    setState(() {
      _isLoading = true;
      _visibleCount = 1;
      _isLoadingFertilizer.clear();
      _fertilizerResults.clear();
      _isSchedulingReminder.clear();
      _reminderDone.clear();
    });
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    try {
      final topCrops = RecommendationsService.recommendTopCrops(_inputData);
      if (mounted) {
        setState(() {
          _results = topCrops;
          _isLoading = false;
        });
        if (topCrops.isNotEmpty) {
          await dbService.insertHistory('crop', _inputData, topCrops.first);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _checkFertilizer(int index, String cropName) async {
    setState(() => _isLoadingFertilizer[index] = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final fertData = {
      'N': _n, 'P': _p, 'K': _k,
      'temperature': _temp,
      'humidity': _humidity,
      'rainfall': _rainfall,
      'ph': _ph,
      'Nitrogen_Level': _n,
      'Phosphorus_Level': _p,
      'Potassium_Level': _k,
      'Temperature': _temp,
      'Humidity': _humidity,
      'Rainfall': _rainfall,
      'Soil_pH': _ph,
      'Soil_Moisture': 40.0,
      'Organic_Carbon': 0.5,
      'Electrical_Conductivity': 0.3,
      'Soil_Type': 'Loamy',
      'Crop_Type': cropName,
      'Season': 'Summer',
    };
    try {
      final result = await apiService.getFertilizerAdvice(fertData);
      if (mounted) {
        setState(() {
          _fertilizerResults[index] = result;
          _isLoadingFertilizer[index] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFertilizer[index] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch fertilizer: $e')),
        );
      }
    }
  }

  Future<void> _scheduleReminder(int index, String cropName, String fertilizer) async {
    setState(() => _isSchedulingReminder[index] = true);
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    final days = RecommendationsService.cultivationDays[cropName] ?? 120;
    final dose2Days = (days * 0.33).round();
    final dose3Days = (days * 0.66).round();
    final baseId = DateTime.now().millisecondsSinceEpoch.remainder(100000) + (index * 10);

    try {
      await dbService.insertReminder(cropName, fertilizer, days);

      await notificationService.scheduleFertilizerReminder(
        id: baseId + 1,
        title: '🌱 $cropName Needs Fertilizer!',
        body: 'Apply Basal Dose (33%) of $fertilizer today. Phase: Initial Cultivation.',
        scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
      );
      await notificationService.scheduleFertilizerReminder(
        id: baseId + 2,
        title: '🌱 $cropName Needs Fertilizer!',
        body: 'Apply 2nd Dose (33%) of $fertilizer today. Phase: Vegetative.',
        scheduledDate: DateTime.now().add(Duration(days: dose2Days)),
      );
      await notificationService.scheduleFertilizerReminder(
        id: baseId + 3,
        title: '🌱 $cropName Needs Fertilizer!',
        body: 'Apply Final Dose (34%) of $fertilizer today. Phase: Flowering/Fruiting.',
        scheduledDate: DateTime.now().add(Duration(days: dose3Days)),
      );

      if (mounted) {
        setState(() {
          _isSchedulingReminder[index] = false;
          _reminderDone[index] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ 3 doses scheduled for $cropName over $days days.\n'
              'Dose 2 in $dose2Days days · Dose 3 in $dose3Days days',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSchedulingReminder[index] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_results != null) ...[
            // Show crops one-by-one, revealed by match %
            ...List.generate(
              _visibleCount.clamp(0, _results!.length),
              (i) => _buildCropCard(i, _results![i]),
            ),

            // "Show Next" button if more remain
            if (_results!.length > _visibleCount)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _visibleCount++),
                  icon: const Icon(PhosphorIconsRegular.arrowDown, size: 16),
                  label: Text(
                    'Show ${_results![_visibleCount]["recommended_crop"]} '
                    '(${_results![_visibleCount]["confidence"]}% match)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primaryDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Adjust parameters & get new recommendations',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          ],

          _buildSlider('Nitrogen (N)', _n, 0, 150, (v) => setState(() => _n = v)).animate().fade(delay: 100.ms),
          _buildSlider('Phosphorus (P)', _p, 0, 150, (v) => setState(() => _p = v)).animate().fade(delay: 200.ms),
          _buildSlider('Potassium (K)', _k, 0, 150, (v) => setState(() => _k = v)).animate().fade(delay: 300.ms),
          _buildSlider('Temperature (°C)', _temp, 0, 50, (v) => setState(() => _temp = v)).animate().fade(delay: 400.ms),
          _buildSlider('Humidity (%)', _humidity, 0, 100, (v) => setState(() => _humidity = v)).animate().fade(delay: 500.ms),
          _buildSlider('Rainfall (mm)', _rainfall, 0, 300, (v) => setState(() => _rainfall = v)).animate().fade(delay: 600.ms),
          _buildSlider('Soil pH', _ph, 0, 14, (v) => setState(() => _ph = v), divisions: 140).animate().fade(delay: 700.ms),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitData,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(TranslationService.translate(context, 'recommend_crop'), style: const TextStyle(fontSize: 16)),
          ).animate().fade(delay: 800.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCropCard(int index, Map<String, dynamic> result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cropName = result['recommended_crop'] as String? ?? '';
    final confidence = result['confidence'] as int? ?? 0;
    final reason = result['reason'] as String? ?? '';
    final fertResult = _fertilizerResults[index];
    final isLoadingFert = _isLoadingFertilizer[index] ?? false;
    final isScheduling = _isSchedulingReminder[index] ?? false;
    final reminderDone = _reminderDone[index] ?? false;

    final rankBadges = ['🥇 Best Match', '🥈 2nd Choice', '🥉 3rd Choice'];
    final rankColors = [Colors.amber, Colors.blueGrey.shade400, Colors.orange.shade400];
    final cardBg = isDark ? Colors.green.shade900.withOpacity(0.2) : Colors.green.shade50;
    final cardBorder = isDark ? Colors.green.shade800 : Colors.green.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.green.shade100.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rankColors[index].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rankBadges[index],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rankColors[index]),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$confidence% match',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(PhosphorIconsFill.plant, color: AppColors.primaryDark, size: 26),
                const SizedBox(width: 8),
                Text(
                  cropName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(reason, style: TextStyle(color: isDark ? Colors.grey.shade300 : AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),

            // Fertilizer result block
            if (fertResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.shade900.withOpacity(0.2) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.blue.shade900 : Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_outlined, color: Colors.blue, size: 18),
                        const SizedBox(width: 6),
                        const Text('Fertilizer Advice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fertResult['recommended_fertilizer'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                    Text(
                      fertResult['suggested_amount'] ?? '',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(fertResult['reason'] ?? '', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 12),

                    // Reminder scheduling row (only shown after fertilizer is fetched)
                    if (!reminderDone)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isScheduling
                              ? null
                              : () => _scheduleReminder(
                                    index,
                                    cropName,
                                    fertResult['recommended_fertilizer'] ?? 'NPK',
                                  ),
                          icon: isScheduling
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(PhosphorIconsRegular.bellRinging, size: 16),
                          label: Text(
                            isScheduling ? 'Scheduling...' : '🔔 Set Reminder for $cropName',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    else
                      // Reminder confirmation badge
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '✅ Reminder set! 3 doses over '
                                '${RecommendationsService.cultivationDays[cropName] ?? 120} days.',
                                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Check Fertilizer button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoadingFert ? null : () => _checkFertilizer(index, cropName),
                icon: isLoadingFert
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(PhosphorIconsRegular.flask, size: 16),
                label: Text(
                  fertResult != null ? 'Refresh Fertilizer' : 'Check Fertilizer for $cropName',
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms).fadeIn();
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged,
      {int? divisions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(value.toStringAsFixed(1),
                  style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.primaryLight.withOpacity(0.3),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
