import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';

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
    @override Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text('LG Controller - ${widget.host}'),
            ),
            body: const Center(
                child: Text('Button'),
                ),
        );
    }
}