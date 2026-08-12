import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
// import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../data/species_data.dart';
import '../models/species.dart';
import '../services/species_service.dart';
// import '../services/kml_service.dart';
import '../services/lg_service.dart';
import '../providers/nav_bar_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/dark_mode_toggle.dart';

class MapsScreen extends StatefulWidget {
  final SSHClient? client;
  final String host;
  final int screens;
  final bool isConnected;

  const MapsScreen({
    super.key,
    required this.client,
    required this.host,
    required this.screens,
    required this.isConnected,
  });

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  // ── Google Maps ───────────────────────────────────────────────
  final Completer<GoogleMapController> _mapCtrl = Completer();
  // final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
  
  Map<String, String>? _iucnData;

  CameraPosition get _initCamera {
  if (vietnamSpecies.isEmpty) {
    return const CameraPosition(
      target: LatLng(14.0, 108.0),
      zoom: 5.5,
    );
  }

  final avgLat = vietnamSpecies
          .map((s) => s.lat)
          .reduce((a, b) => a + b) /
      vietnamSpecies.length;

  final avgLng = vietnamSpecies
          .map((s) => s.lng)
          .reduce((a, b) => a + b) /
      vietnamSpecies.length;

  return CameraPosition(
    target: LatLng(avgLat, avgLng),
    zoom: 6,
  );
}
  // bool _isDark = false;
  Set<Marker> _markers = {};

  // Throttle LG camera sync to avoid flooding SSH
  Timer? _camThrottle;

  // ── Species state ─────────────────────────────────────────────
  List<Species> _filtered = List.of(vietnamSpecies);
  Species? _selected;
  SpeciesStory? _story;
  bool _loadingStory = false;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();

  // Active filters
  String _statusFilter = 'All';
  String _groupFilter = 'All';
  String _habitatFilter = 'All';
  String _regionFilter = 'All';

  // Filter options
  final statusOptions = [
    'All',
    'CR',
    'EN',
  ];

  final groupOptions = [
    'All',
    'MAMMALIA',
    'AVES',
    'REPTILIA',
    'PISCES',
    'PLANTAE',
    'ARTHROPODA',
  ];

  final habitatOptions = [
    'All',
    'Forest',
    'River',
    'Wetland',
    'Ocean',
    'Coastal',
    'Grassland',
    'Mountain',
  ];

  final regionOptions = [
    'All',
    'North',
    'Central',
    'South',
  ];

  static const Map<String, List<String>> _groupAliases = {
    'AVES': ['bird', 'birds'],
    'PISCES': ['fish', 'fishes'],
    'MAMMALIA': ['mammal', 'mammals'],
    'REPTILIA': ['reptile', 'reptiles'],
    'PLANTAE': ['plant', 'plants'],
    'ARTHROPODA': ['invertebrate', 'invertebrates', 'arthropod'],
  };

  // Get region
  String _getRegion(double lat) {
      if (lat >= 20) return "North";
      if (lat >= 15) return "Central";
      return "South";
    }

    // Habitat helper
    bool _matchesHabitat(
    Species s,
    String habitat,
  ) {
    final text = s.habitat.toLowerCase();

    switch (habitat) {
      case "Forest":
        return text.contains("forest");

      case "River":
        return text.contains("river");

      case "Wetland":
        return text.contains("wetland");

      case "Ocean":
        return text.contains("ocean");

      case "Coastal":
        return text.contains("coast") ||
              text.contains("coral") ||
              text.contains("sea");

      case "Grassland":
        return text.contains("grassland");

      case "Mountain":
        return text.contains("mountain") ||
              text.contains("montane") ||
              text.contains("highland");

      default:
        return true;
    }
  }

    bool _matchesSearch(Species s, String q) {
      if (q.isEmpty) return true;

      final text = [
        s.commonName,
        s.scientificName,
        s.group,
        s.category,
        s.habitat,
        s.threats,
        ...(_groupAliases[s.group] ?? []),
      ].join(' ').toLowerCase();

      return text.contains(q);
    }

  // ── Voice ─────────────────────────────────────────────────────
  // late stt.SpeechToText _speech;
  // bool _isListening = false;

  // ── TTS ───────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _isMuted = false;

