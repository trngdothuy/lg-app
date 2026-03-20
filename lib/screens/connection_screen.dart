import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'controls_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override 
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {

  final _userController = TextEditingController(text: 'lg1');
  final _hostController = TextEditingController(text: '192.168.56.105');
  final _portController = TextEditingController(text: '22');
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

    // connecting, clear old error message
    setState(() {
      _isConnecting = true;
      _errorMessage = '';
    });

    try {
      // open SSH connection
      final socket = await SSHSocket.connect(host, port);
      final client = SSHClient(
        socket, 
        username: username,
        onPasswordRequest: () => password,
        );
        await client.authenticated; 

        // connected, go to control screen
        if (mounted) { // mounted = widget is still on screen
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
      // connection failed, show error
      setState(() {
        _errorMessage = 'Connection Failed: $e';
        _isConnecting = false;
      });
    }
  }

  // clean up controller when widget is destroyed, prevent memory leaks
  @override
  void dispose() {
    _userController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _screensController.dispose();
    super.dispose();
  }

  // build UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LG Controller - Connect'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // input fields
            _buildField('Username', _userController),
            _buildField('IP Address', _hostController),
            _buildField('Port Number', _portController, isNumber: true),
            _buildField('Password', _passwordController, isPassword: true),
            _buildField('Number of Screens', _screensController, isNumber: true),

            const SizedBox(height: 24),

            // error message
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // connect button
            ElevatedButton(
              onPressed: _isConnecting ? null : _connect, // null to disable the button
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: _isConnecting
                ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
                )
                : const Text('Connect to LG'),
                ),

          ],
        ),
      ),
    );
  }

  // Reusable field builder
  Widget _buildField(
    String label,
    TextEditingController controller, {
      bool isPassword = false,
      bool isNumber = false,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber 
          ? TextInputType.number
          : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

