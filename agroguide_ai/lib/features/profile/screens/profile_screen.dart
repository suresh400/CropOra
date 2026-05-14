import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../../services/translation_service.dart';
import '../../settings/screens/settings_screen.dart';
import 'history_screen.dart';
import '../../dashboard/screens/reminders_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Farmer';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? 'Farmer';
      // Use the login phone saved at sign-in time
      final savedPhone = prefs.getString('login_phone') ?? '';
      final authPhone = Provider.of<AuthService>(context, listen: false).user?.phoneNumber ?? '';
      _phone = savedPhone.isNotEmpty ? savedPhone : (authPhone.isNotEmpty ? authPhone : 'Not logged in');
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', result);
      if (mounted) setState(() => _name = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(TranslationService.translate(context, 'profile'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : 'F',
                      style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _editName,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                    ),
                    child: const Icon(Icons.edit, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _editName,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(PhosphorIconsRegular.pencilSimple, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ).animate().fade(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              _phone,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ).animate().fade(delay: 300.ms),
            const SizedBox(height: 32),

            _buildProfileOption(context,
              icon: PhosphorIconsFill.gear,
              title: TranslationService.translate(context, 'settings'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ).animate().fade(delay: 400.ms).slideX(begin: 0.1, end: 0),
            _buildProfileOption(context,
              icon: PhosphorIconsFill.clockCounterClockwise,
              title: TranslationService.translate(context, 'farming_history'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ).animate().fade(delay: 450.ms).slideX(begin: 0.1, end: 0),
            _buildProfileOption(context,
              icon: PhosphorIconsFill.bell,
              title: TranslationService.translate(context, 'reminders'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen())),
            ).animate().fade(delay: 500.ms).slideX(begin: 0.1, end: 0),
            _buildProfileOption(context,
              icon: PhosphorIconsFill.shieldCheck,
              title: TranslationService.translate(context, 'privacy_policy'),
              onTap: () {},
            ).animate().fade(delay: 550.ms).slideX(begin: 0.1, end: 0),
            const SizedBox(height: 24),
            _buildProfileOption(context,
              icon: PhosphorIconsFill.signOut,
              title: TranslationService.translate(context, 'logout'),
              isDestructive: true,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('login_phone');
                await authService.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ).animate().fade(delay: 600.ms).slideX(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.shade50
                : (isDark ? Colors.grey.shade800 : AppColors.primary.withOpacity(0.1)),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isDestructive ? Colors.red : AppColors.primaryDark),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDestructive ? Colors.red : (isDark ? Colors.white : AppColors.textPrimary),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white54 : AppColors.textSecondary,
            size: 18,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
