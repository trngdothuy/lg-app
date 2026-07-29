import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
// import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../data/species_data.dart';
import '../models/species.dart';

import '../services/species_service.dart';
// import '../services/kml_service.dart';
import '../services/lg_service.dart';

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
  bool _isDark = false;
  Set<Marker> _markers = {};

  // Throttle LG camera sync to avoid flooding SSH
  Timer? _camThrottle;

  // ── Species state ─────────────────────────────────────────────
  List<Species> _filtered = List.of(vietnamSpecies);
  Species? _selected;
  SpeciesStory? _story;
  bool _loadingStory = false;

  // ── Search / filter ───────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _activeFilter = ''; // 'Extinct level' | 'Groups' | 'Places'

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
    _lg?.flyTo(lat: species.lat, lng: species.lng, range: 500000);

    // Pipeline: IUCN → Gemini → LG + TTS
    try {
      final iucnData = await _svc.fetchIucnData(species);
      final story    = await _svc.generateStory(species, iucnData);

      if (!mounted) return;
      setState(() {
        _story        = story;
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
    await _speakText(
      'Travelling back in time for ${_selected!.commonName}. '
      '${_story!.ttsScript}',
    );
  await _lg?.showHistory(
    _selected!,
    _story!,
    );
  }

  Future<void> _onLookingAhead() async {
    if (_selected == null || _story == null) return;
    await _speakText(
      'Looking ahead for ${_selected!.commonName}. '
      'Conservation efforts could still save this species.',
    );
    await _lg?.showFuture(
      _selected!,
      _story!,
    );
  }

  // ── Phone map camera → LG sync (throttled 500 ms) ────────────
  DateTime _lastSync = DateTime.now();
  CameraPosition? _lastCamera;

  void _onCameraMove(CameraPosition pos) {
    _lastCamera = pos;

    final now = DateTime.now();

    if (now.difference(_lastSync).inMilliseconds < 100) {
    return;
    }

    _lastSync = now;

    _lg?.flyTo(
      lat:      pos.target.latitude,
      lng:      pos.target.longitude,
      range:    _zoomToRange(pos.zoom),
      tilt:     pos.bearing,
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
    final q = _searchCtrl.text.toLowerCase().trim();

    var list = vietnamSpecies.where((s) {
      if (q.isEmpty) return true;
      return s.commonName.toLowerCase().contains(q) ||
             s.scientificName.toLowerCase().contains(q);
    }).toList();

    if (_activeFilter == 'Extinct level') {
      list = list.where((s) => s.category == 'CR').toList();
    } else if (_activeFilter == 'Groups') {
      list.sort((a, b) => a.group.compareTo(b.group));
    } else if (_activeFilter == 'Places') {
      list.sort((a, b) => a.lat.compareTo(b.lat)); // south → north
    }

    _filtered = list;
    _buildMarkers(list);
  }

  void _toggleFilter(String f) {
    setState(() => _activeFilter = _activeFilter == f ? '' : f);
    _applyFilters();
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
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.speak(text);
  }

  void _toggleMute() => setState(() {
    _isMuted = !_isMuted;
    if (_isMuted) _tts.stop();
  });

  // ── Dark mode ─────────────────────────────────────────────────
  Future<void> _toggleDark() async {
    setState(() => _isDark = !_isDark);
    final c = await _mapCtrl.future;
    await c.setMapStyle(_isDark ? _kDarkStyle : null);
  }

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
    return Scaffold(
      body: Stack(children: [

        // ── Google Map ────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: _initCamera,
          markers: _markers,
          onMapCreated: (c) => _mapCtrl.complete(c),
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

              // Connected badge
              if (widget.isConnected)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 14, top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.93),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6)
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check,
                            size: 14, color: Color(0xFF2E7D32)),
                        SizedBox(width: 4),
                        Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Enter name of species..',
                          hintStyle: TextStyle(
                              color: Colors.black38, fontSize: 14),
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
                    const Icon(Icons.search,
                        color: Colors.black54, size: 22),
                    const SizedBox(width: 14),
                  ]),
                ),
              ),

              const SizedBox(height: 10),

              // Filter chips
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip('Extinct level'),
                    const SizedBox(width: 8),
                    _chip('Groups'),
                    const SizedBox(width: 8),
                    _chip('Places'),
                  ]),
                ),
              ),
            ],
          ),
        ),

        // ── Dark mode toggle (bottom-left, above nav bar) ─────────
        Positioned(
          bottom: 72,
          left: 16,
          child: GestureDetector(
            onTap: _toggleDark,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isDark
                    ? const Color(0xFF222222)
                    : Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8)
                ],
              ),
              child: Icon(
                _isDark
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round,
                color: _isDark ? Colors.white70 : Colors.black54,
                size: 22,
              ),
            ),
          ),
        ),

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

      bottomNavigationBar: const _MapsBottomNav(),
    );
  }

  Widget _chip(String label) {
    final active = _activeFilter == label;
    return GestureDetector(
      onTap: () => _toggleFilter(label),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF333333)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4)
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : Colors.black87,
          ),
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

// ── Bottom nav — Maps tab active ──────────────────────────────────
class _MapsBottomNav extends StatelessWidget {
  const _MapsBottomNav();

  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'Maps', 'Chat', 'Tools', 'Settings'];
    const active = 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(labels.length, (i) {
              final sel = i == active;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i == 0) Navigator.pop(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (sel)
                        Container(
                          width: 28,
                          height: 2.5,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        const SizedBox(height: 6.5),
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: sel
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF999999),
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
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