// import '../models/species.dart';
// import 'species_service.dart';

// class KmlService {
//   static const String _kmlHeader = '''
// <?xml version="1.0" encoding="UTF-8"?>
// <kml xmlns="http://www.opengis.net/kml/2.2">
// <Document>
// ''';

//   static const String _kmlFooter = '''
// </Document>
// </kml>
// ''';

//   /// ============================================================
//   /// Permanent paw markers
//   /// ============================================================

//   static String buildMarkersKml(List<Species> species) {
//     final buffer = StringBuffer();

//     buffer.write(_kmlHeader);

//     buffer.writeln('''
// <Style id="paw">
//   <IconStyle>
//     <scale>1.2</scale>
//     <Icon>
//       <href>http://lg1:81/images/paw.png</href>
//     </Icon>
//   </IconStyle>
// </Style>
// ''');

//     for (final s in species) {
//       buffer.writeln('''
// <Placemark>

// <name>${s.commonName}</name>

// <styleUrl>#paw</styleUrl>

// <Point>
// <coordinates>${s.lng},${s.lat},0</coordinates>
// </Point>

// </Placemark>
// ''');
//     }

//     buffer.write(_kmlFooter);

//     return buffer.toString();
//   }

//   /// ============================================================
//   /// Right screen overlay
//   /// ============================================================

//   static String buildRightOverlayKml() {
//     return '''
// $_kmlHeader

// <ScreenOverlay>

// <name>Species Card</name>

// <Icon>

// <href>http://lg1:81/species.html</href>

// </Icon>

// <overlayXY
// x="0"
// y="1"
// xunits="fraction"
// yunits="fraction"/>

// <screenXY
// x="0"
// y="1"
// xunits="fraction"
// yunits="fraction"/>

// <size
// x="100%"
// y="100%"
// xunits="fraction"
// yunits="fraction"/>

// </ScreenOverlay>

// $_kmlFooter
// ''';
//   }

//   /// ============================================================
//   /// HTML page
//   /// ============================================================

//   static String buildSpeciesHtml(
//     Species species,
//     SpeciesStory story,
//   ) {
//     return '''
// <!DOCTYPE html>

// <html>

// <head>

// <meta charset="utf-8">

// <style>

// body{

// margin:0;
// padding:40px;

// background:#0E1B25;

// color:white;

// font-family:Arial;

// }

// img{

// width:300px;

// border-radius:12px;

// display:block;

// margin:auto;

// }

// h1{

// font-size:42px;

// margin-top:20px;

// }

// .status{

// font-size:24px;

// font-weight:bold;

// color:${species.category=="CR" ? "#C62828" : "#EF6C00"};

// }

// .story{

// margin-top:25px;

// font-size:24px;

// line-height:1.6;

// }

// .footer{

// margin-top:40px;

// font-size:18px;

// opacity:.8;

// }

// </style>

// </head>

// <body>

// <img src="http://lg1:81/images/${species.id}.png">

// <h1>${species.commonName}</h1>

// <div><i>${species.scientificName}</i></div>

// <div class="status">

// ${species.category=="CR"
// ? "Critically Endangered"
// : "Endangered"}

// </div>

// <div class="story">

// ${story.narrative}

// </div>

// <div class="footer">

// IUCN Red List

// </div>

// </body>

// </html>
// ''';
//   }
// }

import '../models/species.dart';

// class KmlService {

//   /// Main KML shown on Google Earth
//   static String buildSpeciesKml(List<Species> species) {
//     final b = StringBuffer();

//     b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
//     b.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
//     b.writeln('<Document>');

//     for (final s in species) {
//       b.writeln(_pawPlacemark(s));
//     }

//     b.writeln('</Document>');
//     b.writeln('</kml>');

//     return b.toString();
//   }

//   static String _pawPlacemark(Species s) => '''
// <Placemark>

// <name>${s.commonName}</name>

// <Style>

// <IconStyle>

// <scale>1.4</scale>

// <Icon>

// <href>http://lg1:81/paws/${s.id}.png</href>

// </Icon>

// </IconStyle>

// </Style>

// <Point>

// <coordinates>${s.lng},${s.lat},0</coordinates>

// </Point>

// </Placemark>
// ''';

//   /// HTML page shown on right screen
//   static String buildHtmlCard({
//     required Species species,
//     required String html,
//   }) {

//     return '''
// <!DOCTYPE html>

// <html>

// <head>

// <meta charset="utf-8">

// <style>

// body{

// background:#101010;

// font-family:Arial;

// color:white;

// padding:40px;

// }

// h1{

// font-size:38px;

// }

// img{

// width:260px;

// display:block;

// margin:auto;

// }

// </style>

// </head>

// <body>

// <img src="http://lg1:81/paws/${species.id}.png">

// $html

// </body>

// </html>
// ''';
//   }

// }

// import '../data/species_data.dart';

class KmlService {
  static String buildSpeciesKml(List<Species> species) {
    final b = StringBuffer();

    b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    b.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    b.writeln('<Document>');

    for (final s in species) {
      b.writeln('''
<Placemark>
  <name>${s.commonName}</name>
  <Point>
    <coordinates>${s.lng},${s.lat},0</coordinates>
  </Point>
</Placemark>
''');
    }

    b.writeln('</Document>');
    b.writeln('</kml>');

    return b.toString();
  }

  static String buildHtmlCard({
    required Species species,
    required String html,
  }) {
    return '''
<!DOCTYPE html>
<html>
<body>
<h2>${species.commonName}</h2>
$html
</body>
</html>
''';
  }
}