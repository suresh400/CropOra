import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../crop_recommendation/screens/recommendations_screen.dart';
import '../../ai_chat/screens/ai_chat_screen.dart';
import '../../../services/translation_service.dart';
import '../../profile/screens/profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const RecommendationsScreen(),
    const AiChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight.withOpacity(0.2),
        destinations: [
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.house),
            selectedIcon: const Icon(PhosphorIconsFill.house, color: AppColors.primaryDark),
            label: TranslationService.translate(context, 'home'),
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.leaf),
            selectedIcon: const Icon(PhosphorIconsFill.leaf, color: AppColors.primaryDark),
            label: TranslationService.translate(context, 'advisories'),
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.chatTeardropDots),
            selectedIcon: const Icon(PhosphorIconsFill.chatTeardropDots, color: AppColors.primaryDark),
            label: TranslationService.translate(context, 'ai_chat'),
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.user),
            selectedIcon: const Icon(PhosphorIconsFill.user, color: AppColors.primaryDark),
            label: TranslationService.translate(context, 'profile'),
          ),
        ],
      ),
    );
  }
}
