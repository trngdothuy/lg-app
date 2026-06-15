// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:dartssh2/dartssh2.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:http/http.dart' as http;

// // ══════════════════════════════════════════════════════════════════
// // MapsScreen — entry point
// // ══════════════════════════════════════════════════════════════════
// class MapsScreen extends StatefulWidget {
//   final SSHClient? client;
//   final String host;
//   final int screens;
//   final bool isConnected;

//   const MapsScreen({
//     super.key,
//     required this.client,
//     required this.host,
//     required this.screens,
//     required this.isConnected,
//   });

//   @override
//   State<MapsScreen> createState() => _MapsScreenState();
// }

// class _MapsScreenState extends State<MapsScreen> {
//   // ── Map ───────────────────────────────────────────────────────
//   final Completer<GoogleMapController> _mapController = Completer();
//   static const CameraPosition _initialCamera = CameraPosition(
//     target: LatLng(21.028511, 105.8067), // Hanoi, Vietnam
//     zoom: 6,
//   );

//   bool _isDarkMode   = false;
//   Set<Marker> _markers = {};

//   // ── Species / IUCN ────────────────────────────────────────────
//   // TODO: replace with your IUCN Red List API token
//   static const String _iucnToken = 'YOUR_IUCN_API_TOKEN';
//   List<_Species> _allSpecies = [];
//   List<_Species> _filteredSpecies = [];
//   _Species? _selectedSpecies;

//   // ── Search + filter ───────────────────────────────────────────
//   final TextEditingController _searchController = TextEditingController();
//   String _activeFilter = ''; // 'Extinct level' | 'Groups' | 'Places' | ''

//   // ── Voice ─────────────────────────────────────────────────────
//   late stt.SpeechToText _speech;
//   bool _isListening = false;

//   // ── TTS ───────────────────────────────────────────────────────
//   final FlutterTts _tts = FlutterTts();
//   bool _isMuted = false;

//   // ── LG SSH ────────────────────────────────────────────────────
//   bool _lgBusy = false;

//   // ─────────────────────────────────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _loadIucnSpecies();
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _tts.stop();
//     super.dispose();
//   }

//   // ── IUCN Red List API ─────────────────────────────────────────
//   Future<void> _loadIucnSpecies() async {
//     try {
//       // Page 0 returns up to 10 000 species with location data
//       final url = Uri.parse(
//         'https://apiv3.iucnredlist.org/api/v3/species/region/global/page/0'
//         '?token=$_iucnToken',
//       );
//       final res = await http.get(url).timeout(const Duration(seconds: 15));
//       if (res.statusCode != 200) return;

//       final data   = json.decode(res.body) as Map<String, dynamic>;
//       final result = (data['result'] as List? ?? []);

//       final loaded = <_Species>[];
//       for (final item in result) {
//         // Only keep species that have lat/lng in occurrence data
//         // A second call fetches occurrence for each; here we use a
//         // lightweight country-centroid fallback for demo speed.
//         final lat = (item['lat'] as num?)?.toDouble();
//         final lng = (item['lon'] as num?)?.toDouble();
//         if (lat == null || lng == null) continue;

//         loaded.add(_Species(
//           id:           item['taxonid']?.toString() ?? '',
//           name:         item['scientific_name'] ?? 'Unknown',
//           commonName:   item['main_common_name'] ?? '',
//           category:     item['category'] ?? '',
//           group:        item['class_name'] ?? '',
//           lat:          lat,
//           lng:          lng,
//         ));
//       }

//       setState(() {
//         _allSpecies      = loaded;
//         _filteredSpecies = loaded;
//         _buildMarkers(loaded);
//       });
//     } catch (_) {
//       // Fallback: seed a few demo pins so the UI still works
//       _loadDemoSpecies();
//     }
//   }

