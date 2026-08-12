import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:provider/provider.dart';
import 'settings_screen.dart';
import '../providers/nav_bar_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/dark_mode_toggle.dart';

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
        client: _client,
        host: _host,
        screens: _screens,
        isConnected: _isConnected,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F0);
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF222222) : const Color(0xFFDDDDDD);

    return Scaffold(
      backgroundColor: bgColor,
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
              Text(
                'Hey there,\nnice to meet you,\nI\'m Angela.\nReady to dive in?\nLet\'s explore the living\nworld together and see\nwhich species need our\nhelp.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
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
                  Text(
                    'Status:',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
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
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? const Color(0xFF444444) 
                      : (_isConnected ? Colors.grey.shade300 : Colors.green.shade300),
                    ),
                    backgroundColor: isDark ? const Color(0xFF222222) 
                    : (_isConnected ? Colors.grey : Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: Text(
                    _isConnected ? 'Disconnect' : 'Connect',
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Dark mode toggle (bottom-left, above nav bar) ─────────
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DarkModeToggle(),
                ),
              ),
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
