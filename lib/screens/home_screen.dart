import 'package:flutter/material.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isConnected = false; // update from SSH connection state

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    if (index == 4) {
      // Settings tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ).then((connected) {
        if (connected == true) {
          setState(() => _isConnected = true);
        }
      });
    }
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
                  child: Image.network(
                    'https://cdn.myportfolio.com/17be4dd08c5417027a544816a909fcf8/fb2dab8c-5de5-47ba-96bc-c262ccdcdad0_rw_600.gif?h=adec1dcadf3bdfb29a908988bfeb432e', 
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ).then((connected) {
                      if (connected == true) {
                        setState(() => _isConnected = true);
                      }
                    });
                  },
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
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
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