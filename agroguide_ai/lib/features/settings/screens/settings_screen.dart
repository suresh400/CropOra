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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          TranslationService.translate(context, 'settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: [
          // ─── Offline Mode ───────────────────────────────────────────
          _buildSectionHeader(context, TranslationService.translate(context, 'offline_mode')),
          _buildCard(
            isDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _iconBox(PhosphorIconsFill.wifiSlash, AppColors.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          TranslationService.translate(context, 'offline_mode'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Switch(
                          key: ValueKey<bool>(settingsProvider.offlineMode),
                          value: settingsProvider.offlineMode,
                          onChanged: settingsProvider.toggleOfflineMode,
                          activeColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TranslationService.translate(context, 'offline_mode_desc'),
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Appearance ─────────────────────────────────────────────
          _buildSectionHeader(context, TranslationService.translate(context, 'language') + ' & ' + TranslationService.translate(context, 'dark_mode')),
          _buildCard(
            isDark,
            child: Column(
              children: [
                _buildListTile(
                  icon: PhosphorIconsFill.moon,
                  title: TranslationService.translate(context, 'dark_mode'),
                  trailing: Switch(
                    value: settingsProvider.themeMode == ThemeMode.dark,
                    onChanged: settingsProvider.toggleTheme,
                    activeColor: AppColors.primary,
                  ),
                  isDark: isDark,
                ),
                Divider(height: 1, indent: 56, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                _buildListTile(
                  icon: PhosphorIconsFill.translate,
                  title: TranslationService.translate(context, 'language'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _validLang(settingsProvider.locale.languageCode),
                        icon: const Icon(PhosphorIconsRegular.caretDown, size: 16),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                          DropdownMenuItem(value: 'te', child: Text('తెలుగు')),
                          DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
                          DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ')),
                          DropdownMenuItem(value: 'ml', child: Text('മലയാളം')),
                          DropdownMenuItem(value: 'mr', child: Text('मराठी')),
                          DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
                          DropdownMenuItem(value: 'pa', child: Text('ਪੰਜਾਬੀ')),
                          DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                          DropdownMenuItem(value: 'or', child: Text('ଓଡ଼ିଆ')),
                          DropdownMenuItem(value: 'as', child: Text('অসমীয়া')),
                          DropdownMenuItem(value: 'ur', child: Text('اردو')),
                        ],
                        onChanged: (code) {
                          if (code != null) settingsProvider.setLanguage(code);
                        },
                      ),
                    ),
                  ),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Contact Us ─────────────────────────────────────────────
          _buildSectionHeader(context, TranslationService.translate(context, 'contact_us')),
          _buildCard(
            isDark,
            child: Column(
              children: [
                _contactRow(
                  context,
                  icon: PhosphorIconsFill.phone,
                  label: TranslationService.translate(context, 'phone'),
                  value: '7777766666',
                  isDark: isDark,
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: '7777766666'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(TranslationService.translate(context, 'copied_phone'))),
                    );
                  },
                ),
                Divider(height: 1, indent: 56, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                _contactRow(
                  context,
                  icon: PhosphorIconsFill.envelope,
                  label: TranslationService.translate(context, 'email'),
                  value: 'supportcropora@gmail.com',
                  isDark: isDark,
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: 'supportcropora@gmail.com'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(TranslationService.translate(context, 'copied_email'))),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── App Info ────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(PhosphorIconsFill.plant, color: AppColors.primary, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  TranslationService.translate(context, 'app_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  TranslationService.translate(context, 'app_version'),
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _iconBox(icon, isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _iconBox(icon, AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.copy, size: 18, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  String _validLang(String code) {
    const valid = ['en','hi','te','ta','kn','ml','mr','gu','pa','bn','or','as','ur'];
    return valid.contains(code) ? code : 'en';
  }
}
