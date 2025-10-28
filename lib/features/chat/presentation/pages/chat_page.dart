import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/local_database.dart';
import '../../../../shared/services/ai/ai_chat_service.dart';
import '../../domain/models/chat_message.dart';
import '../viewmodels/chat_view_model.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatViewModel>(
      create: (_) => ChatViewModel(
        chatService: context.read<AiChatService>(),
        localDatabase: context.read<LocalDatabase>(),
      ),
      child: Consumer<ChatViewModel>(
        builder: (context, vm, _) {
          if (!vm.isReady) {
            return const Scaffold(
              appBar: _ChatAppBar(),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: const _ChatAppBar(),
            body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: vm.messages.length,
                    itemBuilder: (context, index) {
                      final message = vm.messages[index];
                      return _MessageBubble(message: message);
                    },
                  ),
                ),
                if (vm.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MaterialBanner(
                      content: Text(vm.error!),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        TextButton(
                          onPressed: vm.clearError,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                _Composer(
                  controller: _controller,
                  sending: vm.isSending,
                  onSend: (text) async {
                    await vm.sendMessage(text);
                    _controller.clear();
                    await Future<void>.delayed(
                        const Duration(milliseconds: 150));
                    if (!mounted) return;
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('AI Concierge'),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function(String message) onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onSubmitted: sending ? null : (value) => onSend(value),
                decoration: const InputDecoration(
                  hintText: 'Ask about rooms, bookings, or policies…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: sending ? null : () => onSend(controller.text),
              child: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final colorScheme = theme.colorScheme;
    final bubbleColor =
        isUser ? colorScheme.primary : colorScheme.surfaceVariant;
    final textColor =
        isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: Radius.circular(isUser ? 0 : 16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
          ),
        ),
        child: Text(
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      ),
    );
  }
}
