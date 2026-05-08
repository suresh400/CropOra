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
            // Avatar with edit-name tap
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : 'F',
                    style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                GestureDetector(
                  onTap: _editName,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _editName,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _phone,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 32),

            _buildProfileOption(context,
              icon: PhosphorIconsRegular.gear,
              title: 'Settings',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            _buildProfileOption(context,
              icon: PhosphorIconsRegular.clockCounterClockwise,
              title: TranslationService.translate(context, 'farming_history'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ),
            _buildProfileOption(context,
              icon: PhosphorIconsRegular.bell,
              title: TranslationService.translate(context, 'reminders'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen())),
            ),
            _buildProfileOption(context,
              icon: PhosphorIconsRegular.shieldCheck,
              title: TranslationService.translate(context, 'privacy_policy'),
              onTap: () {},
            ),
            const Divider(height: 48),
            _buildProfileOption(context,
              icon: PhosphorIconsRegular.signOut,
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
            ),
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
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.shade50
              : (isDark ? Colors.grey.shade900 : AppColors.primary.withOpacity(0.1)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : AppColors.primaryDark),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : (isDark ? Colors.white : AppColors.textPrimary),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white54 : AppColors.textSecondary,
        size: 18,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
