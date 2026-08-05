import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:async';
import '../models/species.dart';
import 'species_service.dart';
import 'kml_service.dart';

class LGService {
  final SSHClient client;
  final String host;
  final int screens;

  LGService({required this.client, required this.host, required this.screens});

  int get _rightMostScreen => screens ~/ 2 + 1;

  bool _flyBusy = false;
  Map<String, dynamic>? _pendingFly;

  Future<void> disconnect() async {}

  Future<void> _run(String cmd) async {
    print("RUN: $cmd");
    try {
      final session = await client.execute(cmd).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('SSH command timed out: $cmd'),
      );

      final stdout = await utf8.decodeStream(session.stdout);
      final stderr = await utf8.decodeStream(session.stderr);
      final exitCode = await session.exitCode;

      print("STDOUT: $stdout");
      print("STDERR: $stderr");
      print("EXIT: $exitCode");
    } catch (e) {
      print("_run() FAILED for '$cmd': $e");
      rethrow;
    }
  }

  Future<void> _writeRemoteFile(String path, String content) async {
    final encoded = base64Encode(utf8.encode(content));
    await _run("echo '$encoded' | base64 -d > $path");
  }

  Future<void> _sendToScreen(int screenIndex, String kmlUrl) async {
    await _run(
      "sshpass -p lg ssh -o StrictHostKeyChecking=no lg$screenIndex@lg$screenIndex "
      "'echo \"$kmlUrl\" > /tmp/query.txt'",
    );
  }

  // ── One-time asset upload (run once per rig, not per session) ───
  Future<void> uploadPawModel({
    String assetPath = 'assets/kml/paws/redPaw.dae',
    String remotePath = '/var/www/html/kml/paw/redPaw.dae',
  }) async {
    // Load the file that's bundled inside the app itself
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    // Make sure the destination folder exists on the rig
    await _run('mkdir -p /var/www/html/kml/paw');

    // Open the model file for writing over SFTP and send the bytes
    final sftp = await client.sftp();
    final remoteFile = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    await remoteFile.write(Stream.value(bytes));
    await remoteFile.close();
  }

  Future<void> uploadPawIcon({
    String assetPath = 'assets/logo/paw.png',
    String remotePath = '/var/www/html/images/paw.png',
  }) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    await _run('mkdir -p /var/www/html/images');

    final sftp = await client.sftp();
    final remoteFile = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    await remoteFile.write(Stream.value(bytes));
    await remoteFile.close();
  }

  // ── One-time bulk upload of species photos ──────────────────
  // Expects assets named assets/species_images/<species.id>.jpg
  Future<void> uploadSpeciesImages(List<Species> species) async {
    await _run('mkdir -p /var/www/html/images/species');
    final sftp = await client.sftp();

    for (final s in species) {
      final assetPath = 'assets/species_images/${s.internalTaxonId}.jpg';
      try {
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List();

        final remoteFile = await sftp.open(
          '/var/www/html/images/species/${s.internalTaxonId}.jpg',
          mode: SftpFileOpenMode.create |
              SftpFileOpenMode.write |
              SftpFileOpenMode.truncate,
        );
        await remoteFile.write(Stream.value(bytes));
        await remoteFile.close();
      } catch (e) {
        // Don't let one missing photo abort the whole batch —
        // just log it and move on to the next species.
        print('No image for ${s.internalTaxonId}, skipping: $e');
      }
    }
  }

  // ── Paw markers, shown on nav to the map screen ─────────────────
  Future<void> initialize(List<Species> species) async {
    await _writeRemoteFile(
      '/var/www/html/kml/species.kml',
      KmlService.buildPawIconsKml(species),
    );
    // Reset (not append) kmls.txt so re-connecting doesn't duplicate layers.
    // flyTo() below never touches this file — that was the bug.
    await _writeRemoteFile(
      '/var/www/html/kmls.txt',
      'http://lg1:81/kml/species.kml',
    );
  }

  // Call this from _applyFilters() if you want the rig's paw set to
  // track the phone's current filter/search results.
  Future<void> updateMarkers(List<Species> species) async {
    await _writeRemoteFile(
      '/var/www/html/kml/species.kml',
      KmlService.buildPawIconsKml(species),
    );
  }

  // ── Camera sync: phone map move → rig flies too ─────────────────
  Future<void> flyTo({
    required double lat,
    required double lng,
    double range = 500000,
    double tilt = 0,
    double heading = 0,
    int duration = 0,
  }) async {
    print('flyTo() called: $lat, $lng, busy=$_flyBusy');

    if (_flyBusy) {
      _pendingFly = {
        'lat': lat, 'lng': lng, 'range': range,
        'tilt': tilt, 'heading': heading,
      };
      print('flyTo() queued (busy) — will send after current one finishes');
      return;
    }

    _flyBusy = true;
    try {
      await _doFlyTo(lat: lat, lng: lng, range: range, tilt: tilt, heading: heading);
      print('flyTo() sent successfully');

      while (_pendingFly != null) {
        final next = _pendingFly!;
        _pendingFly = null;
        print('flyTo() sending queued position: ${next['lat']}, ${next['lng']}');
        await _doFlyTo(
          lat: next['lat'], lng: next['lng'], range: next['range'],
          tilt: next['tilt'], heading: next['heading'],
        );
      }
    } catch (e, st) {
      print('flyTo() ERROR: $e');
    } finally {
      _flyBusy = false;
    }
  }

  Future<void> _doFlyTo({
    required double lat,
    required double lng,
    required double range,
    required double tilt,
    required double heading,
  }) async {
    final kml = KmlService.buildFlyTo(lat: lat, lng: lng, range: range, tilt: tilt, heading: heading);
    await _writeRemoteFile('/var/www/html/kml/flyto.kml', kml);
    for (int i = 1; i <= screens; i++) {
      await _sendToScreen(i, 'http://lg1:81/kml/flyto.kml');
    }
  }

  // ── Tap a pin on the phone → rig flies + shows info balloon ─────
  Future<void> showSpecies(Species species, SpeciesStory story) async {
    await _writeRemoteFile(
      '/var/www/html/kml/info.kml',
      KmlService.buildSpeciesInfoKml(species, story, imageUrl: 'http://lg1:81/images/species/${species.internalTaxonId}.jpg'),
    );
    await _sendToScreen(_rightMostScreen, 'http://lg1:81/kml/info.kml');
  }

  Future<void> showHistory(Species species, SpeciesStory story) async {
    await _writeRemoteFile(
      '/var/www/html/kml/info.kml',
      KmlService.buildSpeciesInfoKml(species, story, title: 'History', imageUrl: 'http://lg1:81/images/species/${species.internalTaxonId}.jpg'),
    );
    await _sendToScreen(_rightMostScreen, 'http://lg1:81/kml/info.kml');
  }

  Future<void> showFuture(Species species, SpeciesStory story) async {
    await _writeRemoteFile(
      '/var/www/html/kml/info.kml',
      KmlService.buildSpeciesInfoKml(species, story, title: 'Future Outlook and Actions', imageUrl: 'http://lg1:81/images/species/${species.internalTaxonId}.jpg'),
    );
    await _sendToScreen(_rightMostScreen, 'http://lg1:81/kml/info.kml');
  }
}