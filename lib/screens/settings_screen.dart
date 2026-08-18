import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:red_list_endangered_species_vietnam_app/services/lg_service.dart';
import '../../providers/nav_bar_provider.dart';
import '../providers/theme_provider.dart';
import 'tools_screen.dart';
import 'maps_screen.dart';
import 'home_screen.dart';
import '../data/species_data.dart';
import '../services/species_service.dart';
import '../widgets/dark_mode_toggle.dart';
import '../widgets/quick_actions_bar.dart';

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
  String _connectionStatus = '';
  bool _obscurePassword = true;
  String _errorMessage = '';
  late bool _isConnected; // update from SSH connection state
  late SSHClient? _client; // store the SSH client for later use
  LGService? _lg;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.isConnected;
    _client = widget.client;
    _hostController = TextEditingController(text: '192.168.56.101');
    _portController = TextEditingController(text: '22');
    _userController = TextEditingController(text: 'lg1');
    _passwordController = TextEditingController(text: 'lg');
    _screensController = TextEditingController(text: widget.screens.toString());
  }

  // int _preloadDone = 0;
  // int _preloadTotal = 0;
  // bool _preloading = false;

  // Future<void> _preloadStories() async {
  //   setState(() {
  //     _preloading = true;
  //     _preloadDone = 0;
  //     _preloadTotal = vietnamSpecies.length * 3;
  //   });

  //   final svc = SpeciesService();
  //   await svc.preloadAllStories(
  //     vietnamSpecies,
  //     onProgress: (done, total) => setState(() {
  //       _preloadDone = done;
  //       _preloadTotal = total;
  //     }),
  //   );

  //   setState(() => _preloading = false);
  // }

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

  // Disconnect
  Future<void> _disconnect() async {
    setState(() {
      _client = null;
      _isConnected = false;
      _connectionStatus = '';
    });

     Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(),
      ),
    );
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
      _connectionStatus = 'Connecting to Liquid Galaxy...';
    });

    // fake connection for testing
    // await Future.delayed(const Duration(seconds: 2));
    // setState(() => _isConnecting = false);
    // if (mounted) {
    //     setState(() {
    //       _isConnected = true;
    //       // _client = client;
    //       _isConnecting = false;
    //     });
    //   }
    // return;

    try {
      
      final socket = await SSHSocket.connect(host, port);
      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      await client.authenticated;

      // setState(() {
      //   _connectionStatus = 'Connected. Preparing Liquid Galaxy...';
      // });

      // fly to Vietnam and send logo only after successful connection
      await _flyToVietnam(client);
      // await _setRefresh(client);
      // await Future.delayed(const Duration(seconds: 5));
      
      setState(() {
        _connectionStatus = 'Uploading logo...';
      });
      await _sendLogo(client);

      setState(() {
        _connectionStatus = 'Uploading species markers...';
      });

      final lg = LGService(client: client, host: host, screens: screens);
      await lg.uploadPawModel();
      await lg.uploadPawIcon();
      await lg.uploadSpeciesImages(vietnamSpecies);

      await Future.delayed(
        const Duration(seconds: 1),
      );

      setState(() {
        _connectionStatus = 'Configuring displays...';
      });

      await _run(
          client,
          "mkdir -p /var/www/html/images",
      );

      await _run(
          client,
          "mkdir -p /var/www/html/kml",
      );

      if (mounted) {
        // setState(() {
        //   _isConnected = true;
        //   _client = client;
        //   _isConnecting = false;
        // });

        setState(() {
          _client = client;
          _isConnected = true;
          _isConnecting = false;
          _connectionStatus = 'Opening Maps...';
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MapsScreen(
              client: client,
              host: host,
              screens: screens,
              isConnected: true,
            ),
          ),
        );
      }
    } catch (e) {
        String reason = e.toString();

        if (reason.contains('SocketException')) {
          reason = 'Cannot reach the host. Check the IP address and network.';
        } else if (reason.contains('Handshake')) {
          reason = 'SSH handshake failed.';
        } else if (reason.contains('Timeout')) {
          reason = 'Connection timed out.';
        } else if (reason.contains('authentication')) {
          reason = 'Incorrect username or password.';
        }

        setState(() {
          _errorMessage = reason;
          _connectionStatus = '';
          _isConnecting = false;
          _isConnected = false;
        });
      }
  }
  

  Future<void> _run(SSHClient client, String cmd) async {
    print("RUN: $cmd");

    final session = await client.execute(cmd);

    final stdout = await utf8.decodeStream(session.stdout);
    final stderr = await utf8.decodeStream(session.stderr);

    final exitCode = await session.exitCode;
    print("Exit: $exitCode");

    print("STDOUT:\n$stdout");
    print("STDERR:\n$stderr");
  }

  Future<void> _flyToVietnam(SSHClient client) async {
    final screens = int.tryParse(_screensController.text) ?? 3;

    setState(() {
      _connectionStatus = 'Sending startup commands...';
    });

    print('Preparing to send flyTo.kml to LG...');

    // Load KML file from assets and encode it in base64
    final String flyKml = await rootBundle.loadString('assets/kml/flyTo.kml');
    final base64EncodedKml = base64Encode(utf8.encode(flyKml));
    print('KML file loaded and encoded in base64.');

    // Upload KML file
    await _run(client, 
      "echo '$base64EncodedKml' | base64 -d > /var/www/html/kml/flyTo.kml");
    print('flyTo.kml uploaded to /var/www/html/kml/flyTo.kml');

    // Write to kmls.txt
    await _run(client, 
      "echo 'http://lg1:81/kml/flyTo.kml' > /var/www/html/kmls.txt");
    print('flyTo.kml URL written to /var/www/html/kmls.txt');
    print('Preparing to trigger flyTo on each screen...');
    // Trigger flyTo on each screen via query.txt
    for (int i = 1; i <= screens; i++) {
      await _run(client,
        "sshpass -p lg ssh -o StrictHostKeyChecking=no lg$i@lg$i "
        "'echo \"http://lg1:81/kml/flyTo.kml\" > /tmp/query.txt'");
    }
    print('Fly to Vietnam command sent to $screens screens.');
  }

  // send logo
  Future<void> _sendLogo(SSHClient client) async {
    // setState(() {
    //   _connectionStatus = 'Uploading logo...';
    // });

    final int screens = int.tryParse(_screensController.text) ?? 3;
    final int leftMostScreen = (screens ~/ 2) + 2;

    // read logo as raw bytes
    final ByteData data = await rootBundle.load('assets/logo/logo_liquid_galaxy.jpg');
    final List<int> bytes = data.buffer.asUint8List();
    final String base64Logo = base64Encode(bytes);

    await _run(client,
        "echo '$base64Logo' | base64 -d > /var/www/html/logo.png"
    );

    final String kml = '''<?xml version="1.0" encoding="UTF-8"?>
  <kml xmlns="http://www.opengis.net/kml/2.2">
      <Document>
          <ScreenOverlay>
              <name>LG Logo</name>
              <Icon>
                  <href>http://lg1:81/logo.png</href>
              </Icon>
              <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
              <screenXY x="0.02" y="0.95" xunits="fraction" yunits="fraction"/>
              <size x="300" y="0" xunits="pixels" yunits="pixels"/>
          </ScreenOverlay>
      </Document>
  </kml>''';

  final String base64KML = base64Encode(utf8.encode(kml));
  await _run(client,
      "echo '$base64KML' | base64 -d > /var/www/html/kml/slave_$leftMostScreen.kml"
  );

  await _setRefresh(client);
  }

  // Refresh
  Future<void> _setRefresh(SSHClient client) async {
    final int screens = int.tryParse(_screensController.text) ?? 3;

    for (var i = 2; i <= screens; i++) {
      final s = '<href>##LG_PHPIFACE##kml\\/slave_$i.kml<\\/href>';
      final r = '$s<refreshMode>onInterval<\\/refreshMode>'
          '<refreshInterval>2<\\/refreshInterval>';
      await _run(client, 
        "sshpass -p lg ssh -t lg$i@lg$i "
        "'echo lg | sudo -S sed -i \"s/$r/$s/\" ~/earth/kml/slave/myplaces.kml'",
      );
      await _run(client,
        "sshpass -p lg ssh -t lg$i@lg$i "
        "'echo lg | sudo -S sed -i \"s/$s/$r/\" ~/earth/kml/slave/myplaces.kml'",
      );
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
    final isDark = context.watch<ThemeProvider>().isDark;
    final backgroundColor =
      isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F0);
    final fieldColor =
      isDark ? const Color(0xFF222222) : const Color(0xFFEBEBE6);
    final primaryText =
      isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryText =
      isDark ? Colors.white70 : const Color(0xFF555555);

    final host = _hostController.text.trim();
    final screens = int.tryParse(_screensController.text) ?? widget.screens;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF4A7C59),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Layer 1: scrolling content
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Connected badge (top right) ──────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, top: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check,
                      size: 14,
                      color: _isConnected
                          ? const Color(0xFF2E7D32)
                          : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'Connected' : 'Not Connected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isConnected
                            ? const Color(0xFF2E7D32)
                            : Colors.grey,
                      ),
                    ),
                  ]),
                ),
              ),

                const SizedBox(height: 12),

                // ── Scan QR Code button ──────────────────────────────
                OutlinedButton.icon(
                  onPressed: () {
                    _openQrScanner();
                  },
                  icon: Icon(Icons.qr_code_scanner_outlined,
                      color: secondaryText,),
                  label: Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: fieldColor,
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

                // Show connectivity message
                if (_connectionStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _connectionStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),

                const SizedBox(height: 28),

                // ── Connect to LG button ─────────────────────────────
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _isConnected ? _disconnect : _connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2A2A2A) : (_isConnected ? Colors.grey : const Color(0xFF4A7C59)),
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
                          : Text(
                            _isConnected ? "Disconnect" : 'Connect to LG',
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // OutlinedButton(
                //   onPressed: _preloading ? null : _preloadStories,
                //   child: Text(_preloading
                //       ? 'Preloading $_preloadDone / $_preloadTotal...'
                //       : 'Preload All Species Stories'),
                // ),

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

          // Layer 2: Quick actions bar (bottom-left, above nav bar) ─────────
              Positioned(
                bottom: 24,
                right: 16,
                child: QuickActionsBar(
                  client: widget.client, host: widget.host,
                  screens: widget.screens, isConnected: widget.isConnected,
                ),
              ),
          ]
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
    final isDark = context.watch<ThemeProvider>().isDark;
    final fieldColor =
      isDark ? const Color(0xFF222222) : const Color(0xFFEBEBE6);
    final textColor =
      isDark ? Colors.white : const Color(0xFF1A1A1A);
    final labelColor =
      isDark ? Colors.white70 : const Color(0xFF555555);
    final hintColor =
      isDark ? Colors.white38 : const Color(0xFFAAAAAA);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          hintStyle: TextStyle(
            color: hintColor,
            fontSize: 13,
          ),
          // Clear (×) button on the right
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: isDark ? Colors.white38 : const Color(0xFFAAAAAA),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Color(0xFFAAAAAA),
                    size: 20,
                  ),
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