//   void _loadDemoSpecies() {
//     final demo = [
//       _Species(id:'1', name:'Lynx pardinus',      commonName:'Iberian Lynx',       category:'EN', group:'MAMMALIA',   lat:38.00, lng:-4.50),
//       _Species(id:'2', name:'Aquila adalberti',   commonName:'Spanish Imperial Eagle', category:'VU', group:'AVES',   lat:39.50, lng:-5.80),
//       _Species(id:'3', name:'Galemys pyrenaicus', commonName:'Pyrenean Desman',    category:'VU', group:'MAMMALIA',   lat:43.00, lng:-1.60),
//       _Species(id:'4', name:'Mauremys leprosa',   commonName:'Mediterranean Turtle',  category:'NT', group:'REPTILIA',lat:37.20, lng:-5.00),
//       _Species(id:'5', name:'Ursus arctos',       commonName:'Brown Bear',         category:'VU', group:'MAMMALIA',   lat:43.20, lng:-0.80),
//       _Species(id:'6', name:'Gypaetus barbatus',  commonName:'Bearded Vulture',    category:'NT', group:'AVES',       lat:42.50, lng: 1.50),
//       _Species(id:'7', name:'Emys orbicularis',   commonName:'European Pond Turtle',  category:'NT', group:'REPTILIA',lat:40.20, lng:-3.20),
//       _Species(id:'8', name:'Rhinolophus ferrumequinum', commonName:'Greater Horseshoe Bat', category:'LC', group:'MAMMALIA', lat:41.60, lng:-4.70),
//       _Species(id:'9', name:'Lutra lutra',        commonName:'Eurasian Otter',     category:'NT', group:'MAMMALIA',   lat:38.80, lng:-6.50),
//       _Species(id:'10',name:'Testudo graeca',     commonName:'Spur-thighed Tortoise', category:'VU', group:'REPTILIA',lat:37.50, lng:-1.80),
//     ];
//     setState(() {
//       _allSpecies      = demo;
//       _filteredSpecies = demo;
//       _buildMarkers(demo);
//     });
//   }

//   void _buildMarkers(List<_Species> species) {
//     _markers = species.map((s) {
//       return Marker(
//         markerId: MarkerId(s.id),
//         position: LatLng(s.lat, s.lng),
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//         infoWindow: InfoWindow(title: s.commonName.isNotEmpty ? s.commonName : s.name),
//         onTap: () => _onMarkerTap(s),
//       );
//     }).toSet();
//   }

//   void _onMarkerTap(_Species species) {
//     setState(() => _selectedSpecies = species);
//     _speak('${species.commonName.isNotEmpty ? species.commonName : species.name}. '
//         'Conservation status: ${_categoryLabel(species.category)}.');
//     _flyLgToSpecies(species);
//   }

//   // ── Search & filter ───────────────────────────────────────────
//   void _onSearch(String query) {
//     _applyFilters(query, _activeFilter);
//   }

//   void _onFilter(String filter) {
//     setState(() =>
//       _activeFilter = _activeFilter == filter ? '' : filter);
//     _applyFilters(_searchController.text, _activeFilter);
//   }

//   void _applyFilters(String query, String filter) {
//     var list = _allSpecies;

//     if (query.isNotEmpty) {
//       final q = query.toLowerCase();
//       list = list.where((s) =>
//         s.name.toLowerCase().contains(q) ||
//         s.commonName.toLowerCase().contains(q)).toList();
//     }

//     if (filter == 'Extinct level') {
//       list = list.where((s) =>
//         ['EX','EW','CR','EN','VU'].contains(s.category)).toList();
//     } else if (filter == 'Groups') {
//       list.sort((a, b) => a.group.compareTo(b.group));
//     } else if (filter == 'Places') {
//       list.sort((a, b) => a.lat.compareTo(b.lat));
//     }

//     setState(() {
//       _filteredSpecies = list;
//       _buildMarkers(list);
//     });
//   }

//   // ── Voice search ──────────────────────────────────────────────
//   Future<void> _toggleVoice() async {
//     if (_isListening) {
//       await _speech.stop();
//       setState(() => _isListening = false);
//       return;
//     }
//     final available = await _speech.initialize();
//     if (!available) return;
//     setState(() => _isListening = true);
//     _speech.listen(onResult: (result) {
//       _searchController.text = result.recognizedWords;
//       _onSearch(result.recognizedWords);
//       if (result.finalResult) setState(() => _isListening = false);
//     });
//   }

//   // ── TTS ───────────────────────────────────────────────────────
//   Future<void> _speak(String text) async {
//     if (_isMuted) return;
//     await _tts.setLanguage('en-US');
//     await _tts.setSpeechRate(0.5);
//     await _tts.speak(text);
//   }

