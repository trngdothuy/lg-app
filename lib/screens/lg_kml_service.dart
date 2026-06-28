// lg_kml_service.dart
// All Liquid Galaxy SSH + KML logic in one place.
// Screen layout (screens=5): lg5=left logos | lg4,lg3,lg2=centre | lg1=right info
// Screen layout (screens=3): lg3=left logos | lg2=centre           | lg1=right info
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'species_data.dart';

class LgKmlService {
  final SSHClient client;
  final String host;
  final int screens;

  LgKmlService({
    required this.client,
    required this.host,
    required this.screens,
  });

  // ── Screen numbers ────────────────────────────────────────────
  int get _leftScreen   => screens;       // logos overlay
  int get _rightScreen  => 1;             // species info panel
  int get _centerScreen => (screens / 2).ceil(); // silhouette

  // ── Low-level helpers ─────────────────────────────────────────
  Future<void> _run(String cmd) async {
    try {
      final session = await client.execute(cmd);
      await session.done;
    } catch (e) {
      print('[LG] SSH error: $e');
    }
  }

  Future<void> _uploadKml(String filename, String kml) async {
    // Write KML as base64 to avoid shell quoting issues
    final b64 = base64Encode(utf8.encode(kml));
    await _run("echo '$b64' | base64 -d > /var/www/html/kml/$filename");
  }

