// species_service.dart
// Fetches IUCN Red List API data, then calls Gemini to generate
// storytelling narrative + TTS script. Keys come from .env only.
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/species.dart';

class SpeciesStory {
  final String narrative;
  final String ttsScript;
  final Map<String,String> iucnFields;

  const SpeciesStory({
    required this.narrative,
    required this.ttsScript,
    required this.iucnFields,
  });

  String get habitat =>
      iucnFields['habitat_text'] ?? '';

  String get threats =>
      iucnFields['threats'] ?? '';

  String get conservation =>
      iucnFields['conservation'] ?? '';

  String get population =>
      iucnFields['population'] ?? '';

  String get countries =>
      iucnFields['countries'] ?? '';
}

class SpeciesService {
  String get _iucnKey   => dotenv.env['IUCN_API_KEY']  ?? '';
  String get _geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const _iucnBase = 'https://apiv3.iucnredlist.org/api/v3';
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models'
      '/gemini-3.5-flash:generateContent';

  // ── Step 1: fetch IUCN assessment data ───────────────────────
  Future<Map<String, String>> fetchIucnData(Species s) async {
    final result = <String, String>{};
    final id = s.internalTaxonId;

    // Parallel fetch: narrative + species detail + countries
    final responses = await Future.wait([
      http.get(Uri.parse('$_iucnBase/species/narrative/id/$id?token=$_iucnKey'))
          .timeout(const Duration(seconds: 15)),
      http.get(Uri.parse('$_iucnBase/species/id/$id?token=$_iucnKey'))
          .timeout(const Duration(seconds: 15)),
      http.get(Uri.parse('$_iucnBase/species/countries/id/$id?token=$_iucnKey'))
          .timeout(const Duration(seconds: 15)),
    ]).catchError((_) => <http.Response>[]);

    try {
      // Narrative fields
      if (responses.isNotEmpty && responses[0].statusCode == 200) {
        final r = ((json.decode(responses[0].body)['result'] as List?)
                ?.firstOrNull as Map?) ??
            {};
        result['rationale']    = _clean(r['rationale'])           ?? '';
        result['threats']      = _clean(r['threats'])             ?? s.threats;
        result['conservation'] = _clean(r['conservation_actions'])  ?? '';
        result['population']   = _clean(r['population'])          ?? 'Unknown';
        result['habitat_text'] = _clean(r['habitat'])             ?? s.habitat;
        result['use_trade']    = _clean(r['use_trade'])           ?? '';
      }

      // Taxonomy
      if (responses.length > 1 && responses[1].statusCode == 200) {
        final r = ((json.decode(responses[1].body)['result'] as List?)
                ?.firstOrNull as Map?) ??
            {};
        result['order_name']       = r['order_name']?.toString()  ?? '';
        result['family_name']      = r['family_name']?.toString() ?? '';
        result['main_common_name'] =
            r['main_common_name']?.toString() ?? s.commonName;
      }

      // Countries
      if (responses.length > 2 && responses[2].statusCode == 200) {
        final list = json.decode(responses[2].body)['result'] as List? ?? [];
        result['countries'] = list
            .map((c) => c['country']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .take(6)
            .join(', ');
      }
    } catch (e) {
      // fallback to hardcoded data
      result['threats']      = s.threats;
      result['habitat_text'] = s.habitat;
      result['population']   = 'Unknown';
    }

    return result;
  }

  Future<SpeciesStory> generateThemedStory(
    Species s,
    Map<String, String> iucn, {
    required String mode, // 'history' or 'future'
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_geminiUrl?key=$_geminiKey'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'contents': [
                {'parts': [{'text': _themedPrompt(s, iucn, mode)}]}
              ],
              'generationConfig': {
                'temperature': 0.75,
                'maxOutputTokens': 1024,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final raw = (json.decode(res.body)['candidates']?[0]?['content']
                ?['parts']?[0]?['text'] as String? ?? '');
        final cleaned = raw
            .replaceAll(RegExp(r'```json\s*'), '')
            .replaceAll(RegExp(r'```\s*'), '')
            .trim();
        final parsed = json.decode(cleaned) as Map<String, dynamic>;
        return SpeciesStory(
          narrative: parsed['narrative'] as String? ?? _fallbackThemed(s, iucn, mode),
          ttsScript: parsed['tts_script'] as String? ?? _fallbackTts(s),
          iucnFields: iucn,
        );
      } else {
        print('Gemini returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      print('Gemini call FAILED, using fallback: $e');
      // fall through to fallback
    }
    return SpeciesStory(
      narrative: _fallbackThemed(s, iucn, mode),
      ttsScript: _fallbackTts(s),
      iucnFields: iucn,
    );
  }

  String _themedPrompt(Species s, Map<String, String> iucn, String mode) {
    final shared = '''
  SPECIES DATA (from IUCN Red List):
  - Common name: ${s.commonName}
  - Scientific name: ${s.scientificName}
  - IUCN Status: ${s.category == 'CR' ? 'Critically Endangered (CR)' : 'Endangered (EN)'}
  - Habitat: ${iucn['habitat_text'] ?? s.habitat}
  - Key threats: ${iucn['threats'] ?? s.threats}
  - Conservation actions: ${iucn['conservation'] ?? 'Not available'}
  - Population: ${iucn['population'] ?? 'Unknown'}
  ''';

    if (mode == 'history') {
      return '''
  You are a conservation storyteller for a Liquid Galaxy multi-screen exhibit.
  $shared
  Write about how this species' population and range have likely declined over
  recent decades, based ONLY on the threats and population data above. Do NOT
  invent specific years, percentages, or figures not present in the data —
  describe the qualitative trend (declining population, shrinking range)
  rather than fabricated statistics.

  Return JSON with exactly two keys:
  "narrative": HTML (no html/body/head tags), max 140 words, <p> tags,
    bold the species name, emotional but factual tone about the decline.
  "tts_script": Plain text, max 70 words, spoken narration about the decline.
  Return ONLY valid JSON.
  ''';
    } else {
      return '''
  You are a conservation storyteller for a Liquid Galaxy multi-screen exhibit.
  $shared
  Write about the future outlook for this species: threats it will likely
  keep facing, and concrete conservation actions (from the data above, or
  well-known strategies for this type of species) that could help it recover.
  Hopeful but realistic tone.

  Return JSON with exactly two keys:
  "narrative": HTML (no html/body/head tags), max 140 words, <p> tags,
    bold the species name, end on a hopeful, actionable note.
  "tts_script": Plain text, max 70 words, ending with a call to action.
  Return ONLY valid JSON.
  ''';
    }
  }

  String _fallbackThemed(Species s, Map<String, String> iucn, String mode) {
    if (mode == 'history') {
      return '<p><b>${s.commonName}</b> has seen its population decline over '
          'recent decades due to ${iucn['threats'] ?? s.threats}.</p>'
          '<p>Its range within ${iucn['habitat_text'] ?? s.habitat} continues to shrink.</p>';
    }
    return '<p>Without stronger action, <b>${s.commonName}</b> will keep facing '
        '${iucn['threats'] ?? s.threats}.</p>'
        '<p>${iucn['conservation'] ?? 'Continued habitat protection and anti-poaching efforts'} '
        'could help it recover.</p>';
  }

  // Gemini story genearation for general species (not a specific story)
  Future<SpeciesStory> generateStory(
      Species s, Map<String, String> iucn) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_geminiUrl?key=$_geminiKey'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt(s, iucn)}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.75,
                'maxOutputTokens': 1024,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final raw = (json.decode(res.body)['candidates']?[0]?['content']
                ?['parts']?[0]?['text'] as String? ??
            '');
        final cleaned = raw
            .replaceAll(RegExp(r'```json\s*'), '')
            .replaceAll(RegExp(r'```\s*'), '')
            .trim();
        final parsed = json.decode(cleaned) as Map<String, dynamic>;
        return SpeciesStory(
          narrative:  parsed['narrative']  as String? ?? _fallbackHtml(s, iucn),
          ttsScript:  parsed['tts_script'] as String? ?? _fallbackTts(s),
          iucnFields: iucn,
        );
      } else {
        print('Gemini returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      print('Gemini call FAILED, using fallback: $e');
      // Gemini unavailable — use fallback
    }
    return SpeciesStory(
      narrative:  _fallbackHtml(s, iucn),
      ttsScript:  _fallbackTts(s),
      iucnFields: iucn,
    );
  }

  Future<SpeciesStory> getStory(Species s, Map<String, String> iucn) =>
    _cached('${s.internalTaxonId}_initial', () => generateStory(s, iucn));

  Future<SpeciesStory> getThemedStory(Species s, Map<String, String> iucn, String mode) =>
      _cached('${s.internalTaxonId}_$mode', () => generateThemedStory(s, iucn, mode: mode));

  Future<SpeciesStory> _cached(String key, Future<SpeciesStory> Function() generate) async {
    final box = Hive.box('species_stories');
    final cached = box.get(key);
    if (cached != null) {
      final map = Map<String, dynamic>.from(cached);
      return SpeciesStory(
        narrative: map['narrative'],
        ttsScript: map['ttsScript'],
        iucnFields: Map<String, String>.from(map['iucnFields']),
      );
    }

    final story = await generate();
    await box.put(key, {
      'narrative': story.narrative,
      'ttsScript': story.ttsScript,
      'iucnFields': story.iucnFields,
    });
    return story;
  }

  // ── Gemini prompt ─────────────────────────────────────────────
  String _prompt(Species s, Map<String, String> iucn) => '''
You are a conservation storyteller for a Liquid Galaxy multi-screen exhibit.
All information you use MUST come only from the data below — do not invent facts.

SPECIES DATA (from IUCN Red List):
- Common name: ${s.commonName}
- Scientific name: ${s.scientificName}
- IUCN Status: ${s.category == 'CR' ? 'Critically Endangered (CR)' : 'Endangered (EN)'}
- Taxonomic group: ${s.group}
- Habitat: ${iucn['habitat_text'] ?? s.habitat}
- Key threats: ${iucn['threats'] ?? s.threats}
- Conservation actions: ${iucn['conservation'] ?? 'Not available'}
- Population: ${iucn['population'] ?? 'Unknown'}
- Countries of occurrence: ${iucn['countries'] ?? 'Vietnam region'}
- IUCN rationale: ${iucn['rationale'] ?? 'Not available'}

Return a JSON object with exactly two keys:

"narrative": HTML content (no html/body/head tags) for a large display screen.
  Max 160 words. Use <p> tags. Bold the species name. Show status in
  ${s.category == 'CR' ? '#CC0000' : '#E53935'} colour. Emotional and educational tone.
  Only use facts from the data above.

"tts_script": Plain text (no HTML). Max 70 words. Spoken aloud by a narrator.
  Start with the species name. Only use facts from the data above.
  End with a conservation call to action.

Return ONLY valid JSON. No markdown, no explanation.
''';

  // ── Fallbacks ─────────────────────────────────────────────────
  String _fallbackHtml(Species s, Map<String, String> iucn) {
    final color = s.category == 'CR' ? '#CC0000' : '#E53935';
    final label = s.category == 'CR' ? 'Critically Endangered' : 'Endangered';
    return '<p><b>${s.commonName}</b> (<i>${s.scientificName}</i>) is '
        '<span style="color:$color;font-weight:bold;">$label</span> '
        'on the IUCN Red List.</p>'
        '<p>${iucn['habitat_text'] ?? s.habitat}</p>'
        '<p><b>Threats:</b> ${iucn['threats'] ?? s.threats}</p>'
        '<p>Support conservation efforts before this species disappears forever.</p>';
  }

  String _fallbackTts(Species s) {
    final label = s.category == 'CR' ? 'Critically Endangered' : 'Endangered';
    return '${s.commonName}. This $label species is under serious threat. '
        '${s.threats} '
        'We can still make a difference. '
        'Learn more at the IUCN Red List.';
  }

  String? _clean(dynamic v) => v == null
      ? null
      : v.toString()
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
}
