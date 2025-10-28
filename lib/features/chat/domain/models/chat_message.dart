import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum ChatSender { user, assistant, system }

class ChatMessage {
  ChatMessage({
    required this.sender,
    required this.content,
    String? id,
    DateTime? timestamp,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();

  final String id;
  final ChatSender sender;
  final String content;
  final DateTime timestamp;

  bool get isUser => sender == ChatSender.user;
  bool get isAssistant => sender == ChatSender.assistant;
}
