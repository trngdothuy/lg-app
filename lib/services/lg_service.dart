import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/species.dart';
import 'species_service.dart';
import 'kml_service.dart';

class LGService {
  final SSHClient client;
  final String host;
  final int screens;

  LGService({required this.client, required this.host, required this.screens});

  Future<void> disconnect() async {}

  Future<void> _run(String cmd) async {
    final session = await client.execute(cmd);
    await utf8.decodeStream(session.stdout);
    await utf8.decodeStream(session.stderr);
    await session.exitCode;
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
    print('flyTo() called: $lat, $lng');
    final kml = KmlService.buildFlyTo(
      lat: lat, lng: lng, range: range, tilt: tilt, heading: heading,
    );
    await _writeRemoteFile('/var/www/html/kml/flyto.kml', kml);

    for (int i = 1; i <= screens; i++) {
      await _sendToScreen(i, 'http://lg1:81/kml/flyto.kml');
    }
    // kmls.txt is intentionally untouched here — the paw layer stays up.
  }

  // ── Tap a pin on the phone → rig flies + shows info balloon ─────
  Future<void> showSpecies(Species species, SpeciesStory story) async {
    await _writeRemoteFile(
      '/var/www/html/kml/info.kml',
      KmlService.buildSpeciesInfoKml(species, story),
    );
    await _sendToScreen(1, 'http://lg1:81/kml/info.kml');
  }

  Future<void> showHistory(Species species, SpeciesStory story) async {
    await _writeRemoteFile(
      '/var/www/html/kml/info.kml',
      KmlService.buildSpeciesInfoKml(species, story, title: 'History'),
    );
    await _sendToScreen(1, 'http://lg1:81/kml/info.kml');
  }

  Future<void> showFuture(Species species, SpeciesStory story) async {
    await _writeRemoteFile(
      '/var/www/html/kml/info.kml',
      KmlService.buildSpeciesInfoKml(species, story, title: 'Looking Ahead'),
    );
    await _sendToScreen(1, 'http://lg1:81/kml/info.kml');
  }
}