//   void _toggleMute() => setState(() {
//     _isMuted = !_isMuted;
//     if (_isMuted) _tts.stop();
//   });

//   // ── Dark mode ─────────────────────────────────────────────────
//   Future<void> _toggleDarkMode() async {
//     setState(() => _isDarkMode = !_isDarkMode);
//     final controller = await _mapController.future;
//     controller.setMapStyle(_isDarkMode ? _kDarkMapStyle : null);
//   }

//   // ── LG commands ───────────────────────────────────────────────
//   Future<void> _sendCommand(String command) async {
//     if (widget.client == null) return;
//     try {
//       final session = await widget.client!.execute(command);
//       await session.done;
//     } catch (_) {}
//   }

//   Future<void> _flyLgToSpecies(_Species s) async {
//     if (!widget.isConnected) return;
//     setState(() => _lgBusy = true);
//     final kml = _buildFlyToKml(s.lat, s.lng, s.name);
//     final b64 = base64Encode(utf8.encode(kml));
//     await _sendCommand(
//         "echo '$b64' | base64 -d > /var/www/html/kml/species.kml");
//     await _sendCommand(
//         "echo 'http://lg1:81/kml/species.kml' > /var/www/html/kmls.txt");
//     setState(() => _lgBusy = false);
//   }

//   Future<void> _sendHistoryJourney() async {
//     if (!widget.isConnected || _selectedSpecies == null) return;
//     setState(() => _lgBusy = true);
//     await _speak('Showing the history journey of ${_selectedSpecies!.commonName.isNotEmpty
//         ? _selectedSpecies!.commonName : _selectedSpecies!.name}');
//     final kml = _buildBalloonKml(
//       _selectedSpecies!,
//       title:   'History Journey',
//       content: 'Historical range and population data for ${_selectedSpecies!.name}.',
//     );
//     final b64 = base64Encode(utf8.encode(kml));
//     final left = widget.screens;
//     await _sendCommand(
//         "echo '$b64' | base64 -d > /var/www/html/kml/slave_$left.kml");
//     await _setRefresh();
//     setState(() => _lgBusy = false);
//   }

//   Future<void> _sendLookingAhead() async {
//     if (!widget.isConnected || _selectedSpecies == null) return;
//     setState(() => _lgBusy = true);
//     await _speak('Showing looking ahead projection for ${_selectedSpecies!.commonName.isNotEmpty
//         ? _selectedSpecies!.commonName : _selectedSpecies!.name}');
//     final kml = _buildBalloonKml(
//       _selectedSpecies!,
//       title:   'Looking Ahead',
//       content: 'Future range projections and conservation outlook for ${_selectedSpecies!.name}.',
//     );
//     final b64 = base64Encode(utf8.encode(kml));
//     final left = widget.screens;
//     await _sendCommand(
//         "echo '$b64' | base64 -d > /var/www/html/kml/slave_$left.kml");
//     await _setRefresh();
//     setState(() => _lgBusy = false);
//   }

//   Future<void> _setRefresh() async {
//     for (var i = 2; i <= widget.screens; i++) {
//       final search  = '<href>##LG_PHPIFACE##kml\\/slave_$i.kml<\\/href>';
//       final replace = '$search<refreshMode>onInterval<\\/refreshMode>'
//           '<refreshInterval>2<\\/refreshInterval>';
//       await _sendCommand(
//           "sshpass -p lg ssh -t lg$i@lg$i 'echo lg | sudo -S sed -i "
//           '"s/$replace/$search/" ~/earth/kml/slave/myplaces.kml\'');
//       await _sendCommand(
//           "sshpass -p lg ssh -t lg$i@lg$i 'echo lg | sudo -S sed -i "
//           '"s/$search/$replace/" ~/earth/kml/slave/myplaces.kml\'');
//     }
//   }

//   // ── KML builders ─────────────────────────────────────────────
//   String _buildFlyToKml(double lat, double lng, String name) => '''
// <?xml version="1.0" encoding="UTF-8"?>
// <kml xmlns="http://www.opengis.net/kml/2.2"
//      xmlns:gx="http://www.google.com/kml/ext/2.2">
//   <Document>
//     <gx:Tour><name>Fly to $name</name>
//       <gx:Playlist>
//         <gx:FlyTo>
//           <gx:duration>3</gx:duration>
//           <gx:flyToMode>smooth</gx:flyToMode>
//           <LookAt>
//             <longitude>$lng</longitude><latitude>$lat</latitude>
//             <altitude>0</altitude><range>800000</range>
//             <tilt>0</tilt><heading>0</heading>
//           </LookAt>
//         </gx:FlyTo>
//       </gx:Playlist>
//     </gx:Tour>
//   </Document>
// </kml>''';

