import 'dart:convert';
import '../models/species.dart';
import 'species_service.dart';

class KmlService {
  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  // ── Persistent paw markers ──────────
  static String buildPawIconsKml(
    List<Species> species, {
    String iconHref = 'http://lg1:81/images/paw.png',
  }) {
    final b = StringBuffer();
    b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    b.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    b.writeln('<Document><name>Species Paw Markers</name>');
    b.writeln('''
  <Style id="pawIcon">
    <IconStyle>
      <scale>1.2</scale>
      <Icon><href>$iconHref</href></Icon>
    </IconStyle>
    <LabelStyle>
      <scale>0</scale>
    </LabelStyle>
  </Style>''');

    for (final s in species) {
      b.writeln('''
  <Placemark>
    <name>${_escape(s.commonName)}</name>
    <styleUrl>#pawIcon</styleUrl>
    <Point>
      <coordinates>${s.lng},${s.lat},0</coordinates>
    </Point>
  </Placemark>''');
    }

    b.writeln('</Document></kml>');
    return b.toString();
  }

  // ── Camera sync ──────────────────────────────────────────────
  static String buildFlyTo({
    required double lat,
    required double lng,
    required double range,
    required double tilt,
    required double heading,
  }) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
<LookAt>
  <longitude>$lng</longitude>
  <latitude>$lat</latitude>
  <range>$range</range>
  <tilt>$tilt</tilt>
  <heading>$heading</heading>
</LookAt>
</Document>
</kml>''';
  }

  // ── Species info balloon shown on flyTo ─────────────────────────
  // Uses gx:balloonVisibility to auto-open, which is the standard LG
  // technique for showing rich info without a separate ScreenOverlay
  // image. Test on your actual rig — balloon auto-open support can
  // vary slightly by the Earth build LG ships.
  static String buildSpeciesInfoKml(
    Species species,
    SpeciesStory story, {
    String title = '',
    String? imageUrl,
  }) {
    final heading = title.isEmpty
        ? _categoryLabel(species.category)
        : title;

    return '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
<Document>
<Style id="infoBalloon">
  <BalloonStyle>
    <bgColor>ff251b0e</bgColor>
    <textColor>ffffffff</textColor>
    <text><![CDATA[
      \$[description]
    ]]></text>
  </BalloonStyle>
</Style>
<Placemark>
  <name>${_escape(species.commonName)}</name>
  <styleUrl>#infoBalloon</styleUrl>
  <description><![CDATA[
    ${_infoHtml(species, story, heading, imageUrl)}
  ]]></description>
  <gx:balloonVisibility>1</gx:balloonVisibility>
  <Point><coordinates>${species.lng},${species.lat},0</coordinates></Point>
</Placemark>
</Document>
</kml>''';
  }

  static String _categoryLabel(String c) =>
      c == 'CR' ? 'Critically Endangered' : 'Endangered';

  static String _infoHtml(Species s, SpeciesStory story, String heading, String? imageUrl) {
    final imageTag = imageUrl != null
        ? '<img src="$imageUrl" style="width:100%;border-radius:8px;margin-bottom:8px;">'
        : '';
    
    final body = (story.highlights != null && story.highlights!.isNotEmpty)
        ? _renderHighlights(story.highlights!)
        : '<div style="line-height:1.5;">${story.narrative}</div>';
    
    return '''
<div style="font-family:Arial;max-width:340px;background:#0E1B25;
            color:white;padding:16px;border-radius:8px;">
  $imageTag
  <h2 style="margin:0 0 4px 0;">${_escape(s.commonName)}</h2>
  <div style="font-style:italic;opacity:.7;margin-bottom:8px;">
    ${_escape(s.scientificName)}
  </div>
  <div style="font-weight:bold;color:${s.category == "CR" ? "#EF5350" : "#FFA726"};
              margin-bottom:10px;">
    $heading
  </div>
  $body
</div>''';
  }

  static const Map<String, String> _highlightColors = {
    'threat': '#EF5350', // red
    'action': '#66BB6A', // green
    'fact': '#29B6F6',   // blue
    'hope': '#FFA726',   // orange
  };

  static String _renderHighlights(List<Map<String, String>> highlights) {
    final items = highlights.map((h) {
      final color = _highlightColors[h['type']] ?? '#FFFFFF';
      return '''
      <li style="margin-bottom:8px;line-height:1.4;">
        <span style="color:$color;font-weight:bold;">•</span>
        ${_escape(h['text'] ?? '')} 
      </li>''';
    }).join();

    return '<ul style="list-style-type:none;padding:0;margin:0;">$items</ul>';
  }
}