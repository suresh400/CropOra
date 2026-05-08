import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../services/database_service.dart';
import '../../../services/translation_service.dart';
import '../../../core/theme/app_colors.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(TranslationService.translate(context, 'farming_history')),
          bottom: TabBar(
            tabs: [
              Tab(
                text: TranslationService.translate(context, 'history_tabs_advisories'), 
                icon: const Icon(PhosphorIconsRegular.plant)
              ),
              Tab(
                text: TranslationService.translate(context, 'history_tabs_chat'), 
                icon: const Icon(PhosphorIconsRegular.chatCircleText)
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAdvisoryHistory(dbService),
            _buildChatHistory(dbService),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisoryHistory(DatabaseService dbService) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllAdvisories(dbService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(TranslationService.translate(context, 'no_history')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final item = snapshot.data![index];
            final type = item['type']; // crop, fertilizer, pest
            IconData icon = PhosphorIconsRegular.plant;
            String title = 'Advisory';

            if (type == 'crop') {
              title = TranslationService.translate(context, 'crop_suggest');
              icon = PhosphorIconsRegular.plant;
            } else if (type == 'fertilizer') {
              title = TranslationService.translate(context, 'fertilizer');
              icon = PhosphorIconsRegular.flask;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(icon, color: AppColors.primaryDark),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item['timestamp']}'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  // Show details dialog or screen
                  _showDetails(context, item);
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllAdvisories(DatabaseService dbService) async {
    final crop = await dbService.getHistory('crop');
    final fertilizer = await dbService.getHistory('fertilizer');
    
    final all = [...crop, ...fertilizer];
    all.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    return all;
  }

  void _showDetails(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('History Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Type: ${item['type'].toString().toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Date: ${item['timestamp']}'),
              const Divider(height: 32),
              const Text('Result:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(item['result_data']),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatHistory(DatabaseService dbService) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: dbService.getChatHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(TranslationService.translate(context, 'no_history')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final item = snapshot.data![index];
            final isUser = item['is_user'] == 1;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                decoration: BoxDecoration(
                  color: isUser 
                    ? AppColors.primary.withOpacity(0.1) 
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item['message'], 
                  style: TextStyle(
                    color: isUser ? AppColors.primaryDark : (isDark ? Colors.white : Colors.black87)
                  )
                ),
              ),
            );
          },
        );
      },
    );
  }
}