//   String _buildBalloonKml(_Species s, {required String title, required String content}) => '''
// <?xml version="1.0" encoding="UTF-8"?>
// <kml xmlns="http://www.opengis.net/kml/2.2">
//   <Document>
//     <Placemark>
//       <name>${s.commonName.isNotEmpty ? s.commonName : s.name}</name>
//       <description><![CDATA[
//         <h2>$title</h2>
//         <p><b>Scientific name:</b> ${s.name}</p>
//         <p><b>Status:</b> ${_categoryLabel(s.category)}</p>
//         <p><b>Group:</b> ${s.group}</p>
//         <p>$content</p>
//       ]]></description>
//       <Point><coordinates>${s.lng},${s.lat},0</coordinates></Point>
//     </Placemark>
//   </Document>
// </kml>''';

//   String _categoryLabel(String cat) => {
//     'EX': 'Extinct',
//     'EW': 'Extinct in the Wild',
//     'CR': 'Critically Endangered',
//     'EN': 'Endangered',
//     'VU': 'Vulnerable',
//     'NT': 'Near Threatened',
//     'LC': 'Least Concern',
//     'DD': 'Data Deficient',
//   }[cat] ?? cat;

//   Color _categoryColor(String cat) => {
//     'EX': Colors.black,
//     'EW': const Color(0xFF4A148C),
//     'CR': const Color(0xFFB71C1C),
//     'EN': const Color(0xFFE53935),
//     'VU': const Color(0xFFF57C00),
//     'NT': const Color(0xFFF9A825),
//     'LC': const Color(0xFF2E7D32),
//     'DD': Colors.grey,
//   }[cat] ?? Colors.grey;

//   // ── BUILD ─────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // ── Google Map ────────────────────────────────────────
//           GoogleMap(
//             initialCameraPosition: _initialCamera,
//             markers: _markers,
//             onMapCreated: (c) => _mapController.complete(c),
//             myLocationButtonEnabled: false,
//             zoomControlsEnabled: false,
//             mapToolbarEnabled: false,
//           ),

//           // ── Top overlay ───────────────────────────────────────
//           SafeArea(
//             child: Column(
//               children: [
//                 // Connected badge
//                 if (widget.isConnected)
//                   Align(
//                     alignment: Alignment.topRight,
//                     child: Container(
//                       margin: const EdgeInsets.only(right: 16, top: 8),
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 12, vertical: 5),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.92),
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
//                       ),
//                       child: const Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.check, size: 14, color: Color(0xFF2E7D32)),
//                           SizedBox(width: 4),
//                           Text('Connected',
//                               style: TextStyle(
//                                   fontSize: 13,
//                                   fontWeight: FontWeight.w600,
//                                   color: Color(0xFF2E7D32))),
//                         ],
//                       ),
//                     ),
//                   ),

//                 const SizedBox(height: 6),

