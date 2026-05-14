import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/api_service.dart';
import '../../../../services/database_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/translation_service.dart';
import '../../../../services/recommendations_service.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FertilizerAdvisoryForm extends StatefulWidget {
  const FertilizerAdvisoryForm({super.key});

  @override
  State<FertilizerAdvisoryForm> createState() => _FertilizerAdvisoryFormState();
}

class _FertilizerAdvisoryFormState extends State<FertilizerAdvisoryForm> {
  double _n = 50;
  double _p = 50;
  double _k = 50;
  double _moisture = 40;
  double _temp = 25;
  double _humidity = 60;
  double _ph = 6.5;
  double _rainfall = 100;
  double _organicCarbon = 0.5;
  double _ec = 0.3;

  String _soilType = 'Loamy';
  String _cropType = 'Rice';
  String _season = 'Summer';

  final List<String> _soilTypes = ['Sandy', 'Loamy', 'Black', 'Red', 'Clayey'];
  final List<String> _cropTypes = [
    'Rice', 'Maize', 'Chickpea', 'Banana', 'Mango', 'Grapes',
    'Watermelon', 'Muskmelon', 'Apple', 'Orange', 'Papaya',
    'Coconut', 'Cotton', 'Jute', 'Coffee', 'Sugarcane', 'Tomato',
    'Wheat', 'Pigeonpeas', 'Mothbeans', 'Mungbean', 'Blackgram', 'Lentil',
  ];
  final List<String> _seasons = ['Summer', 'Winter', 'Rainy'];

  bool _isLoading = false;
  bool _isScheduling = false;
  Map<String, dynamic>? _result;

  void _submitData() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    final data = {
      'Nitrogen_Level': _n,
      'Phosphorus_Level': _p,
      'Potassium_Level': _k,
      'Soil_Moisture': _moisture,
      'Temperature': _temp,
      'Humidity': _humidity,
      'Soil_pH': _ph,
      'Rainfall': _rainfall,
      'Organic_Carbon': _organicCarbon,
      'Electrical_Conductivity': _ec,
      'Soil_Type': _soilType,
      'Crop_Type': _cropType,
      'Season': _season,
    };

    try {
      final result = await apiService.getFertilizerAdvice(data);
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
        await dbService.insertHistory('fertilizer', data, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Auto-schedule reminder using the built-in cultivation days table.
  /// No navigation — schedules instantly and shows snackbar.
  Future<void> _autoScheduleReminder() async {
    if (_result == null) return;

    setState(() => _isScheduling = true);

    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final fertilizer = _result!['recommended_fertilizer'] as String? ?? 'NPK';

    // Look up cultivation days from the built-in table
    final days = RecommendationsService.cultivationDays[_cropType] ?? 120;

    final int dose2Days = (days * 0.33).round();
    final int dose3Days = (days * 0.66).round();

    try {
      await dbService.insertReminder(_cropType, fertilizer, days);

      await notificationService.scheduleFertilizerReminder(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 1,
        title: '🌱 $_cropType Needs Fertilizer!',
        body: 'Apply Basal Dose (33%) of $fertilizer today. Phase: Initial Cultivation.',
        scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
      );

      await notificationService.scheduleFertilizerReminder(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 2,
        title: '🌱 $_cropType Needs Fertilizer!',
        body: 'Apply 2nd Dose (33%) of $fertilizer today. Phase: Vegetative.',
        scheduledDate: DateTime.now().add(Duration(days: dose2Days)),
      );

      await notificationService.scheduleFertilizerReminder(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 3,
        title: '🌱 $_cropType Needs Fertilizer!',
        body: 'Apply Final Dose (34%) of $fertilizer today. Phase: Flowering/Fruiting.',
        scheduledDate: DateTime.now().add(Duration(days: dose3Days)),
      );

      if (mounted) {
        setState(() => _isScheduling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Reminders set! 3 doses scheduled over $days days for $_cropType.',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScheduling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling reminders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_result != null) _buildResultCard(isDark),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDropdown('Soil Type', _soilType, _soilTypes, (val) => setState(() => _soilType = val!)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown('Crop Type', _cropType, _cropTypes, (val) => setState(() => _cropType = val!)),
              ),
            ],
          ).animate().fade(delay: 50.ms),
          const SizedBox(height: 16),
          _buildDropdown('Season', _season, _seasons, (val) => setState(() => _season = val!)).animate().fade(delay: 100.ms),

          const SizedBox(height: 16),
          _buildSlider('Nitrogen (N) Content', _n, 0, 150, (val) => setState(() => _n = val)).animate().fade(delay: 150.ms),
          _buildSlider('Phosphorus (P) Content', _p, 0, 150, (val) => setState(() => _p = val)).animate().fade(delay: 200.ms),
          _buildSlider('Potassium (K) Content', _k, 0, 150, (val) => setState(() => _k = val)).animate().fade(delay: 250.ms),
          _buildSlider('Soil Moisture (%)', _moisture, 0, 100, (val) => setState(() => _moisture = val)).animate().fade(delay: 300.ms),
          _buildSlider('Soil pH', _ph, 0, 14, (val) => setState(() => _ph = val), divisions: 140).animate().fade(delay: 350.ms),
          _buildSlider('Rainfall (mm)', _rainfall, 0, 1000, (val) => setState(() => _rainfall = val)).animate().fade(delay: 400.ms),
          _buildSlider('Organic Carbon', _organicCarbon, 0, 2, (val) => setState(() => _organicCarbon = val)).animate().fade(delay: 450.ms),
          _buildSlider('Electrical Cond. (EC)', _ec, 0, 2, (val) => setState(() => _ec = val)).animate().fade(delay: 500.ms),
          _buildSlider('Temperature (°C)', _temp, 0, 50, (val) => setState(() => _temp = val)).animate().fade(delay: 550.ms),
          _buildSlider('Humidity (%)', _humidity, 0, 100, (val) => setState(() => _humidity = val)).animate().fade(delay: 600.ms),

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
              : Text(TranslationService.translate(context, 'get_fertilizer_advice'), style: const TextStyle(fontSize: 16)),
          ).animate().fade(delay: 700.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 120), // Increased padding for floating nav bar
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDark) {
    final fertilizer = _result!['recommended_fertilizer'] as String? ?? '';
    final amount = _result!['suggested_amount'] as String? ?? '';
    final reason = _result!['reason'] as String? ?? '';
    final days = RecommendationsService.cultivationDays[_cropType] ?? 120;
    final cardBg = isDark ? Colors.blue.shade900.withOpacity(0.25) : Colors.blue.shade50;
    final cardBorder = isDark ? Colors.blue.shade900 : Colors.blue.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.blue.shade100.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Text(
                  TranslationService.translate(context, 'fert_form_title'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              fertilizer,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : AppColors.textSecondary),
            ),
            const Divider(height: 24),
            Text('${TranslationService.translate(context, 'reason')}:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(reason),
            const SizedBox(height: 16),

            // Auto-schedule reminder info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.calendarCheck, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_cropType · $days days cultivation · 3 dose schedule',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScheduling ? null : _autoScheduleReminder,
                icon: _isScheduling
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(PhosphorIconsRegular.bellRinging, size: 20),
                label: Text(
                  _isScheduling
                    ? 'Scheduling...'
                    : TranslationService.translate(context, 'set_reminder'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms).fadeIn();
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged, {int? divisions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(value.toStringAsFixed(1), style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
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
