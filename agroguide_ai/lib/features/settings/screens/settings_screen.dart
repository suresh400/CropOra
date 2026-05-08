import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/translation_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBorder = BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ─── Offline Mode ───────────────────────────────────────────
          _buildCard(
            isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _iconBox(PhosphorIconsRegular.wifiSlash, AppColors.primaryDark),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text('Offline Mode',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      Switch(
                        value: settingsProvider.offlineMode,
                        onChanged: settingsProvider.toggleOfflineMode,
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When enabled, the app uses a local AI model without internet.',
                    style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Appearance ─────────────────────────────────────────────
          _buildCard(
            isDark,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.moon),
                  title: Text(TranslationService.translate(context, 'dark_mode')),
                  trailing: Switch(
                    value: settingsProvider.themeMode == ThemeMode.dark,
                    onChanged: settingsProvider.toggleTheme,
                    activeColor: AppColors.primary,
                  ),
                ),
                const Divider(height: 1, indent: 50),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.translate),
                  title: Text(TranslationService.translate(context, 'language')),
                  trailing: DropdownButton<String>(
                    value: _validLang(settingsProvider.locale.languageCode),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                      DropdownMenuItem(value: 'te', child: Text('Telugu')),
                      DropdownMenuItem(value: 'ta', child: Text('Tamil')),
                      DropdownMenuItem(value: 'kn', child: Text('Kannada')),
                      DropdownMenuItem(value: 'ml', child: Text('Malayalam')),
                      DropdownMenuItem(value: 'mr', child: Text('Marathi')),
                      DropdownMenuItem(value: 'gu', child: Text('Gujarati')),
                      DropdownMenuItem(value: 'pa', child: Text('Punjabi')),
                      DropdownMenuItem(value: 'bn', child: Text('Bengali')),
                      DropdownMenuItem(value: 'or', child: Text('Odia')),
                      DropdownMenuItem(value: 'as', child: Text('Assamese')),
                      DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                    ],
                    onChanged: (code) {
                      if (code != null) settingsProvider.setLanguage(code);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Contact Us ─────────────────────────────────────────────
          _buildCard(
            isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _iconBox(PhosphorIconsRegular.envelope, AppColors.primaryDark),
                      const SizedBox(width: 12),
                      Text(
                        'Contact Us',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _contactRow(
                    context,
                    icon: PhosphorIconsRegular.phone,
                    label: 'Phone',
                    value: '7777766666',
                    isDark: isDark,
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: '7777766666'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone number copied!')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _contactRow(
                    context,
                    icon: PhosphorIconsRegular.envelope,
                    label: 'Email',
                    value: 'supportcropora@gmail.com',
                    isDark: isDark,
                    onTap: () {
                      Clipboard.setData(
                          const ClipboardData(text: 'supportcropora@gmail.com'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── App Info ────────────────────────────────────────────────
          _buildCard(
            isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _iconBox(PhosphorIconsRegular.info, AppColors.primaryDark),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CropOra',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Version 1.0.0 • Smart Farming AI',
                          style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isDark, {required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color),
    );
  }

  Widget _contactRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primaryDark)),
              ],
            ),
            const Spacer(),
            Icon(PhosphorIconsRegular.copy, size: 14, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  String _validLang(String code) {
    const valid = ['en','hi','te','ta','kn','ml','mr','gu','pa','bn','or','as','ur'];
    return valid.contains(code) ? code : 'en';
  }
}
