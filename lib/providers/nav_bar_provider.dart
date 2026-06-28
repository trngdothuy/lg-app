import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';

// Forward declarations to avoid circular imports
import '../screens/home_screen.dart';
import '../screens/tools_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/maps_screen.dart';

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final SSHClient? client;
  final String host;
  final int screens;
  final bool isConnected;
  final bool isDark;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.client,
    required this.host,
    required this.screens,
    required this.isConnected,
    this.isDark = false,
  });

  void _onTap(BuildContext context, int index) {
    if (index == selectedIndex) return;

    Widget target;
    switch (index) {
      case 0:
        target = HomeScreen(
          client: client,
          host: host,
          screens: screens,
          isConnected: isConnected,
        );
        break;
      case 1:
        target = MapsScreen(
          client: client,
          host: host,
          screens: screens,
          isConnected: isConnected,
        );
        break;
      case 3:
        target = ToolsScreen(
          client: client,
          host: host,
          screens: screens,
          isConnected: isConnected,
        );
        break;
      case 4:
        target = SettingsScreen(
          client: client,
          host: host,
          screens: screens,
          isConnected: isConnected,
        );
        break;
      default:
        return; // Maps/Chat not yet implemented
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'Maps', 'Chat', 'Tools', 'Settings'];

    final bg      = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final border  = isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE);
    final selCol  = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final unselCol = isDark ? Colors.white38 : const Color(0xFF999999);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(labels.length, (i) {
              final sel = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTap(context, i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (sel)
                        Container(
                          width: 28,
                          height: 2.5,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: selCol,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        const SizedBox(height: 6.5),
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: sel ? selCol : unselCol,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
