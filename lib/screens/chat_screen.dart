import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import '../services/chat_service.dart';
import '../screens/home_screen.dart';

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
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String? _apiKey;
  bool _sending = false;

  List<ChatMessage> get _messages => _svc.messages;

  @override
  void initState() {
    super.initState();
    _loadKey();
    if (_messages.isNotEmpty) {
      _scrollToBottom();
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter your Gemini API key'),
        content: TextField(controller: ctrl, obscureText: true,
          decoration: const InputDecoration(hintText: 'API key')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _svc.saveApiKey(result);
      setState(() => _apiKey = result);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _apiKey == null || _sending) return;
    setState(() {
      _messages.add(ChatMessage('user', text));
      _inputCtrl.clear();
      _sending = true;
    });
    _scrollToBottom();
    try {
      final reply = await _svc.sendMessage(_apiKey!, _messages.sublist(0, _messages.length - 1), text);
      setState(() => _messages.add(ChatMessage('model', reply)));
    } catch (e) {
      setState(() => _messages.add(ChatMessage('model', "Sorry, something went wrong: $e")));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // "Back": just leave, conversation stays in the singleton for next time.
  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(
          client: widget.client, host: widget.host,
          screens: widget.screens, isConnected: widget.isConnected,
        )),
      );
    }
  }

  Future<void> _confirmEndChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End chat?'),
        content: const Text('This will clear the conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false), 
            child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End chat'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _svc.clearConversation();
    _goBack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Type here to ask about the app or species..'),
        backgroundColor: const Color(0xFF4A7C59),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack),
        actions: [
          IconButton(icon: const Icon(Icons.vpn_key_outlined), onPressed: _promptForKey, tooltip: 'API key'),
          IconButton(icon: const Icon(Icons.close), onPressed: _confirmEndChat, tooltip: 'End chat'),
        ],
      ),
      body: _apiKey == null
          ? Center(
              child: ElevatedButton(
                onPressed: _promptForKey,
                child: const Text('Add your Gemini API key to start'),
              ),
            )
          : Column(children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length) return const _TypingBubble();
                    final m = _messages[i];
                    return _ChatBubble(message: m);
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: TextField(
                          controller: _inputCtrl,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Ask about a species...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF4A7C59),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                        onPressed: _sending ? null : _send,
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF4A7C59) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text(message.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 14, height: 1.4)),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
              final delay = i * 0.2;
              final t = (_ctrl.value - delay) % 1.0;
              final opacity = t < 0.5 ? (0.3 + t) : (1.3 - t);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: opacity.clamp(0.3, 1.0),
                  child: const CircleAvatar(radius: 3.5, backgroundColor: Colors.black54),
                ),
              );
            }));
          },
        ),
      ),
    );
  }
}