import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'app_bottom_nav.dart';

class SettingsScreen extends StatefulWidget {
  final SSHClient? client; // store the SSH client for later use
  final String host; // store the host for later use
  final int screens; // store the number of screens for later use
  final bool isConnected; // update from SSH connection state

  const SettingsScreen({
    super.key,
    this.client,
    this.host = '',
    this.screens = 3,
    this.isConnected = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  late final TextEditingController _screensController;

  bool _isConnecting = false;
  String _errorMessage = '';
  late bool _isConnected; // update from SSH connection state
  late SSHClient? _client; // store the SSH client for later use

  void initState() {
    super.initState();
    _isConnected = widget.isConnected;
    _client = widget.client;
    _hostController = TextEditingController(text: '192.168.56.101');
    _portController = TextEditingController(text: '22');
    _userController = TextEditingController(text: 'lg1');
    _passwordController = TextEditingController(text: 'lq');
    _screensController = TextEditingController(text: widget.screens.toString());
  }

  // QR scanner controller
  // Expected QR JSON format:
  // {
  //   "username": "lg",
  //   "ip": "192.168.1.10",
  //   "port": "22",
  //   "password": "lqgalaxy",
  //   "screens": "5"
  // }
  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _QrScannerScreen(
        onScanned: (raw) => _parseQrData(raw),
      )),
    );
  }

  void _parseQrData(String raw) {
    try {
      final Map<String, dynamic> data = json.decode(raw);

      // Validate all required keys are present
      final requiredKeys = ['username', 'ip', 'port', 'password', 'screens'];
      final missing = requiredKeys.where((k) => !data.containsKey(k)).toList();
      if (missing.isNotEmpty) {
        setState(() {
          _errorMessage = 'QR missing fields: ${missing.join(', ')}';
        });
        return;
      }

      setState(() {
        _hostController.text     = data['ip'].toString().trim();
        _portController.text     = data['port'].toString().trim();
        _userController.text     = data['username'].toString().trim();
        _passwordController.text = data['password'].toString().trim();
        _screensController.text  = data['screens'].toString().trim();
        _errorMessage            = '';
      });
    } on FormatException {
      setState(() {
        _errorMessage =
            'QR format not recognised.\n'
            'Expected JSON with: username, ip, port, password, screens';
      });
    }
  }

  // Connect to LG via SSH
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
        setState(() {
          _isConnected = true;
          _client = client;
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed: $e';
        _isConnecting = false;
        _isConnected = false;
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

  // UI
  @override
  Widget build(BuildContext context) {
    final host = _hostController.text.trim();
    final screens = int.tryParse(_screensController.text) ?? widget.screens;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF4A7C59),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
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
                  _openQrScanner();
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
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        client: _client,
        host: host,
        screens: screens,
        isConnected: _isConnected,
      ),
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

// ══════════════════════════════════════════════════════════════════
// QR Scanner screen
// ══════════════════════════════════════════════════════════════════
class _QrScannerScreen extends StatefulWidget {
  final ValueChanged<String> onScanned;
  const _QrScannerScreen({required this.onScanned});

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _scanned = false; // prevent firing twice

  @override
  void dispose() {
  _scannerController.dispose();
  super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
  if (_scanned) return;
  final barcode = capture.barcodes.firstOrNull;
  final value = barcode?.rawValue;
  if (value == null) return;

  _scanned = true;
  _scannerController.stop();
  Navigator.of(context).pop(); // close scanner
  widget.onScanned(value); // pass data back
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
  backgroundColor: Colors.black,
  body: Stack(
  children: [
  // ── Live camera feed ───────────────────────────────────
  MobileScanner(
  controller: _scannerController,
  onDetect: _onDetect,
  ),

  // ── Overlay: dimmed border + scan window ───────────────
  _ScanOverlay(),

  // ── Top bar ────────────────────────────────────────────
  SafeArea(
  child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
  // Back button
  IconButton(
  icon: const Icon(Icons.arrow_back_ios_new,
  color: Colors.white),
  onPressed: () => Navigator.of(context).pop(),
  ),
  const Text(
  'Scan QR Code',
  style: TextStyle(
  color: Colors.white,
  fontSize: 17,
  fontWeight: FontWeight.w600,
  ),
  ),
  // Torch toggle
  ValueListenableBuilder(
  valueListenable: _scannerController,
  builder: (_, state, __) {
  final torchOn =
  state.torchState == TorchState.on;
  return IconButton(
  icon: Icon(
  torchOn
  ? Icons.flashlight_on
  : Icons.flashlight_off,
  color: Colors.white,
  ),
  onPressed: () =>
  _scannerController.toggleTorch(),
  );
  },
  ),
  ],
  ),
  ),
  ),

  // ── Bottom hint ─────────────────────────────────────────
  Positioned(
  bottom: 60,
  left: 0, right: 0,
  child: Column(
  children: const [
  Text(
  'Point the camera at the LG QR code',
  textAlign: TextAlign.center,
  style: TextStyle(
  color: Colors.white70,
  fontSize: 14,
  ),
  ),
  SizedBox(height: 6),
  Text(
  'Format: host | port | user | pass | screens',
  textAlign: TextAlign.center,
  style: TextStyle(
  color: Colors.white38,
  fontSize: 12,
  ),
  ),
  ],
  ),
  ),
  ],
  ),
  );
  }
}