  // ── Services ──────────────────────────────────────────────────
  final SpeciesService _svc = SpeciesService();
  LGService? _lg;

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // _speech = stt.SpeechToText();
    _buildMarkers(_filtered);

     WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitAllMarkers();
    });

    if (widget.isConnected && widget.client != null) {
      _lg = LGService(
        client:  widget.client!,
        host:    widget.host,
        screens: widget.screens,      );
      _initLg();
    }
  }

  @override
  void dispose() {
    _camThrottle?.cancel();
    _searchCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  // Update dark mode style
  Future<void> _updateMapStyle(bool isDark) async {
    if (!_mapCtrl.isCompleted) return;

    final controller = await _mapCtrl.future;

    await controller.setMapStyle(
      isDark ? _kDarkStyle : null,
    );
  }

  // ── LG init ───────────────────────────────────────────────────
  Future<void> _initLg() async {
    try {
      await _lg?.initialize(
          vietnamSpecies,
      );
    } catch (e) {
      debugPrint('[Maps] LG init error: $e');
    }
  }

  // ── Markers ───────────────────────────────────────────────────
  void _buildMarkers(List<Species> list) {
    setState(() {
      _markers = list.map((s) => Marker(
        markerId: MarkerId(s.id),
        position: LatLng(s.lat, s.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title:   s.commonName,
          snippet: '${s.category} · ${s.group}',
        ),
        onTap: () => _onMarkerTap(s),
      )).toSet();
    });
  }

  // Fit camera to all species markers
  Future<void> _fitAllMarkers() async {
    if (_markers.isEmpty) return;

    final controller = await _mapCtrl.future;

    double minLat = _markers.first.position.latitude;
    double maxLat = minLat;
    double minLng = _markers.first.position.longitude;
    double maxLng = minLng;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  // ── Marker tap → pipeline ────────────────────────────────────
  Future<void> _onMarkerTap(Species species) async {
    setState(() {
      _selected     = species;
      _story        = null;
      _loadingStory = true;
    });

    // Zoom phone map to species
    final ctrl = await _mapCtrl.future;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(species.lat, species.lng), 7),
    );

    // Fire-and-forget: fly LG immediately
    _lg?.flyTo(lat: species.lat, lng: species.lng, range: 1, tilt: 45);

    // Pipeline: IUCN → Gemini → LG + TTS
    try {
      final iucnData = await _svc.fetchIucnData(species);
      final story    = await _svc.getStory(species, iucnData);

      if (!mounted) return;
      setState(() {
        _story        = story;
        _iucnData    = iucnData;
        _loadingStory = false;
      });

      // TTS
      await _speakText(story.ttsScript);

      // Full LG display
      await _lg?.showSpecies(
        species,
        story,
      );   
    } catch (e) {
      debugPrint('[Maps] Pipeline error: $e');
      if (mounted) setState(() => _loadingStory = false);
    }
  }

  // ── LG action buttons ─────────────────────────────────────────
  Future<void> _onHistoryJourney() async {
    if (_selected == null || _story == null) return;
    final historyStory = await _svc.getThemedStory(
      _selected!, _iucnData!, 'history',
    );
    await _speakText(
      'Travelling back in time for ${_selected!.commonName}. '
      '${historyStory.ttsScript}',
    );
    await _lg?.showHistory(
      _selected!,
      historyStory,
      );
  }

  Future<void> _onLookingAhead() async {
    if (_selected == null || _story == null) return;
    final futureStory = await _svc.getThemedStory(
      _selected!, _iucnData!, 'future',
    );
    await _speakText(
      'Looking ahead for ${_selected!.commonName}. '
      '${futureStory.ttsScript}',
    );
    await _lg?.showFuture(
      _selected!,
      futureStory,
    );
  }

  // ── Phone map camera → LG sync (throttled 500 ms) ────────────
  DateTime _lastSync = DateTime.now();
  CameraPosition? _lastCamera;

  void _onCameraMove(CameraPosition pos) {
    print(
      "MOVE ${pos.target.latitude}, ${pos.target.longitude}, ${pos.zoom}");

    _lastCamera = pos;

    final now = DateTime.now();

    const syncInterval = Duration(milliseconds: 800);

    if (now.difference(_lastSync) < syncInterval) {
    return;
    }

    _lastSync = now;

    print('LG instance: $_lg, isConnected: ${widget.isConnected}');
    _lg?.flyTo(
      lat:      pos.target.latitude,
      lng:      pos.target.longitude,
      range:    _zoomToRange(pos.zoom),
      tilt:     pos.tilt,
      heading: pos.bearing,
      duration: 0,
    );
  }

  void _onCameraIdle() {
    if (_lastCamera == null) return;

    _lg?.flyTo(
      lat: _lastCamera!.target.latitude,
      lng: _lastCamera!.target.longitude,
      range: _zoomToRange(_lastCamera!.zoom),
      tilt: _lastCamera!.tilt,
      heading: _lastCamera!.bearing,
      duration: 0,
    );
  }

  // ── Search & filter ───────────────────────────────────────────
  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();

    final list = vietnamSpecies.where((s) {

      if (!_matchesSearch(s, q))
        return false;

      if (_statusFilter != "All" &&
          s.category != _statusFilter)
        return false;

      if (_groupFilter != "All" &&
          s.group != _groupFilter)
        return false;

      if (_habitatFilter != "All" &&
          !_matchesHabitat(s, _habitatFilter))
        return false;

      if (_regionFilter != "All" &&
          _getRegion(s.lat) != _regionFilter)
        return false;

      return true;

    }).toList();

    setState(() {
      _filtered = list;
    });

    _buildMarkers(list);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitAllMarkers();
    });

    _buildMarkers(list);
    _lg?.updateMarkers(list); // keep the rig's paws matching the phone's filter
  }

  // ── Voice search ──────────────────────────────────────────────
  // Future<void> _toggleVoice() async {
  //   if (_isListening) {
  //     await _speech.stop();
  //     setState(() => _isListening = false);
  //     return;
  //   }
  //   if (!await _speech.initialize()) return;
  //   setState(() => _isListening = true);
  //   _speech.listen(onResult: (r) {
  //     _searchCtrl.text = r.recognizedWords;
  //     _applyFilters();
  //     if (r.finalResult) setState(() => _isListening = false);
  //   });
  // }

  // ── TTS ───────────────────────────────────────────────────────
  Future<void> _speakText(String text) async {
    if (_isMuted) return;
    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.speak(text);
  }

  void _toggleMute() => setState(() {
    _isMuted = !_isMuted;
    if (_isMuted) _tts.stop();
  });

  // ── Dark mode ─────────────────────────────────────────────────
  // Future<void> _toggleDark() async {
  //   final themeProvider = context.read<ThemeProvider>();
  //   themeProvider.toggleDark();
  //   final c = await _mapCtrl.future;
  //   await c.setMapStyle(themeProvider.isDark ? _kDarkStyle : null);
  // }

  // ── Helpers ───────────────────────────────────────────────────
  String _categoryLabel(String c) => c == 'CR'
      ? 'Critically Endangered'
      : 'Endangered';

  Color _categoryColor(String c) => c == 'CR'
      ? const Color(0xFFB71C1C)
      : const Color(0xFFE53935);

  // Google Maps zoom → approximate ground range in metres
  double _zoomToRange(double zoom) =>
      (40075000.0 / (1 << zoom.floor())).clamp(200.0, 14000000.0);

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMapStyle(isDark);
    });

    return Scaffold(
      body: Stack(children: [

        // ── Google Map ────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: _initCamera,
          markers: _markers,
          onMapCreated: (c) {
            _mapCtrl.complete(c);
            if (isDark) {c.setMapStyle(_kDarkStyle);} 
          },
          onCameraMove: _onCameraMove,
          onCameraIdle: _onCameraIdle,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          mapType: MapType.normal,
          compassEnabled: true,
          // Tap anywhere on map (not a marker) → dismiss panel
          onTap: (_) {
            if (_selected != null) setState(() => _selected = null);
          },
        ),

        // ── Top overlay ───────────────────────────────────────────
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
            // ── Connected badge (top right) ──────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check,
                    size: 14,
                    color: widget.isConnected
                        ? const Color(0xFF2E7D32)
                        : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    widget.isConnected
                    ? 'Connected' : 'Not Connected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isConnected
                          ? const Color(0xFF2E7D32)
                          : Colors.grey,
                    ),
                  ),
                ]),
              ),
            ),

              const SizedBox(height: 6),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222222) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: Row(children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => _applyFilters(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search species, habitat, threats, group,...',
                          hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    // GestureDetector(
                    //   onTap: _toggleVoice,
                    //   child: Icon(
                    //     _isListening ? Icons.mic : Icons.mic_none,
                    //     color: _isListening
                    //         ? const Color(0xFFCC0000)
                            // : Colors.black54,
                        // size: 22,
                    //   ),
                    // ),
                    const SizedBox(width: 10),
                    Icon(Icons.search,
                        color: isDark ? Colors.white38 : Colors.black54, size: 22),
                    const SizedBox(width: 14),
                  ]),
                ),
              ),

              // Dropdown under search box
              if (_searchCtrl.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222222) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final s = _filtered[index];

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.location_on,
                          color: s.category == "CR"
                              ? Colors.red
                              : Colors.orange,
                        ),
                        title: Text(
                          s.commonName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          "${s.scientificName}\n${_categoryLabel(s.category)} • ${s.group}",
                          maxLines: 2,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black54,
                          ),
                        ),
                        isThreeLine: true,
                        onTap: () async {
                          _searchCtrl.text = s.commonName;

                          setState(() {
                            _filtered = [s];
                          });

                          _buildMarkers([s]);

                          final controller = await _mapCtrl.future;
                          controller.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(s.lat, s.lng),
                              8,
                            ),
                          );

                          _onMarkerTap(s);

                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  ),
                ),

                // Count result
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Showing ${_filtered.length} of ${vietnamSpecies.length} species",
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // Filter chips
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [

                      _filterChip(
                        title: "Status",
                        value: _statusFilter,
                        values: statusOptions,
                        onChanged: (v) {
                          setState(() => _statusFilter = v);
                          _applyFilters();
                        },
                      ),

                      const SizedBox(width: 8),

                      _filterChip(
                        title: "Group",
                        value: _groupFilter,
                        values: groupOptions,
                        onChanged: (v) {
                          setState(() => _groupFilter = v);
                          _applyFilters();
                        },
                      ),

                      const SizedBox(width: 8),

                      _filterChip(
                        title: "Habitat",
                        value: _habitatFilter,
                        values: habitatOptions,
                        onChanged: (v) {
                          setState(() => _habitatFilter = v);
                          _applyFilters();
                        },
                      ),

                      const SizedBox(width: 8),

                      _filterChip(
                        title: "Region",
                        value: _regionFilter,
                        values: regionOptions,
                        onChanged: (v) {
                          setState(() => _regionFilter = v);
                          _applyFilters();
                        },
                      ),

                    ],
                  )
                ),
              ),
            ],
          ),
        ),

        // ── Dark mode toggle (bottom-left, above nav bar) ─────────
        Positioned(
          bottom: 72,
          left: 16,
          child: DarkModeToggle(),
        ),
        // Positioned(
        //   bottom: 72,
        //   left: 16,
        //   child: GestureDetector(
        //     onTap: _toggleDark,
        //     child: Container(
        //       width: 44,
        //       height: 44,
        //       decoration: BoxDecoration(
        //         color: context.watch<ThemeProvider>().isDark
        //             ? const Color(0xFF222222)
        //             : Colors.white,
        //         shape: BoxShape.circle,
        //         boxShadow: const [
        //           BoxShadow(color: Colors.black26, blurRadius: 8)
        //         ],
        //       ),
              // child: Icon(
              //   context.watch<ThemeProvider>().isDark
              //       ? Icons.wb_sunny_outlined
              //       : Icons.nightlight_round,
              //   color: context.watch<ThemeProvider>().isDark ? Colors.white70 : Colors.black54,
              //   size: 22,
              // ),
        //     ),
        //   ),
        // ),

        // ── Species panel (shown after marker tap) ────────────────
        if (_selected != null)
          _SpeciesPanel(
            species:          _selected!,
            story:            _story,
            loading:          _loadingStory,
            isMuted:          _isMuted,
            isConnected:      widget.isConnected,
            categoryLabel:    _categoryLabel,
            categoryColor:    _categoryColor,
            onHistoryJourney: _onHistoryJourney,
            onLookingAhead:   _onLookingAhead,
            onToggleMute:     _toggleMute,
            onClose: () => setState(() => _selected = null),
          ),

      ]),

      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        client: widget.client,
        host: widget.host,
        screens: widget.screens,
        isConnected: widget.isConnected,
        // isDark: context.watch<ThemeProvider>().isDark,
      ),
    );
  }

  Widget _filterChip({
    required String title,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = context.watch<ThemeProvider>().isDark;
    
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => values
          .map(
            (v) => PopupMenuItem(
              value: v,
              child: Text(
                v,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$title • $value",
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Species panel — shown over the map after marker tap
// ══════════════════════════════════════════════════════════════
class _SpeciesPanel extends StatelessWidget {
  final Species species;
  final SpeciesStory? story;
  final bool loading;
  final bool isMuted;
  final bool isConnected;
  final String Function(String) categoryLabel;
  final Color Function(String) categoryColor;
  final VoidCallback onHistoryJourney;
  final VoidCallback onLookingAhead;
  final VoidCallback onToggleMute;
  final VoidCallback onClose;

  const _SpeciesPanel({
    required this.species,
    required this.story,
    required this.loading,
    required this.isMuted,
    required this.isConnected,
    required this.categoryLabel,
    required this.categoryColor,
    required this.onHistoryJourney,
    required this.onLookingAhead,
    required this.onToggleMute,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(children: [
        // Tap-to-dismiss backdrop
        GestureDetector(
          onTap: onClose,
          child: Container(color: Colors.transparent),
        ),

        // Panel content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── Info card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Header row
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                species.commonName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                species.scientificName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor(species.category)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: categoryColor(species.category)
                                  .withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            species.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: categoryColor(species.category),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onClose,
                          child: const Icon(Icons.close,
                              size: 20, color: Colors.black38),
                        ),
                      ]),

                      const SizedBox(height: 6),
                      Text(
                        categoryLabel(species.category),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: categoryColor(species.category),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Group: ${species.group}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        species.habitat,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Gemini TTS preview / loading
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      if (loading)
                        const Row(children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFCC0000)),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Generating story…',
                            style: TextStyle(
                                fontSize: 11, color: Colors.black45),
                          ),
                        ])
                      else if (story != null)
                        Text(
                          story!.ttsScript,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── History Journey button ─────────────────────────
                _PillButton(
                  label:   'History Journey',
                  enabled: isConnected && !loading,
                  onTap:   onHistoryJourney,
                ),

                const SizedBox(height: 12),

                // ── Looking Ahead button ───────────────────────────
                _PillButton(
                  label:   'Looking Ahead',
                  enabled: isConnected && !loading,
                  onTap:   onLookingAhead,
                ),

                const SizedBox(height: 18),

                // ── Mute button ────────────────────────────────────
                GestureDetector(
                  onTap: onToggleMute,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isMuted
                          ? const Color(0xFF333333)
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26, blurRadius: 8)
                      ],
                    ),
                    child: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color:
                          isMuted ? Colors.white : Colors.black54,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Dark pill button ──────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38,
                  blurRadius: 14,
                  offset: Offset(0, 4))
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dark map style ────────────────────────────────────────────────
const String _kDarkStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill",
   "stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill",
   "stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi.park","elementType":"geometry",
   "stylers":[{"color":"#181818"}]},
  {"featureType":"road","elementType":"geometry.fill",
   "stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road.highway","elementType":"geometry",
   "stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"water","elementType":"geometry",
   "stylers":[{"color":"#000000"}]}
]''';



// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

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
//   State<MapsScreen> createState() => _MapPageState();
// }

// class _MapPageState extends State<MapsScreen> {
//   late GoogleMapController mapController;

//   final LatLng _center = const LatLng(41.6177, 0.6200);

//   void _onMapCreated(GoogleMapController controller) {
//     mapController = controller;
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: GoogleMap(
//         onMapCreated: _onMapCreated,
//         initialCameraPosition: CameraPosition(
//           target: _center,
//           zoom: 12.0,
//         ),
//       ),
//     );
//   }
// }