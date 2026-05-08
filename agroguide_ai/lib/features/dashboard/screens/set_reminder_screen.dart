import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/notification_service.dart';
import '../../../services/database_service.dart';
import '../../../services/translation_service.dart';
import '../../ai_expert/services/ai_expert_service.dart';

class SetReminderScreen extends StatefulWidget {
  final String? initialCrop;
  final String? initialFertilizer;

  const SetReminderScreen({super.key, this.initialCrop, this.initialFertilizer});

  @override
  State<SetReminderScreen> createState() => _SetReminderScreenState();
}

class _SetReminderScreenState extends State<SetReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cropTypeController = TextEditingController();
  final _fertilizerController = TextEditingController();
  final _cultivationDaysController = TextEditingController();

  List<String> _cropHistory = [];
  List<String> _fertilizerHistory = [];
  bool _isLoadingAI = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCrop != null) {
      _cropTypeController.text = widget.initialCrop!;
    }
    if (widget.initialFertilizer != null) {
      _fertilizerController.text = widget.initialFertilizer!;
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    // Fetch Crop History
    final cropRows = await dbService.getHistory('crop');
    final List<String> loadedCrops = [];
    for (var row in cropRows) {
      if (row['result_data'] != null) {
        final resultDecoded = jsonDecode(row['result_data'] as String);
        if (resultDecoded['recommended_crop'] != null) {
          loadedCrops.add(resultDecoded['recommended_crop'].toString());
        }
      }
    }

    // Fetch Fertilizer History
    final fertRows = await dbService.getHistory('fertilizer');
    final List<String> loadedFerts = [];
    for (var row in fertRows) {
      if (row['result_data'] != null) {
        final resultDecoded = jsonDecode(row['result_data'] as String);
        if (resultDecoded['recommended_fertilizer'] != null) {
          loadedFerts.add(resultDecoded['recommended_fertilizer'].toString());
        }
      }
    }

    if (mounted) {
      setState(() {
        _cropHistory = loadedCrops.toSet().toList(); // Remove duplicates
        _fertilizerHistory = loadedFerts.toSet().toList();
      });
    }
  }

  Future<void> _askAiForDays() async {
    final crop = _cropTypeController.text.trim();
    final fertilizer = _fertilizerController.text.trim();

    if (crop.isEmpty || fertilizer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select a Crop and Fertilizer first."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingAI = true);

    final aiExpertService = Provider.of<AiExpertService>(context, listen: false);
    final prompt = "Estimate the total cultivation days for \$crop using \$fertilizer. Provide ONLY the integer number of overall days as your entire response. No text, no explanation.";

    try {
      final response = await aiExpertService.askExpert(context, prompt);
      // Clean the response leaving only digits
      final digitString = response.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (digitString.isNotEmpty && mounted) {
        setState(() {
          _cultivationDaysController.text = digitString;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("AI estimated \$digitString days!"),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        throw Exception("Could not parse integer from AI.");
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("AI estimation failed. Please enter manually."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  void _scheduleReminders() async {
    if (_formKey.currentState!.validate()) {
      final String cropType = _cropTypeController.text.trim();
      final String fertilizer = _fertilizerController.text.trim();
      final int days = int.parse(_cultivationDaysController.text.trim());

      final notificationService = Provider.of<NotificationService>(context, listen: false);
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      final int dose2Days = (days * 0.33).round();
      final int dose3Days = (days * 0.66).round();

      try {
        // Save to Database
        await dbService.insertReminder(cropType, fertilizer, days);

        // Schedule Dose 1: Basal (1 min from now for demo)
        await notificationService.scheduleFertilizerReminder(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 1,
          title: TranslationService.translate(context, 'fertilizer_alert'),
          body: "Apply basal dose of \$fertilizer to your \$cropType.",
          scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
        );

        // Schedule Dose 2: Vegetative
        await notificationService.scheduleFertilizerReminder(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 2,
          title: TranslationService.translate(context, 'fertilizer_alert'),
          body: "Apply 2nd dose of \$fertilizer to your \$cropType.",
          scheduledDate: DateTime.now().add(Duration(days: dose2Days)),
        );

        // Schedule Dose 3: Flowering/Fruiting
        await notificationService.scheduleFertilizerReminder(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 3,
          title: TranslationService.translate(context, 'fertilizer_alert'),
          body: "Apply final dose of \$fertilizer to your \$cropType.",
          scheduledDate: DateTime.now().add(Duration(days: dose3Days)),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TranslationService.translate(context, 'reminders_set_success')),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error scheduling notifications: \$e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.translate(context, 'set_reminder')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(PhosphorIconsRegular.bellRinging, size: 64, color: AppColors.primary),
              const SizedBox(height: 24),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: widget.initialCrop ?? ''),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return _cropHistory;
                  return _cropHistory.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _cropTypeController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                   // Link autocomplete controller to our tracking controller
                   controller.addListener(() { _cropTypeController.text = controller.text; });
                   return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: TranslationService.translate(context, 'crop_type'),
                      prefixIcon: const Icon(PhosphorIconsRegular.plant),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: widget.initialFertilizer ?? ''),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return _fertilizerHistory;
                  return _fertilizerHistory.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _fertilizerController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                   controller.addListener(() { _fertilizerController.text = controller.text; });
                   return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: TranslationService.translate(context, 'fertilizer_name'),
                      prefixIcon: const Icon(PhosphorIconsRegular.flask),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cultivationDaysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: TranslationService.translate(context, 'cultivation_days'),
                        prefixIcon: const Icon(PhosphorIconsRegular.calendarBlank),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (int.tryParse(val) == null) return 'Number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 56, // Match text form field height roughly
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.blue.shade100,
                          foregroundColor: isDark ? Colors.white : Colors.blue.shade800,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isLoadingAI ? null : _askAiForDays,
                        icon: _isLoadingAI 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(PhosphorIconsFill.sparkle, size: 18),
                        label: Text(_isLoadingAI ? '' : 'Ask AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _scheduleReminders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  TranslationService.translate(context, 'schedule_reminders'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
