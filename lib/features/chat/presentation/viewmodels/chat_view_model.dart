import 'package:flutter/foundation.dart';

import '../../../../core/database/local_database.dart';
import '../../../../shared/services/ai/ai_chat_service.dart';
import '../../domain/models/chat_message.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required AiChatService chatService,
    required LocalDatabase localDatabase,
  })  : _chatService = chatService,
        _localDatabase = localDatabase {
    _initialise();
  }

  final AiChatService _chatService;
  final LocalDatabase _localDatabase;

  final List<ChatMessage> _messages = <ChatMessage>[];
  bool _sending = false;
  String? _error;
  bool _initialised = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _sending;
  String? get error => _error;
  bool get isReady => _initialised;

  Future<void> _initialise() async {
    await _buildSystemPrompt();
    _initialised = true;
    notifyListeners();
  }

  Future<void> _buildSystemPrompt() async {
    final rooms = await _localDatabase.getRooms();
    final roomSummary = rooms.isEmpty
        ? 'No cached rooms available yet. Respond with general guidance and suggest syncing data.'
        : rooms
            .map(
              (room) =>
                  '- ${room.name} | capacity ${room.capacity} | location ${room.location}${room.latitude != null ? ' | lat ${room.latitude}, lng ${room.longitude}' : ''}',
            )
            .join('\n');

    final systemPrompt = ChatMessage(
      sender: ChatSender.system,
      content: '''
You are an AI assistant for the Meeting Room Booking System. Help users discover rooms, explain booking policies, and guide them through using the app.

Known rooms:
$roomSummary

Always remind users to confirm availability inside the app before finalising plans.
''',
    );
    _messages
      ..clear()
      ..add(systemPrompt)
      ..add(
        ChatMessage(
          sender: ChatSender.assistant,
          content:
              'Hello! I can help you explore meeting rooms, booking rules, and app features. What would you like to know?',
        ),
      );
  }

  Future<void> sendMessage(String content) async {
    if (!_initialised || content.trim().isEmpty || _sending) {
      return;
    }
    _error = null;
    final userMessage = ChatMessage(
      sender: ChatSender.user,
      content: content.trim(),
    );
    _messages.add(userMessage);
    _sending = true;
    notifyListeners();

    try {
      final aiMessages = _messages
          .map(
            (message) => AiChatMessage(
              role: switch (message.sender) {
                ChatSender.user => 'user',
                ChatSender.assistant => 'assistant',
                ChatSender.system => 'system',
              },
              content: message.content,
            ),
          )
          .toList();

      final reply = await _chatService.sendChatCompletion(messages: aiMessages);

      final assistantMessage = ChatMessage(
        sender: ChatSender.assistant,
        content: reply,
      );
      _messages.add(assistantMessage);
    } on AiChatException catch (error) {
      _error = error.message;
      _messages.add(
        ChatMessage(
          sender: ChatSender.assistant,
          content:
              'I could not reach the AI service. Please double-check the API key configuration and try again.',
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('ChatViewModel.sendMessage unexpected error: $error');
      debugPrint('$stackTrace');
      _error = 'Unexpected error occurred.';
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
