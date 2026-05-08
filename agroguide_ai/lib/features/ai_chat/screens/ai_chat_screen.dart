import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/database_service.dart';
import '../../../services/translation_service.dart';
import '../../../providers/settings_provider.dart';
import '../../ai_expert/services/ai_expert_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage(this.text, {required this.isUser});
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
        TranslationService.translate(context, 'ai_expert_greeting'), 
        isUser: false
      ));
    }
  }

  void _sendMessage([String? quickActionText]) async {
    final text = quickActionText ?? _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final aiExpertService = Provider.of<AiExpertService>(context, listen: false);

    setState(() {
      _messages.add(ChatMessage(text, isUser: true));
      _messageController.clear();
      _isTyping = true;
    });
    
    // Save user message to DB
    await dbService.insertChatMessage(text, true);

    try {
      final response = await aiExpertService.askExpert(context, text);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(response, isUser: false));
          _isTyping = false;
        });
        // Save AI response to DB
        await dbService.insertChatMessage(response, false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage("AI expert unavailable. Please try again.", isUser: false));
          _isTyping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(PhosphorIconsFill.robot, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Text(TranslationService.translate(context, 'ai_chat')),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildQuickActions(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final isUser = _messages[index].isUser;
                return _buildChatBubble(_messages[index].text, isUser);
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('...', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
              ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      'Crop Recommendation',
      'Fertilizer Advice',
      'Weather Advice',
    ];
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(actions[index]),
              backgroundColor: Theme.of(context).cardColor,
              side: BorderSide(color: AppColors.primaryLight.withOpacity(0.5)),
              labelStyle: const TextStyle(color: AppColors.primaryDark),
              onPressed: () => _sendMessage(actions[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: TranslationService.translate(context, 'ask_anything'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: const Icon(PhosphorIconsFill.paperPlaneRight, color: Colors.white),
                onPressed: () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
