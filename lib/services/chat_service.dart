import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../data/species_data.dart';

class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  ChatMessage(this.role, this.text);
}

class ChatService {
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent';

  Future<String?> getSavedApiKey() async {
    final box = await Hive.openBox('user_settings');
    return box.get('chat_gemini_key') as String?;
  }

  Future<void> saveApiKey(String key) async {
    final box = await Hive.openBox('user_settings');
    await box.put('chat_gemini_key', key);
  }

  String _systemContext() {
    final speciesList = vietnamSpecies
        .map((s) => '${s.commonName} (${s.scientificName}, ${s.category}, ${s.group}): ${s.habitat}. Threats: ${s.threats}.')
        .join('\n');
    return '''
You are a helpful assistant inside the "LG Red List Endangered Species Living Atlas" app,
a Liquid Galaxy exhibit about Vietnam's critically endangered and endangered species.
Answer questions about the app's features (map, species pins, History Journey, Looking Ahead)
and about the species below, using only this data. If asked something unrelated, politely
redirect to the app's topic.

SPECIES DATA:
$speciesList
''';
  }

  Future<String> sendMessage(String apiKey, List<ChatMessage> history, String newMessage) async {
    final contents = [
      {'role': 'user', 'parts': [{'text': _systemContext()}]},
      {'role': 'model', 'parts': [{'text': 'Understood, I can help with the app and these species.'}]},
      ...history.map((m) => {'role': m.role, 'parts': [{'text': m.text}]}),
      {'role': 'user', 'parts': [{'text': newMessage}]},
    ];

    final res = await http.post(
      Uri.parse(_geminiUrl),
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
      body: json.encode({'contents': contents}),
    ).timeout(const Duration(seconds: 25));

    if (res.statusCode == 200) {
      return (json.decode(res.body)['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?) ?? "Sorry, I couldn't generate a response.";
    }
    if (res.statusCode == 400 || res.statusCode == 403) {
      throw Exception('Invalid API key');
    }
    throw Exception('Gemini returned ${res.statusCode}');
  }
}