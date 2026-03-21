import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartssh2/dartssh2.dart';
import 'dart:convert';

class ControlsScreen extends StatefulWidget {
    final SSHClient? client;
    final String host;
    final int screens;

    const ControlsScreen({
        super.key,
        required this.client,
        required this.host,
        required this.screens,
    });

    @override State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {

    // helper to time out connection if left idle for more than 22s
    String _status = 'Ready';

    Future<void> _sendCommand(String command) async {
        setState(() => _status = 'Sending...');
        print('Running command: $command');

        try {
            print('Connecting to ${widget.host}:22');
            final socket = await SSHSocket.connect(widget.host, 22);
            
            print('Socket open, authenticating..');
            final client = SSHClient(
                socket, 
                username: 'lg1',
                onPasswordRequest: () => 'lg',
                );
            await client.authenticated;

            print('Authenticated. Running command..');
            final session = await client.execute(command);
            await session.done;
            client.close();

            print('Done');
            setState(() => _status = 'Done');
        } catch (e) {
            print('Error $e');
            setState(() => _status = 'Error: $e');
        }
    }

    // send logo
    Future<void> _sendLogo() async {
        final int leftScreen = widget.screens;

        // read logo as raw bytes
        final ByteData data = await rootBundle.load('assets/logo/LOGO_LIQUID_GALAXY.jpg');
        final List<int> bytes = data.buffer.asUint8List();
        final String base64Logo = base64Encode(bytes);

        await _sendCommand(
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
                <size x="200" y="0" xunits="pixels" yunits="pixels"/>
            </ScreenOverlay>
        </Document>
    </kml>''';

    final escaped = kml.replaceAll("'", "'\\''");
    await _sendCommand(
        "echo '$escaped' > /var/www/html/kml/slave_$leftScreen.kml"
    );
    }

    // send pyramid
    Future<void> _sendPyramid() async {
        setState(() => _status = 'Loading KML...');

        final String kmlContent =  await rootBundle.loadString('assets/kml/pyramid.kml');
        final String base64KML = base64Encode(utf8.encode(kmlContent));

        await _sendCommand(
            "echo '$base64KML' | base64 -d > /var/www/html/kml/pyramid.kml"
        );

        for (int i = 1; i <= widget.screens; i++) {
            await _sendCommand(
            "ssh -o StrictHostKeyChecking=no lg$i@lg$i 'echo \"http://lg1:81/kml/pyramid.kml\" > /tmp/query.txt'"
        );
        }
        
        setState(() => _status = 'Pyramid loaded');
    }

    @override Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text('LG Controller - ${widget.host}'),
            ),
            body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        // status
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                                'Status: $_status',
                                style: const TextStyle(fontFamily: 'monospace'),
                                ),
                        ),

                        const SizedBox(height: 32),

                        _button('Send LG Logo', Colors.indigo, _sendLogo),
                        const SizedBox(height: 12),
                        _button('Send 3D Pyramid', Colors.indigo, _sendPyramid),
                    ],
                ),
            ),
        );
    }

    // reusable button widget
    Widget _button(String label, Color color, VoidCallback onPressed) {
        return ElevatedButton(
            onPressed: onPressed, 
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                ),
            ),
            child: Text(label),
        );
    }
}