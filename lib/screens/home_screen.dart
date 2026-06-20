import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'settings_screen.dart';
// import 'tools_screen.dart';
import 'app_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  final SSHClient? client; // store the SSH client for later use
  final String host; // store the host for later use
  final int screens; // store the number of screens for later use
  final bool isConnected; // update from SSH connection state

  const HomeScreen({
    super.key,
    this.client,
    this.host = '',
    this.screens = 3,
    this.isConnected = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late bool _isConnected; // update from SSH connection state
  late SSHClient? _client; // store the SSH client for later use
  late String _host; // store the host for later use
  late int _screens; // store the number of screens for later use

  @override
  void initState() {
    super.initState();
    _isConnected = widget.isConnected;
    _client = widget.client;
    _host = widget.host;
    _screens = widget.screens;
  }

  void _openSettings() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          // client: _client,
          // host: _host,
          // screens: _screens,
          // isConnected: _isConnected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Avatar ──────────────────────────────────────────
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/avatar/avatar.gif',
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE8C84A),
                      child: const Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Greeting text ────────────────────────────────────
              const Text(
                'Hey there,\nnice to meet you,\nI\'m Angela.\nReady to dive in?\nLet\'s explore the living\nworld together and see\nwhich species need our\nhelp.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2A2A2A),
                  fontSize: 19,
                  fontWeight: FontWeight.w400,
                  height: 1.65,
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 40),

              // ── Status row ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                    ),
                    child: Text(
                      _isConnected ? 'Connected' : 'Not Connected',
                      style: TextStyle(
                        color: _isConnected
                            ? const Color(0xFF4A8C5C)
                            : const Color(0xFF555555),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Connect button ───────────────────────────────────
              SizedBox(
                width: 160,
                child: OutlinedButton(
                  onPressed: _openSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2A2A2A),
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Connect'),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),

      // ── Bottom navigation bar ────────────────────────────────────
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 0,
        client: _client,
        host: _host,
        screens: _screens,
        isConnected: _isConnected,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bottom navigation bar
// ──────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(label: 'Home', icon: Icons.home_outlined),
      _NavItem(label: 'Maps', icon: Icons.map_outlined),
      _NavItem(label: 'Chat', icon: Icons.chat_bubble_outline),
      _NavItem(label: 'Tools', icon: Icons.build_outlined),
      _NavItem(label: 'Settings', icon: Icons.settings_outlined),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // underline for selected tab
                      if (selected)
                        Container(
                          width: 28,
                          height: 2.5,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        const SizedBox(height: 6.5),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF999999),
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
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

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}