import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import '../services/chat_service.dart';
import '../providers/nav_bar_provider.dart';

class ChatScreen extends StatefulWidget {
  final SSHClient? client;
  final String host;
  final int screens;
  final bool isConnected;

  const ChatScreen({super.key, required this.client, required this.host, required this.screens, required this.isConnected});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _svc = ChatService();
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  String? _apiKey;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _svc.getSavedApiKey();
    setState(() => _apiKey = key);
  }

  Future<void> _promptForKey() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter your Gemini API key'),
        content: TextField(controller: ctrl, obscureText: true,
          decoration: const InputDecoration(hintText: 'API key')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _svc.saveApiKey(result);
      setState(() => _apiKey = result);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _apiKey == null) return;
    setState(() {
      _messages.add(ChatMessage('user', text));
      _inputCtrl.clear();
      _sending = true;
    });
    try {
      final reply = await _svc.sendMessage(_apiKey!, _messages.sublist(0, _messages.length - 1), text);
      setState(() => _messages.add(ChatMessage('model', reply)));
    } catch (e) {
      setState(() => _messages.add(ChatMessage('model', 'Error: $e')));
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask about species'), actions: [
        IconButton(icon: const Icon(Icons.vpn_key), onPressed: _promptForKey),
      ]),
      body: _apiKey == null
          ? Center(
              child: ElevatedButton(onPressed: _promptForKey, child: const Text('Add your Gemini API key to start')),
            )
          : Column(children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isUser = m.role == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF4A7C59) : const Color(0xFFEBEBE6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(m.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
                      ),
                    );
                  },
                ),
              ),
              if (_sending) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(child: TextField(controller: _inputCtrl, decoration: const InputDecoration(hintText: 'Ask something...'))),
                  IconButton(icon: const Icon(Icons.send), onPressed: _sending ? null : _send),
                ]),
              ),
            ]),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2, client: widget.client, host: widget.host, screens: widget.screens, isConnected: widget.isConnected,
      ),
    );
  }
}