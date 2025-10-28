import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/ai_config.dart';

enum AiProvider { openAi, gemini }

class AiChatException implements Exception {
  AiChatException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AiChatException($statusCode): $message';
}

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;
}

class AiChatService {
  AiChatService({
    http.Client? client,
    AiProvider? provider,
  })  : _client = client ?? http.Client(),
        _provider = provider ?? _resolveProvider();

  final http.Client _client;
  final AiProvider _provider;

  static AiProvider _resolveProvider() {
    if (_hasValidKey(AiConfig.openAiApiKey)) {
      return AiProvider.openAi;
    }
    return AiProvider.gemini;
  }

  Future<String> sendChatCompletion({
    required List<AiChatMessage> messages,
  }) async {
    switch (_provider) {
      case AiProvider.openAi:
        return _sendOpenAi(messages);
      case AiProvider.gemini:
        return _sendGemini(messages);
    }
  }

  Future<String> _sendOpenAi(List<AiChatMessage> messages) async {
    if (!_hasValidKey(AiConfig.openAiApiKey)) {
      throw AiChatException(
        'OpenAI API key missing. Set OPENAI_API_KEY via dart-define or replace the placeholder.',
      );
    }

    final uri = Uri.parse('${AiConfig.openAiBaseUrl}/chat/completions');
    final payload = <String, dynamic>{
      'model': AiConfig.openAiModel,
      'temperature': 0.2,
      'messages': messages
          .map((message) => {
                'role': message.role,
                'content': message.content,
              })
          .toList(),
    };

    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer ${AiConfig.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    return _parseOpenAiResponse(response);
  }

  Future<String> _sendGemini(List<AiChatMessage> messages) async {
    if (!_hasValidKey(AiConfig.geminiApiKey)) {
      throw AiChatException(
        'Gemini API key missing. Set GEMINI_API_KEY via dart-define or replace the placeholder.',
      );
    }

    final uri = Uri.parse(
      '${AiConfig.geminiBaseUrl}/${AiConfig.geminiModel}:generateContent?key=${AiConfig.geminiApiKey}',
    );

    final content = messages
        .where((message) => message.role != 'system')
        .map((message) => {
              'role': message.role == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': message.content}
              ],
            })
        .toList();

    final payload = <String, dynamic>{
      'contents': content,
      'generationConfig': {
        'temperature': 0.2,
      },
    };

    final response = await _client.post(
      uri,
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    return _parseGeminiResponse(response);
  }

  String _parseOpenAiResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiChatException(
        'OpenAI request failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw AiChatException('OpenAI response missing choices.');
    }
    final message =
        choices.first['message'] as Map<String, dynamic>? ?? const {};
    final content = message['content'] as String?;
    if (content == null || content.isEmpty) {
      throw AiChatException('OpenAI response missing content.');
    }
    return content.trim();
  }

  String _parseGeminiResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiChatException(
        'Gemini request failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw AiChatException('Gemini response missing candidates.');
    }
    final content =
        candidates.first['content'] as Map<String, dynamic>? ?? const {};
    final parts = content['parts'] as List<dynamic>? ?? const [];
    final textPart = parts.firstWhere(
      (part) => part is Map && part['text'] != null,
      orElse: () => null,
    );
    if (textPart == null) {
      throw AiChatException('Gemini response missing text content.');
    }
    return (textPart['text'] as String).trim();
  }

  static bool _hasValidKey(String key) =>
      key.isNotEmpty && !key.toLowerCase().contains('replace');
}