  Future<void> _setRefresh() async {
    for (var i = 2; i <= screens; i++) {
      final src = '<href>##LG_PHPIFACE##kml\\/slave_$i.kml<\\/href>';
      final dst = '$src<refreshMode>onInterval<\\/refreshMode>'
          '<refreshInterval>2<\\/refreshInterval>';
      await _run(
          "sshpass -p lg ssh -t lg$i@lg$i "
          "'echo lg | sudo -S sed -i \"s/$dst/$src/\" "
          "~/earth/kml/slave/myplaces.kml'");
      await _run(
          "sshpass -p lg ssh -t lg$i@lg$i "
          "'echo lg | sudo -S sed -i \"s/$src/$dst/\" "
          "~/earth/kml/slave/myplaces.kml'");
    }
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── 1. Upload static assets once after connect ────────────────
  // loadAsset = (assetPath) async => bytes from rootBundle
  Future<void> uploadAssets(
      Future<List<int>> Function(String) loadAsset) async {
    await _run('mkdir -p /var/www/html/kml/logos');
    await _run('mkdir -p /var/www/html/kml/silhouettes');
    await _run('mkdir -p /var/www/html/kml/icons');

    // Logos
    for (final e in {
      'lg_logo.png':      'assets/logo/logo1.png',
      'redlist_logo.png': 'assets/logo/logo2.png',
    }.entries) {
      final b64 = base64Encode(await loadAsset(e.value));
      await _run("echo '$b64' | base64 -d > /var/www/html/kml/logos/${e.key}");
    }

    // Silhouettes (one per group)
    for (final g in [
      'mammalia', 'aves', 'reptilia', 'pisces', 'arthropoda', 'plantae'
    ]) {
      try {
        final b64 = base64Encode(await loadAsset('assets/silhouettes/$g.png'));
        await _run(
            "echo '$b64' | base64 -d > /var/www/html/kml/silhouettes/$g.png");
      } catch (_) {} // skip if asset missing
    }

    // Paw icon for globe
    try {
      final b64 = base64Encode(await loadAsset('assets/icons/paw.png'));
      await _run("echo '$b64' | base64 -d > /var/www/html/kml/icons/paw.png");
    } catch (_) {}
  }

  // ── 2. Spinning globe (initial state) ─────────────────────────
  Future<void> sendSpinningGlobe(List<Species> species) async {
    // Place a paw icon at each species location
    final placemarks = species.map((s) => '''
    <Placemark>
      <name>${_esc(s.commonName)}</name>
      <Style>
        <IconStyle>
          <Icon><href>http://lg1:81/kml/icons/paw.png</href></Icon>
          <scale>1.3</scale>
        </IconStyle>
        <LabelStyle><scale>0</scale></LabelStyle>
      </Style>
      <Point><coordinates>${s.lng},${s.lat},0</coordinates></Point>
    </Placemark>''').join('\n');

    // Orbit tour: 36 steps × 10° = full 360° spin
    final orbit = List.generate(36, (i) => '''
        <gx:FlyTo>
          <gx:duration>1.5</gx:duration>
          <gx:flyToMode>smooth</gx:flyToMode>
          <LookAt>
            <longitude>${i * 10.0}</longitude>
            <latitude>15</latitude>
            <altitude>0</altitude>
            <range>12000000</range>
            <tilt>0</tilt><heading>0</heading>
          </LookAt>
        </gx:FlyTo>''').join('\n');

    final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Red List — Spinning Globe</name>
$placemarks
    <gx:Tour>
      <name>Globe Spin</name>
      <gx:Playlist>
$orbit
      </gx:Playlist>
    </gx:Tour>
  </Document>
</kml>''';

    await _uploadKml('globe_spin.kml', kml);
    await _run(
        "echo 'http://lg1:81/kml/globe_spin.kml' > /var/www/html/kmls.txt");
    await _setRefresh();
    await sendLogosToLeftScreen(); // always show logos on left
  }

  // ── 3. Left screen: logos overlay ────────────────────────────
  Future<void> sendLogosToLeftScreen() async {
    final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>LG Logo</name>
      <Icon><href>http://lg1:81/kml/logos/lg_logo.png</href></Icon>
      <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY  x="0.02" y="0.95" xunits="fraction" yunits="fraction"/>
      <size x="200" y="0" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>
    <ScreenOverlay>
      <name>Red List Logo</name>
      <Icon><href>http://lg1:81/kml/logos/redlist_logo.png</href></Icon>
      <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY  x="0.02" y="0.68" xunits="fraction" yunits="fraction"/>
      <size x="180" y="0" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>
  </Document>
</kml>''';
    await _uploadKml('slave_$_leftScreen.kml', kml);
    await _setRefresh();
  }

  // ── 4. Fly-to (called on phone map pan OR marker tap) ─────────
  Future<void> flyTo({
    required double lat,
    required double lng,
    double range    = 700000,
    double tilt     = 45,
    double heading  = 0,
    double duration = 2.5,
  }) async {
    final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <gx:Tour><name>FlyTo</name>
      <gx:Playlist>
        <gx:FlyTo>
          <gx:duration>$duration</gx:duration>
          <gx:flyToMode>smooth</gx:flyToMode>
          <LookAt>
            <longitude>$lng</longitude><latitude>$lat</latitude>
            <altitude>0</altitude><range>$range</range>
            <tilt>$tilt</tilt><heading>$heading</heading>
          </LookAt>
        </gx:FlyTo>
      </gx:Playlist>
    </gx:Tour>
  </Document>
</kml>''';
    await _uploadKml('flyto.kml', kml);
    await _run("echo 'http://lg1:81/kml/flyto.kml' > /var/www/html/kmls.txt");
  }

  // ── 5. Full species display (tap on red dot) ──────────────────
  Future<void> sendSpeciesDisplay({
    required Species species,
    required String geminiStory,
    required String ttsScript,
    required Map<String, String> iucnData,
    String mode = 'initial', // 'initial' | 'history' | 'ahead'
  }) async {
    await Future.wait([
      // Centre screen: fly to species + silhouette at its coordinates
      _sendCentreView(species),
      // Right screen: Gemini story panel
      _sendRightPanel(species, geminiStory, iucnData, mode),
      // Left screen: logos (always)
      sendLogosToLeftScreen(),
    ]);
  }

  Future<void> _sendCentreView(Species s) async {
    // 1. Fly there
    await flyTo(lat: s.lat, lng: s.lng, range: 150000, tilt: 50);

    // 2. Silhouette overlay at the species screen position
    final group = s.group.toLowerCase();
    // Silhouette goes on centre screen's slave KML
    final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>${_esc(s.commonName)} silhouette</name>
      <Icon>
        <href>http://lg1:81/kml/silhouettes/$group.png</href>
      </Icon>
      <overlayXY x="0.5" y="0.5" xunits="fraction" yunits="fraction"/>
      <screenXY  x="0.5" y="0.55" xunits="fraction" yunits="fraction"/>
      <size x="0.4" y="0" xunits="fraction" yunits="fraction"/>
    </ScreenOverlay>
  </Document>
</kml>''';
    await _uploadKml('slave_$_centerScreen.kml', kml);
    await _setRefresh();
  }

  Future<void> _sendRightPanel(
    Species s,
    String story,
    Map<String, String> iucn,
    String mode,
  ) async {
    final statusColor = s.category == 'CR' ? '#CC0000' : '#E53935';
    final statusLabel =
        s.category == 'CR' ? 'Critically Endangered' : 'Endangered';
    final modeTitle = mode == 'history'
        ? 'History Journey'
        : mode == 'ahead'
            ? 'Looking Ahead'
            : 'Species Profile';

    // HTML page served from LG web server, shown as ScreenOverlay
    final html = '''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #0a0d1a;
    color: #e0e0e0;
    font-family: 'Arial', sans-serif;
    padding: 20px;
    height: 100vh;
    overflow: hidden;
  }
  .tag {
    font-size: 10px;
    letter-spacing: 3px;
    color: $statusColor;
    text-transform: uppercase;
    margin-bottom: 8px;
    font-weight: 700;
  }
  .mode {
    font-size: 11px;
    letter-spacing: 2px;
    color: #5599cc;
    text-transform: uppercase;
    margin-bottom: 14px;
  }
  .common { font-size: 24px; font-weight: 800; color: #fff; line-height: 1.2; }
  .sci    { font-size: 13px; font-style: italic; color: #888; margin: 4px 0 10px; }
  .badge  {
    display: inline-block;
    background: $statusColor;
    color: #fff;
    font-size: 11px;
    font-weight: 700;
    padding: 3px 12px;
    border-radius: 4px;
    margin-bottom: 16px;
  }
  hr { border: none; border-top: 1px solid #1e2d45; margin: 14px 0; }
  .story p { font-size: 13px; line-height: 1.75; color: #ccc; margin-bottom: 10px; }
  .facts { font-size: 11px; }
  .fact-row {
    display: flex;
    justify-content: space-between;
    padding: 5px 0;
    border-bottom: 1px solid #131c2e;
  }
  .fact-label { color: #555; }
  .fact-val   { color: #bbb; text-align: right; max-width: 60%; }
  .border-accent {
    border-left: 3px solid #00bcd4;
    padding-left: 12px;
    margin-bottom: 16px;
  }
</style>
</head>
<body>
  <div class="tag">Red List Species Update</div>
  <div class="mode">$modeTitle</div>
  <div class="border-accent">
    <div class="common">${_esc(s.commonName)}</div>
    <div class="sci">${_esc(s.scientificName)}</div>
    <span class="badge">$statusLabel (${s.category})</span>
  </div>
  <hr>
  <div class="story">$story</div>
  <hr>
  <div class="facts">
    ${_factRow('Group',      s.group)}
    ${_factRow('Habitat',    _truncate(iucn['habitat_text'] ?? s.habitat, 70))}
    ${_factRow('Threats',    _truncate(iucn['threats'] ?? s.threats, 70))}
    ${_factRow('Population', iucn['population'] ?? 'Unknown')}
    ${iucn['countries'] != null ? _factRow('Range', iucn['countries']!) : ''}
    ${_factRow('IUCN ID',    '${s.internalTaxonId}')}
  </div>
</body>
</html>''';

    // Upload HTML file
    final htmlB64 = base64Encode(utf8.encode(html));
    await _run(
        "echo '$htmlB64' | base64 -d > /var/www/html/kml/species_panel.html");

    // KML ScreenOverlay on the rightmost slave screen
    final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>Species Panel</name>
      <Icon><href>http://lg1:81/kml/species_panel.html</href></Icon>
      <overlayXY x="1"    y="0.5" xunits="fraction" yunits="fraction"/>
      <screenXY  x="0.98" y="0.5" xunits="fraction" yunits="fraction"/>
      <size x="400" y="600" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>
  </Document>
</kml>''';
    await _uploadKml('slave_$_rightScreen.kml', kml);
    await _setRefresh();
  }

  // ── 6. Clear everything ────────────────────────────────────────
  Future<void> clearAll() async {
    const empty = '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2">'
        '<Document></Document></kml>';
    await Future.wait([
      for (var i = 1; i <= screens; i++)
        _uploadKml('slave_$i.kml', empty),
      _run("echo '' > /var/www/html/kmls.txt"),
    ]);
    await _setRefresh();
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _factRow(String label, String value) =>
      '<div class="fact-row">'
      '<span class="fact-label">$label</span>'
      '<span class="fact-val">${_esc(value)}</span>'
      '</div>';

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
