class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://codingclubskenya.com/deheus-api',
  );

  static String aiChatUrl() => '$baseUrl/api/ai/chat';
}
