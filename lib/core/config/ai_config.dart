class AiConfig {
  const AiConfig._();

  static const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY',
      defaultValue: 'REPLACE_WITH_OPENAI_API_KEY');

  static const openAiBaseUrl = String.fromEnvironment('OPENAI_BASE_URL',
      defaultValue: 'https://api.openai.com/v1');

  static const openAiModel =
      String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-3.5-turbo');

  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY',
      defaultValue: 'YOUR_GEMINI_API_KEY_HERE');

  static const geminiBaseUrl = String.fromEnvironment(
    'GEMINI_BASE_URL',
    defaultValue: 'https://generativelanguage.googleapis.com/v1beta',
  );

  static const geminiModel = String.fromEnvironment('GEMINI_MODEL',
      defaultValue: 'models/gemini-1.5-flash');
}