// ──────────────────────────────────────────────────────────────
// Scan overlay: dark surround + bright square cutout + corner marks
// ──────────────────────────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
  const windowSize = 260.0;
  return LayoutBuilder(builder: (context, constraints) {
  final cx = constraints.maxWidth / 2;
  final cy = constraints.maxHeight / 2;
  final left = cx - windowSize / 2;
  final top = cy - windowSize / 2;
  final right = cx + windowSize / 2;
  final bottom = cy + windowSize / 2;

  return Stack(
  children: [
  // dark surround
  CustomPaint(
  size: Size(constraints.maxWidth, constraints.maxHeight),
  painter: _DimPainter(
  cutout: Rect.fromLTRB(left, top, right, bottom),
  ),
  ),
  // corner brackets
  Positioned(
  left: left, top: top,
  child: _CornerBracket(corner: _Corner.topLeft),
  ),
  Positioned(
  right: constraints.maxWidth - right, top: top,
  child: _CornerBracket(corner: _Corner.topRight),
  ),
  Positioned(
  left: left, bottom: constraints.maxHeight - bottom,
  child: _CornerBracket(corner: _Corner.bottomLeft),
  ),
  Positioned(
  right: constraints.maxWidth - right,
  bottom: constraints.maxHeight - bottom,
  child: _CornerBracket(corner: _Corner.bottomRight),
  ),
  ],
  );
  });
  }
}

class _DimPainter extends CustomPainter {
  final Rect cutout;
  const _DimPainter({required this.cutout});

  @override
  void paint(Canvas canvas, Size size) {
  final paint = Paint()..color = Colors.black.withOpacity(0.55);
  final full = Rect.fromLTWH(0, 0, size.width, size.height);
  final path = Path()
  ..addRect(full)
  ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(12)))
  ..fillType = PathFillType.evenOdd;
  canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerBracket extends StatelessWidget {
  final _Corner corner;
  const _CornerBracket({required this.corner});

  @override
  Widget build(BuildContext context) {
  const len = 24.0;
  const thick = 3.5;
  const color = Color(0xFF4A7C59);
  const r = Radius.circular(3);

  final isLeft = corner == _Corner.topLeft || corner == _Corner.bottomLeft;
  final isTop = corner == _Corner.topLeft || corner == _Corner.topRight;

  return SizedBox(
  width: len, height: len,
  child: Stack(children: [
  // horizontal arm
  Positioned(
  left: isLeft ? 0 : null,
  right: isLeft ? null : 0,
  top: isTop ? 0 : null,
  bottom: isTop ? null : 0,
  child: Container(
  width: len, height: thick,
  decoration: BoxDecoration(
  color: color,
  borderRadius: BorderRadius.only(
  topLeft: (isLeft && isTop) ? r : Radius.zero,
  topRight: (!isLeft && isTop) ? r : Radius.zero,
  bottomLeft: (isLeft && !isTop) ? r : Radius.zero,
  bottomRight: (!isLeft && !isTop) ? r : Radius.zero,
  ),
  ),
  ),
  ),
  // vertical arm
  Positioned(
  left: isLeft ? 0 : null,
  right: isLeft ? null : 0,
  top: isTop ? 0 : null,
  bottom: isTop ? null : 0,
  child: Container(
  width: thick, height: len,
  decoration: BoxDecoration(
  color: color,
  borderRadius: BorderRadius.only(
  topLeft: (isLeft && isTop) ? r : Radius.zero,
  topRight: (!isLeft && isTop) ? r : Radius.zero,
  bottomLeft: (isLeft && !isTop) ? r : Radius.zero,
  bottomRight: (!isLeft && !isTop) ? r : Radius.zero,
  ),
  ),
  ),
  ),
  ]),
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