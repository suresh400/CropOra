import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/database_service.dart';
import '../../../services/translation_service.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/ai_cache_service.dart';
import '../../ai_expert/services/ai_expert_service.dart';
import '../../ai_expert/services/offline_engine.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isStreaming;

  ChatMessage(this.text, {required this.isUser, this.isStreaming = false});

  ChatMessage copyWith({String? text, bool? isStreaming}) {
    return ChatMessage(
      text ?? this.text,
      isUser: isUser,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
        TranslationService.translate(context, 'ai_expert_greeting'),
        isUser: false,
      ));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? quickActionText]) async {
    final text = quickActionText ?? _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final aiExpertService =
        Provider.of<AiExpertService>(context, listen: false);

    setState(() {
      _messages.add(ChatMessage(text, isUser: true));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // Save user message to DB (fire-and-forget)
    dbService.insertChatMessage(text, true);

    // Add streaming placeholder
    setState(() {
      _messages.add(ChatMessage('', isUser: false, isStreaming: true));
    });

    final aiMsgIndex = _messages.length - 1;
    final StringBuffer fullResponse = StringBuffer();

    try {
      await for (final chunk
          in aiExpertService.askExpertStream(context, text)) {
        if (!mounted) break;

        // Strip internal prefix tags from the display text
        String displayChunk = chunk;
        if (fullResponse.isEmpty) {
          displayChunk = chunk
              .replaceFirst('[From Cache] ', '')
              .replaceFirst('[Offline Mode]', '')
              .replaceFirst('[Offline: Found in History]', '')
              .trim();
        }

        fullResponse.write(displayChunk);
        setState(() {
          _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
            text: fullResponse.toString(),
            isStreaming: true,
          );
        });
        _scrollToBottom();
      }

      // Finalize
      if (mounted) {
        setState(() {
          _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
            isStreaming: false,
          );
          _isTyping = false;
        });
        dbService.insertChatMessage(fullResponse.toString(), false);
      }
    } catch (e) {
      // Last-resort: OfflineEngine
      String fallbackAnswer;
      try {
        fallbackAnswer = await OfflineEngine.getResponse(text);
        AiCacheService.saveToCache(text, fallbackAnswer, 'offline_engine');
      } catch (_) {
        fallbackAnswer =
            'Sorry, I could not process your question right now. Please try again.';
      }

      if (mounted) {
        setState(() {
          _messages[aiMsgIndex] = ChatMessage(
            fallbackAnswer,
            isUser: false,
            isStreaming: false,
          );
          _isTyping = false;
        });
        dbService.insertChatMessage(fallbackAnswer, false);
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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildChatBubble(_messages[index]),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = msg.isUser;

    final displayText = (msg.isStreaming && msg.text.isEmpty)
        ? '▋'
        : msg.isStreaming
            ? '${msg.text}▋'
            : msg.text;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])
              : null,
          color: isUser
              ? null
              : (isDark ? Colors.grey.shade800 : Colors.white),
          boxShadow: [
            if (!isUser)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(isUser ? 24 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 24),
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : (isDark ? Colors.white : AppColors.textPrimary),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }



  Widget _buildQuickActions() {
    final actions = ['Crop Recommendation', 'Fertilizer Advice', 'Weather Advice'];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ActionChip(
            label: Text(actions[index], style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? AppColors.primaryDark.withOpacity(0.2) 
                : AppColors.primaryLight.withOpacity(0.1),
            side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
            labelStyle: const TextStyle(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _sendMessage(actions[index]),
          ).animate().fade(delay: (100 * index).ms).scale(),
        ),
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
                enabled: !_isTyping,
                decoration: InputDecoration(
                  hintText: _isTyping
                      ? 'AI is thinking...'
                      : TranslationService.translate(context, 'ask_anything'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  filled: true,
                  fillColor:
                      isDark ? Colors.grey.shade900 : Colors.grey.shade100,
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
              backgroundColor:
                  _isTyping ? Colors.grey.shade400 : AppColors.primary,
              child: IconButton(
                icon: Icon(
                  _isTyping
                      ? PhosphorIconsFill.hourglassMedium
                      : PhosphorIconsFill.paperPlaneRight,
                  color: Colors.white,
                ),
                onPressed: _isTyping ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}