//                 // Search bar
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   child: Container(
//                     height: 48,
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(28),
//                       boxShadow: const [
//                         BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,2))
//                       ],
//                     ),
//                     child: Row(
//                       children: [
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: TextField(
//                             controller: _searchController,
//                             onChanged: _onSearch,
//                             style: const TextStyle(fontSize: 14),
//                             decoration: const InputDecoration(
//                               hintText: 'Enter name of species..',
//                               hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
//                               border: InputBorder.none,
//                               isDense: true,
//                             ),
//                           ),
//                         ),
//                         // Voice
//                         GestureDetector(
//                           onTap: _toggleVoice,
//                           child: Icon(
//                             _isListening ? Icons.mic : Icons.mic_none,
//                             color: _isListening
//                                 ? const Color(0xFFCC0000)
//                                 : Colors.black54,
//                             size: 22,
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         const Icon(Icons.search, color: Colors.black54, size: 22),
//                         const SizedBox(width: 14),
//                       ],
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 10),

//                 // Filter chips
//                 Padding(
//                   padding: const EdgeInsets.only(left: 12),
//                   child: SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: Row(
//                       children: [
//                         _filterChip('Extinct level'),
//                         const SizedBox(width: 8),
//                         _filterChip('Groups'),
//                         const SizedBox(width: 8),
//                         _filterChip('Places'),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ── Dark mode button (bottom left) ────────────────────
//           Positioned(
//             bottom: 80,
//             left: 16,
//             child: GestureDetector(
//               onTap: _toggleDarkMode,
//               child: Container(
//                 width: 44, height: 44,
//                 decoration: BoxDecoration(
//                   color: _isDarkMode
//                       ? const Color(0xFF222222)
//                       : Colors.white,
//                   shape: BoxShape.circle,
//                   boxShadow: const [
//                     BoxShadow(color: Colors.black26, blurRadius: 8)
//                   ],
//                 ),
//                 child: Icon(
//                   _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
//                   color: _isDarkMode ? Colors.white70 : Colors.black54,
//                   size: 22,
//                 ),
//               ),
//             ),
//           ),

//           // ── Species detail panel (shown after marker tap) ─────
//           if (_selectedSpecies != null)
//             _SpeciesPanel(
//               species: _selectedSpecies!,
//               isMuted: _isMuted,
//               lgBusy: _lgBusy,
//               isConnected: widget.isConnected,
//               categoryLabel: _categoryLabel,
//               categoryColor: _categoryColor,
//               onHistoryJourney: _sendHistoryJourney,
//               onLookingAhead:   _sendLookingAhead,
//               onToggleMute:     _toggleMute,
//               onClose: () => setState(() => _selectedSpecies = null),
//             ),
//         ],
//       ),

//       // ── Bottom nav ────────────────────────────────────────────
//       bottomNavigationBar: _MapsBottomNav(),
//     );
//   }

//   Widget _filterChip(String label) {
//     final active = _activeFilter == label;
//     return GestureDetector(
//       onTap: () => _onFilter(label),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//         decoration: BoxDecoration(
//           color: active ? const Color(0xFF333333) : Colors.white,
//           borderRadius: BorderRadius.circular(20),
//           boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w500,
//             color: active ? Colors.white : Colors.black87,
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ══════════════════════════════════════════════════════════════════
// // Species detail panel (right screen in mockup)
// // ══════════════════════════════════════════════════════════════════
// class _SpeciesPanel extends StatelessWidget {
//   final _Species species;
//   final bool isMuted;
//   final bool lgBusy;
//   final bool isConnected;
//   final String Function(String) categoryLabel;
//   final Color Function(String) categoryColor;
//   final VoidCallback onHistoryJourney;
//   final VoidCallback onLookingAhead;
//   final VoidCallback onToggleMute;
//   final VoidCallback onClose;

//   const _SpeciesPanel({
//     required this.species,
//     required this.isMuted,
//     required this.lgBusy,
//     required this.isConnected,
//     required this.categoryLabel,
//     required this.categoryColor,
//     required this.onHistoryJourney,
//     required this.onLookingAhead,
//     required this.onToggleMute,
//     required this.onClose,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Positioned.fill(
//       child: Stack(
//         children: [
//           // semi-transparent backdrop (tappable to dismiss)
//           GestureDetector(
//             onTap: onClose,
//             child: Container(color: Colors.transparent),
//           ),

//           // panel anchored to center
//           Center(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 28),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // ── Species info card ──────────────────────────
//                   Container(
//                     padding: const EdgeInsets.all(18),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.96),
//                       borderRadius: BorderRadius.circular(18),
//                       boxShadow: const [
//                         BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0,4))
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     species.commonName.isNotEmpty
//                                         ? species.commonName
//                                         : species.name,
//                                     style: const TextStyle(
//                                       fontSize: 17,
//                                       fontWeight: FontWeight.w700,
//                                       color: Color(0xFF1A1A1A),
//                                     ),
//                                   ),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                     species.name,
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       fontStyle: FontStyle.italic,
//                                       color: Colors.black45,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             // Status badge
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 10, vertical: 4),
//                               decoration: BoxDecoration(
//                                 color: categoryColor(species.category)
//                                     .withOpacity(0.12),
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(
//                                     color: categoryColor(species.category)
//                                         .withOpacity(0.4)),
//                               ),
//                               child: Text(
//                                 species.category,
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w700,
//                                   color: categoryColor(species.category),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             // Close
//                             GestureDetector(
//                               onTap: onClose,
//                               child: const Icon(Icons.close,
//                                   size: 20, color: Colors.black38),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           categoryLabel(species.category),
//                           style: TextStyle(
//                             fontSize: 13,
//                             color: categoryColor(species.category),
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         if (species.group.isNotEmpty) ...[
//                           const SizedBox(height: 4),
//                           Text('Group: ${species.group}',
//                               style: const TextStyle(
//                                   fontSize: 12, color: Colors.black45)),
//                         ],
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 20),

//                   // ── History Journey button ─────────────────────
//                   _LgButton(
//                     label: 'History Journey',
//                     busy: lgBusy,
//                     enabled: isConnected,
//                     onTap: onHistoryJourney,
//                   ),

//                   const SizedBox(height: 14),

//                   // ── Looking Ahead button ───────────────────────
//                   _LgButton(
//                     label: 'Looking Ahead',
//                     busy: lgBusy,
//                     enabled: isConnected,
//                     onTap: onLookingAhead,
//                   ),

//                   const SizedBox(height: 20),

//                   // ── Mute button ────────────────────────────────
//                   GestureDetector(
//                     onTap: onToggleMute,
//                     child: Container(
//                       width: 52, height: 52,
//                       decoration: BoxDecoration(
//                         color: isMuted
//                             ? const Color(0xFF333333)
//                             : Colors.white,
//                         shape: BoxShape.circle,
//                         boxShadow: const [
//                           BoxShadow(color: Colors.black26, blurRadius: 8)
//                         ],
//                       ),
//                       child: Icon(
//                         isMuted ? Icons.volume_off : Icons.volume_up,
//                         color: isMuted ? Colors.white : Colors.black54,
//                         size: 24,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Big dark pill button for LG actions ──────────────────────────
// class _LgButton extends StatelessWidget {
//   final String label;
//   final bool busy;
//   final bool enabled;
//   final VoidCallback onTap;

//   const _LgButton({
//     required this.label,
//     required this.busy,
//     required this.enabled,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: enabled && !busy ? onTap : null,
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 22),
//         decoration: BoxDecoration(
//           color: enabled
//               ? const Color(0xFF2D2D2D)
//               : const Color(0xFF2D2D2D).withOpacity(0.45),
//           borderRadius: BorderRadius.circular(36),
//           boxShadow: const [
//             BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0,4))
//           ],
//         ),
//         child: busy
//             ? const Center(
//                 child: SizedBox(
//                   width: 22, height: 22,
//                   child: CircularProgressIndicator(
//                       color: Colors.white, strokeWidth: 2),
//                 ),
//               )
//             : Text(
//                 label,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   letterSpacing: 0.3,
//                 ),
//               ),
//       ),
//     );
//   }
// }

