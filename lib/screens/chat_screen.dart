import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  ChatMessage(this.text, {this.fromUser = false});
}

class ChatModel {
  final List<ChatMessage> messages = [];
  ChatService? _service;
  bool isLoading = false;

  void setService(ChatService svc) {
    _service = svc;
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    messages.add(ChatMessage(text, fromUser: true));
    isLoading = true;

    try {
      final resp = await _service!.sendMessage(text);
      messages.add(ChatMessage(resp, fromUser: false));
    } catch (e) {
      messages.add(ChatMessage('Error: $e', fromUser: false));
    } finally {
      isLoading = false;
    }
  }

  Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openai_api_key');
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_key', key);
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatModel model = ChatModel();
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final key = await model.loadApiKey();
    if (key != null && key.isNotEmpty) {
      model.setService(ChatService(apiKey: key));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: model.messages.length,
              itemBuilder: (context, i) {
                final msg = model.messages[i];
                return Align(
                  alignment: msg.fromUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: msg.fromUser
                          ? Colors.blueAccent
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(msg.text,
                        style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          if (model.isLoading) const LinearProgressIndicator(minHeight: 3),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration:
                          const InputDecoration(hintText: 'Write a message...'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final txt = _ctrl.text.trim();
                      if (txt.isEmpty) return;
                      if (model._service == null) {
                        // Ask for API key
                        final key = await _askForApiKey(context);
                        if (key == null || key.isEmpty) return;
                        await model.saveApiKey(key);
                        model.setService(ChatService(apiKey: key));
                        setState(() {});
                      }
                      _ctrl.clear();
                      await model.send(txt);
                      setState(() {});
                    },
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askForApiKey(BuildContext context) async {
    final t = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enter OpenAI API Key'),
        content: TextField(
            controller: t,
            decoration: const InputDecoration(hintText: 'sk-...')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(null),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(t.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
  }
}
