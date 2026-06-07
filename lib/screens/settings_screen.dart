import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'controls_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hostController = TextEditingController(text: '192.5.6.20');
  final _portController = TextEditingController(text: '22');
  final _userController = TextEditingController(text: 'liquidgalaxy');
  final _passwordController = TextEditingController(text: 'lg');
  final _screensController = TextEditingController(text: '3');

  bool _isConnecting = false;
  String _errorMessage = '';

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 22;
    final username = _userController.text.trim();
    final password = _passwordController.text;
    final screens = int.tryParse(_screensController.text) ?? 3;

    setState(() {
      _isConnecting = true;
      _errorMessage = '';
    });

    try {
      final socket = await SSHSocket.connect(host, port);
      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      await client.authenticated;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ControlsScreen(
              client: client,
              host: host,
              screens: screens,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed: $e';
        _isConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _screensController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // ── Scan QR Code button ──────────────────────────────
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: implement QR scanner
                },
                icon: const Icon(Icons.qr_code_scanner_outlined,
                    color: Color(0xFF555555)),
                label: const Text(
                  'Scan QR Code',
                  style: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFEBEBE6),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── "or" divider ─────────────────────────────────────
              const Center(
                child: Text(
                  'or',
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Input fields ─────────────────────────────────────
              _buildField(
                label: 'Host',
                hint: 'Enter your host IP',
                controller: _hostController,
              ),
              _buildField(
                label: 'Port',
                controller: _portController,
                isNumber: true,
              ),
              _buildField(
                label: 'User',
                controller: _userController,
              ),
              _buildField(
                label: 'Pass',
                controller: _passwordController,
                isPassword: true,
              ),
              _buildField(
                label: 'Screen',
                controller: _screensController,
                isNumber: true,
              ),

              // ── Error message ────────────────────────────────────
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── Connect to LG button ─────────────────────────────
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A7C59),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF4A7C59).withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Connect to LG'),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),

      // ── Bottom navigation bar ────────────────────────────────────
      bottomNavigationBar: _SettingsBottomNav(),
    );
  }

  Widget _buildField({
    required String label,
    String? hint,
    required TextEditingController controller,
    bool isPassword = false,
    bool isNumber = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBE6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          hintStyle: const TextStyle(
            color: Color(0xFFAAAAAA),
            fontSize: 13,
          ),
          // Clear (×) button on the right
          suffixIcon: IconButton(
            icon: const Icon(Icons.cancel_outlined,
                color: Color(0xFFAAAAAA), size: 20),
            onPressed: () => controller.clear(),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bottom nav — Settings tab is active
// ──────────────────────────────────────────────────────────────
class _SettingsBottomNav extends StatelessWidget {
  const _SettingsBottomNav();

  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'Maps', 'Chat', 'Tools', 'Settings'];
    const activeIndex = 4;

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
            children: List.generate(labels.length, (i) {
              final selected = i == activeIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i == 0) Navigator.pop(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                        labels[i],
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