import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'app_bottom_nav.dart';

class ToolsScreen extends StatefulWidget {
  final SSHClient? client;
  final String host;
  final int screens;
  final bool isConnected;

  const ToolsScreen({
    super.key,
    required this.client,
    required this.host,
    required this.screens,
    required this.isConnected,
  });

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {

  bool _isDarkMode  = false;
  String? _busyBtn;  // label of button currently running

  // ── SSH helper ────────────────────────────────────────────────
  Future<void> _run(String cmd) async {
    if (widget.client == null) return;
    try {
      final session = await widget.client!.execute(cmd);
      await session.done;
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _runBusy(String label, Future<void> Function() action) async {
    if (_busyBtn != null) return; // prevent double-tap
    setState(() => _busyBtn = label);
    try {
      await action();
      _showSnack('$label — done');
    } catch (e) {
      _showSnack('$label failed: $e');
    } finally {
      if (mounted) setState(() => _busyBtn = null);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D2D2D),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── LG commands ───────────────────────────────────────────────

  /// Relaunch Google Earth on all screens
  Future<void> _relaunchLg() async {
    for (var i = screens; i >= 1; i--) {
      await _run(
        "sshpass -p lg ssh -t lg$i@lg$i "
        "'export DISPLAY=:0 && pkill -f googleearth; sleep 2; "
        "googleearth &'",
      );
    }
  }

  /// Reboot all LG nodes
  Future<void> _rebootLg() async {
    final confirmed = await _confirm(
      'Reboot LG?',
      'This will reboot all ${widget.screens} screens. Continue?',
    );
    if (!confirmed) return;
    for (var i = screens; i >= 1; i--) {
      await _run(
        "sshpass -p lg ssh -t lg$i@lg$i "
        "'echo lg | sudo -S reboot'",
      );
    }
  }

  /// Clear all KML overlays (write empty KML to kmls.txt targets)
  Future<void> _cleanKml() async {
    const empty = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document></Document></kml>''';
    final b64 = _b64(empty);
    await _run("echo '$b64' | base64 -d > /var/www/html/kml/active.kml");
    await _run("echo 'http://lg1:81/kml/active.kml' > /var/www/html/kmls.txt");
    await _setRefresh();
  }

  /// Clear logo overlays (write empty KML to left slave screen)
  Future<void> _cleanLogos() async {
    const empty = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document></Document></kml>''';
    final b64 = _b64(empty);
    final left = widget.screens;
    await _run("echo '$b64' | base64 -d > /var/www/html/kml/slave_$left.kml");
    await _setRefresh();
  }

  /// Reset slave KML files to default empty state
  Future<void> _resetSlave() async {
    const empty = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document></Document></kml>''';
    final b64 = _b64(empty);
    for (var i = 1; i <= widget.screens; i++) {
      await _run(
        "echo '$b64' | base64 -d > /var/www/html/kml/slave_$i.kml",
      );
    }
    await _setRefresh();
  }

  /// Trigger a manual KML refresh on all slave nodes
  Future<void> _refreshSlave() async {
    await _setRefresh();
  }

  /// Power off all LG nodes
  Future<void> _powerOff() async {
    final confirmed = await _confirm(
      'Power Off LG?',
      'This will shut down all ${widget.screens} screens. Continue?',
    );
    if (!confirmed) return;
    for (var i = screens; i >= 1; i--) {
      await _run(
        "sshpass -p lg ssh -t lg$i@lg$i "
        "'echo lg | sudo -S poweroff'",
      );
    }
  }

  // Refresh
  Future<void> _setRefresh() async {
    for (var i = 2; i <= widget.screens; i++) {
      final s = '<href>##LG_PHPIFACE##kml\\/slave_$i.kml<\\/href>';
      final r = '$s<refreshMode>onInterval<\\/refreshMode>'
          '<refreshInterval>2<\\/refreshInterval>';
      await _run(
        "sshpass -p lg ssh -t lg$i@lg$i "
        "'echo lg | sudo -S sed -i \"s/$r/$s/\" ~/earth/kml/slave/myplaces.kml'",
      );
      await _run(
        "sshpass -p lg ssh -t lg$i@lg$i "
        "'echo lg | sudo -S sed -i \"s/$s/$r/\" ~/earth/kml/slave/myplaces.kml'",
      );
    }
  }

  int get screens => widget.screens;
  String _b64(String s) => base64Encode(utf8.encode(s));

  // ── Confirmation dialog ───────────────────────────────────────
  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.black54)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D2D2D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg = _isDarkMode ? const Color(0xFF0F0F0F) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [

            // ── Connected badge (top right) ──────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check,
                    size: 14,
                    color: widget.isConnected
                        ? const Color(0xFF2E7D32)
                        : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    widget.isConnected ? 'Connected' : 'Not Connected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isConnected
                          ? const Color(0xFF2E7D32)
                          : Colors.grey,
                    ),
                  ),
                ]),
              ),
            ),

            const Spacer(flex: 2),

            // ── 2-column button grid ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  _row('Relaunch LG',   _relaunchLg,
                       'Reboot LG',     _rebootLg),
                  const SizedBox(height: 20),
                  _row('Clean KML',     _cleanKml,
                       'Clean Logos',   _cleanLogos),
                  const SizedBox(height: 20),
                  _row('Reset Slave',   _resetSlave,
                       'Refresh Slave', _refreshSlave),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Power Off — centred alone ────────────────────────
            _toolBtn(
              label:    'Power Off',
              onTap:    _powerOff,
              width:    160,
              isRed:    false,
            ),

            const Spacer(flex: 2),

            // ── Dark mode toggle (bottom left) ───────────────────
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                  child: Icon(
                    _isDarkMode
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_round,
                    color: _isDarkMode ? Colors.white54 : Colors.black45,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom nav ────────────────────────────────────────────
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 3,
        client: widget.client,
        host: widget.host,
        screens: widget.screens,
        isConnected: widget.isConnected,
        isDark: _isDarkMode,
        ),
    );
  }

  // Two buttons side by side
  Widget _row(
    String label1, Future<void> Function() fn1,
    String label2, Future<void> Function() fn2,
  ) {
    return Row(children: [
      Expanded(child: _toolBtn(label: label1, onTap: fn1)),
      const SizedBox(width: 16),
      Expanded(child: _toolBtn(label: label2, onTap: fn2)),
    ]);
  }

  Widget _toolBtn({
    required String label,
    required Future<void> Function() onTap,
    double? width,
    bool isRed = false,
  }) {
    final busy    = _busyBtn == label;
    final enabled = widget.isConnected && _busyBtn == null;
    final color   = isRed
        ? const Color(0xFFB71C1C)
        : _isDarkMode
            ? const Color(0xFF3A3A3A)
            : const Color(0xFF3D3D4E);

    // Widget child = busy
    //     ? const SizedBox(
    //         width: 18, height: 18,
    //         child: CircularProgressIndicator(
    //             color: Colors.white, strokeWidth: 2))
    //     : Text(
    //         label,
    //         textAlign: TextAlign.center,
    //         style: const TextStyle(
    //           color: Colors.white,
    //           fontSize: 15,
    //           fontWeight: FontWeight.w500,
    //         ),
    //       );

    final btn = GestureDetector(
      onTap: enabled ? () => _runBusy(label, onTap) : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: busy
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    ),
  );

    return width != null ? btn : btn;
  }
}
