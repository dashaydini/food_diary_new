import 'dart:convert';

import 'package:http/http.dart' as http;

/// Very small wrapper for calling OpenAI Chat Completions API.
///
/// Usage:
/// final svc = ChatService(apiKey: await getApiKey());
/// final reply = await svc.sendMessage('Hello');
class ChatService {
  final String apiKey;
  final String apiBase;
  final String model;

  ChatService(
      {required this.apiKey,
      this.apiBase = 'https://api.openai.com/v1',
      this.model = 'gpt-3.5-turbo'});

  Future<String> sendMessage(String message) async {
    final url = Uri.parse('$apiBase/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': message}
      ],
      'max_tokens': 800,
    });

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('API error ${resp.statusCode}: ${resp.body}');
    }

    final Map<String, dynamic> data = jsonDecode(resp.body);
    final content = data['choices']?[0]?['message']?['content'] as String?;
    return content ?? '';
  }
}
