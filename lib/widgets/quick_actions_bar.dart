import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import '../screens/chat_screen.dart';
import '../screens/tools_screen.dart';

class QuickActionsBar extends StatelessWidget {
  final SSHClient? client;
  final String host;
  final int screens;
  final bool isConnected;

  const QuickActionsBar({
    super.key,
    required this.client,
    required this.host,
    required this.screens,
    required this.isConnected,
  });

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _iconButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.black54, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _iconButton(context, Icons.chat_bubble_outline, () => _open(context, ChatScreen(
        client: client, host: host, screens: screens, isConnected: isConnected,
      ))),
      _iconButton(context, Icons.build_outlined, () => _open(context, ToolsScreen(
        client: client, host: host, screens: screens, isConnected: isConnected,
      ))),
    ]);
  }
}