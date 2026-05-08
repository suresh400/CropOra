import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/crop_form.dart';
import '../../fertilizer_advisory/screens/widgets/fertilizer_form.dart';

class RecommendationsScreen extends StatelessWidget {
  final int initialIndex;
  const RecommendationsScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Advisories'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Crop Suggestion', icon: Icon(Icons.local_florist)),
              Tab(text: 'Fertilizer', icon: Icon(Icons.science)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CropRecommendationForm(),
            FertilizerAdvisoryForm(),
          ],
        ),
      ),
    );
  }
}
