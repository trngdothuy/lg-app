// species_service.dart
// Fetches IUCN Red List API data, then calls Gemini to generate
// storytelling narrative + TTS script. Keys come from .env only.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/species.dart';

class SpeciesStory {
  final String narrative;
  final String ttsScript;
  final Map<String,String> iucnFields;
  final List<Map<String, String>>? highlights; // to highlight narrative text on screen (optional)
  final List<Map<String, dynamic>>? trend; // to display trend information (optional)

  const SpeciesStory({
    required this.narrative,
    required this.ttsScript,
    required this.iucnFields,
    this.highlights,
    this.trend,
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

  String _sanitizeJsonText(String raw) {
    // The model sometimes returns literal line breaks inside string values
    // (e.g. between <p> tags), which is invalid JSON — a string's newline
    // must be escaped as \n. Since JSON structure itself doesn't depend on
    // whitespace, it's safe to flatten all raw newlines to spaces.
    return raw
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  // Warms the cache for every species before the exhibit opens, so nobody
  // waits on a Gemini call while standing at the rig. Safe to re-run —
  // _cached() skips anything already generated.
  Future<void> preloadAllStories(
      List<Species> species, {
      void Function(int done, int total)? onProgress,
      int? maxSpeciesThisRun, // for testing, limit how many species to process
    }) async {
      final targets = maxSpeciesThisRun != null
          ? species.take(maxSpeciesThisRun).toList()
          : species;
      final total = targets.length * 3; // initial + history + future
      int done = 0;

      for (final s in targets) {
        final iucn = await fetchIucnData(s);

        try { await getStory(s, iucn); } catch (_) {}
        done++; onProgress?.call(done, total);
        await Future.delayed(const Duration(seconds: 20));

        try { await getThemedStory(s, iucn, 'history'); } catch (_) {}
        done++; onProgress?.call(done, total);
        await Future.delayed(const Duration(seconds: 20));

        try { await getThemedStory(s, iucn,'future'); } catch (_) {}
        done++; onProgress?.call(done, total);
        await Future.delayed(const Duration(seconds: 20));
      }
    }

  Future<Map<String, dynamic>?> _callGemini(String prompt, {int retries = 2}) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final res = await http
            .post(
              Uri.parse(_geminiUrl),
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': _geminiKey},
              body: json.encode({
                'contents': [{'parts': [{'text': prompt}]}],
                'generationConfig': {
                  'temperature': 0.75,
                  'maxOutputTokens': 3072,
                  'responseMimeType': 'application/json',
                },
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (res.statusCode == 200) {
          final raw = (json.decode(res.body)['candidates']?[0]?['content']
                  ?['parts']?[0]?['text'] as String? ?? '');
          final cleaned = _sanitizeJsonText(
            raw.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim(),
          );
          return json.decode(cleaned) as Map<String, dynamic>;
        }

        print('Gemini returned ${res.statusCode}: ${res.body}');
        // 503 (overloaded) and 429 (rate limited) are worth retrying; other
        // errors (403, 404, bad request) won't fix themselves by retrying.
        if (res.statusCode != 503 && res.statusCode != 429) return null;
      } catch (e) {
        print('Gemini call attempt ${attempt + 1} failed: $e');
      }

      if (attempt < retries) {
        await Future.delayed(Duration(seconds: 3 * (attempt + 1))); // 3s, then 6s
      }
    }
    return null;
  }

  Future<SpeciesStory> generateThemedStory(
    Species s,
    Map<String, String> iucn, {
    required String mode, // 'history' or 'future'
  }) async {
    try {
      final parsed = await _callGemini(_themedPrompt(s, iucn, mode));
      if (parsed != null) {
        return SpeciesStory(
          narrative: parsed['narrative'] as String? ?? _fallbackThemed(s, iucn, mode),
          ttsScript: parsed['tts_script'] as String? ?? _fallbackTts(s),
          iucnFields: iucn,
          highlights: (parsed['highlights'] as List?)
              ?.map((item) => Map<String, String>.from(item))
              .toList(),
          trend: (parsed['trend'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
      }
    } catch (e) {
      print('Gemini call FAILED, using fallback: $e');
      // fall through to fallback
    }
    throw Exception('gemini_failed');
    // return SpeciesStory(
    //   narrative: _fallbackThemed(s, iucn, mode),
    //   ttsScript: _fallbackTts(s),
    //   iucnFields: iucn,
    // );
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

      Return JSON with exactly four keys, only using single quotes for HTML attributes, never double quotes:
      "narrative": HTML (no html/body/head tags), max 140 words, <p> tags,
        bold the species name, emotional but factual tone about the decline.
      "tts_script": Plain text, max 70 words, spoken narration about the decline.
      "highlights": An array of 3-5 short bullet points (max 12 words each) summarizing
        the key facts. Each item is an object: {"text": "...", "type": "threat"|"action"|"fact"|"hope"}.
        Use "threat" for dangers, "action" for conservation steps, "fact" for
        neutral info (habitat, population), "hope" for positive/hopeful notes.
      "trend": An array of exactly 4 objects representing rough relative population/range
        size over time, oldest first: {"label": "Decades ago"|"Recent past"|"Today"|"Projected future",
        "relative_size": 1-5, where 5 is largest}. This is an AI estimate, not verified data.
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

      Return JSON with exactly four keys, only using single quotes for HTML attributes, never double quotes:
      "narrative": HTML (no html/body/head tags), max 140 words, <p> tags,
        bold the species name, end on a hopeful, actionable note.
      "tts_script": Plain text, max 70 words, ending with a call to action.
      "highlights": An array of 3-5 short bullet points (max 12 words each) summarizing
        the key facts. Each item is an object: {"text": "...", "type": "threat"|"action"|"fact"|"hope"}.
      "trend": An array of exactly 4 objects representing rough relative population/range
        size over time, oldest first: {"label": "Decades ago"|"Recent past"|"Today"|"Projected future",
        "relative_size": 1-5, where 5 is largest}. This is an AI estimate, not verified data.
        Use "threat" for dangers, "action" for conservation steps, "fact" for
        neutral info (habitat, population), "hope" for positive/hopeful notes.
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

  // Gemini story generation for general species (not a specific story)
  Future<SpeciesStory> generateStory(
      Species s, Map<String, String> iucn) async {
    try {
      final parsed = await _callGemini(_prompt(s, iucn));
      if (parsed != null) {
        return SpeciesStory(
          narrative:  parsed['narrative']  as String? ?? _fallbackHtml(s, iucn),
          ttsScript:  parsed['tts_script'] as String? ?? _fallbackTts(s),
          iucnFields: iucn,
          highlights: (parsed['highlights'] as List?)
              ?.map((item) => Map<String, String>.from(item))
              .toList(), 
        );
      }
    } catch (e) {
      print('Gemini call FAILED, using fallback: $e');
      // Gemini unavailable — use fallback
    }
    throw Exception('gemini_failed');
    // return SpeciesStory(
    //   narrative:  _fallbackHtml(s, iucn),
    //   ttsScript:  _fallbackTts(s),
    //   iucnFields: iucn,
    // );
  }

  Future<SpeciesStory> getStory(Species s, Map<String, String> iucn) async {
    try {
      return await _cached('${s.internalTaxonId}_initial_v3', () => generateStory(s, iucn));
    } catch (_) {
      // Never cached — just shown to whoever's looking right now.
      return SpeciesStory(narrative: _fallbackHtml(s, iucn), ttsScript: _fallbackTts(s), iucnFields: iucn);
    }
  }

  Future<SpeciesStory> getThemedStory(Species s, Map<String, String> iucn, String mode) async {
    try {
      return await _cached('${s.internalTaxonId}_${mode}_v3', () => generateThemedStory(s, iucn, mode: mode));
    } catch (_) {
      return SpeciesStory(narrative: _fallbackThemed(s, iucn, mode), ttsScript: _fallbackTts(s), iucnFields: iucn);
    }
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

Return a JSON object with exactly three keys:

"narrative": HTML content (no html/body/head tags) for a large display screen.
  Max 160 words. Use <p> tags. Bold the species name. Show status in
  ${s.category == 'CR' ? '#CC0000' : '#E53935'} colour using single-quotes HTML attributes, e.g. <span style='color:#CC0000;font-weight:bold;'>. Never use
  double quotes inside the HTML — only single quotes for attributes, since
  this HTML sits inside a JSON string value. Emotional and educational tone.
  Only use facts from the data above.

"tts_script": Plain text (no HTML). Max 70 words. Spoken aloud by a narrator.
  Start with the species name. Only use facts from the data above.
  End with a conservation call to action.
"highlights": An array of 3-5 short bullet points (max 12 words each) summarizing
  the key facts. Each item is an object: {"text": "...", "type": "threat"|"action"|"fact"|"hope"}.
  Use "threat" for dangers, "action" for conservation steps, "fact" for
  neutral info (habitat, population), "hope" for positive/hopeful notes.

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

   Future<SpeciesStory> _cached(String key, Future<SpeciesStory> Function() generate) async {
    final box = Hive.box('species_stories');
    final cached = box.get(key);
    if (cached != null) {
      final map = Map<String, dynamic>.from(cached);
      return SpeciesStory(
        narrative: map['narrative'],
        ttsScript: map['ttsScript'],
        iucnFields: Map<String, String>.from(map['iucnFields']),
        highlights: (map['highlights'] as List?)
            ?.map((item) => Map<String, String>.from(item))
            .toList(),
      );
    }

    try {
      final story = await generate();
      await box.put(key, {
        'narrative': story.narrative,
        'ttsScript': story.ttsScript,
        'iucnFields': story.iucnFields,
        'highlights': story.highlights,
      });
      return story;
    } catch (e) {
      print('Error generating story for $key: $e');
      rethrow;
    }
  }

  Future<String> exportCacheAsJson() async {
    final box = Hive.box('species_stories');
    final Map<String, dynamic> allEntries = {};
    for (final key in box.keys) {
      allEntries[key.toString()] = box.get(key);
    }
    return json.encode(allEntries);
  }

  Future<String> exportCacheToFile() async {
    final box = Hive.box('species_stories');
    final Map<String, dynamic> allEntries = {};
    for (final key in box.keys) {
      allEntries[key.toString()] = box.get(key);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/species_stories_seed.json');
    await file.writeAsString(json.encode(allEntries));
    return file.path; // print/show this so you know where it landed
  }
}
