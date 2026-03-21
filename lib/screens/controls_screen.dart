import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';

class ControlsScreen extends StatefulWidget {
    final SSHClient? client;
    final String host;
    final int screens;
}