// // ══════════════════════════════════════════════════════════════════
// // Data model
// // ══════════════════════════════════════════════════════════════════
// class _Species {
//   final String id;
//   final String name;
//   final String commonName;
//   final String category;
//   final String group;
//   final double lat;
//   final double lng;

//   const _Species({
//     required this.id,
//     required this.name,
//     required this.commonName,
//     required this.category,
//     required this.group,
//     required this.lat,
//     required this.lng,
//   });
// }

// // ══════════════════════════════════════════════════════════════════
// // Bottom nav — Maps tab active
// // ══════════════════════════════════════════════════════════════════
// class _MapsBottomNav extends StatelessWidget {
//   const _MapsBottomNav();

//   @override
//   Widget build(BuildContext context) {
//     const labels      = ['Home', 'Maps', 'Chat', 'Tools', 'Settings'];
//     const activeIndex = 1;
// // ══════════════════════════════════════════════════════════════════
// // Dark map style JSON
// // ══════════════════════════════════════════════════════════════════
// const String _kDarkMapStyle = '''[
//   {"elementType":"geometry","stylers":[{"color":"#212121"}]},
//   {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
//   {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
//   {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
//   {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
//   {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
//   {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
//   {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
//   {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
//   {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},
//   {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
//   {"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},
//   {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
//   {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
//   {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
//   {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
//   {"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},
//   {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
//   {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
//   {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
//   {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
// ]''';