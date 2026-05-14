import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/database_service.dart';
import '../../../services/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  List<String> _trackedIds = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final reminders = await dbService.getReminders();
    final prefs = await SharedPreferences.getInstance();
    
    if (mounted) {
      setState(() {
        _reminders = reminders;
        _trackedIds = prefs.getStringList('tracked_crops') ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTracking(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final strId = id.toString();
    setState(() {
      if (_trackedIds.contains(strId)) {
        _trackedIds.remove(strId);
      } else {
        _trackedIds.add(strId);
      }
    });
    await prefs.setStringList('tracked_crops', _trackedIds);
  }

  String _formatDate(String? isoTimestamp) {
    if (isoTimestamp == null) return '';
    try {
      final dt = DateTime.parse(isoTimestamp);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoTimestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.translate(context, 'reminders')),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: _loadReminders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsRegular.bellSlash, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No reminders set yet',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Schedule fertilizer reminders from the\nFertilizer Advisory screen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReminders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reminders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      final id = reminder['id'] as int;
                      final isTracked = _trackedIds.contains(id.toString());
                      final crop = reminder['crop_type'] ?? 'Unknown';
                      final fertilizer = reminder['fertilizer_name'] ?? 'Unknown';
                      final days = reminder['cultivation_days'] ?? 0;
                      final timestamp = reminder['timestamp'] as String?;
                      
                      final dose2 = (days * 0.33).round();
                      final dose3 = (days * 0.66).round();

                      int daysCompleted = 0;
                      if (timestamp != null) {
                        try {
                          final dt = DateTime.parse(timestamp);
                          daysCompleted = DateTime.now().difference(dt).inDays;
                          if (daysCompleted < 0) daysCompleted = 0;
                          if (daysCompleted > days) daysCompleted = days;
                        } catch (_) {}
                      }
                      final progress = days > 0 ? daysCompleted / days : 0.0;

                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2A1E) : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.green.shade900 : Colors.green.shade200,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(PhosphorIconsRegular.bellRinging, color: AppColors.primaryDark, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          crop,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                        Text(
                                          fertilizer,
                                          style: TextStyle(
                                            color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _toggleTracking(id),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isTracked ? AppColors.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isTracked ? PhosphorIconsFill.pushPin : PhosphorIconsRegular.pushPin,
                                            size: 14,
                                            color: isTracked ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isTracked ? 'Tracking' : 'Track',
                                            style: TextStyle(
                                              color: isTracked ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Cultivation Progress',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : AppColors.textSecondary),
                                  ),
                                  Text(
                                    '$daysCompleted / $days Days',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.green.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progress >= 1.0 ? Colors.amber : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Text(
                                'Scheduled Doses',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDoseRow('Dose 1 (Basal)', 'Immediate', Icons.looks_one_rounded, daysCompleted >= 0, isDark),
                              _buildDoseRow('Dose 2 (Vegetative)', 'Day $dose2', Icons.looks_two_rounded, daysCompleted >= dose2, isDark),
                              _buildDoseRow('Dose 3 (Flowering)', 'Day $dose3', Icons.looks_3_rounded, daysCompleted >= dose3, isDark),
                              if (timestamp != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(PhosphorIconsRegular.calendarCheck,
                                        size: 12,
                                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Set on ${_formatDate(timestamp)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildDoseRow(String label, String timing, IconData icon, bool isReached, bool isDark) {
    final color = isReached ? AppColors.primary : (isDark ? Colors.grey.shade600 : Colors.grey.shade400);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: isReached ? FontWeight.w600 : FontWeight.normal)),
          const Spacer(),
          Text(
            timing,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: isReached ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          if (isReached)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(PhosphorIconsFill.checkCircle, size: 14, color: AppColors.primary),
            )
        ],
      ),
    );
  }
}
