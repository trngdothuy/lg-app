import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen_one.dart';
import 'providers/theme_provider.dart';

Future<void> seedCacheIfEmpty() async {
  final box = Hive.box('species_stories');
  if (box.isNotEmpty) return; // already populated, don't overwrite

  try {
    final jsonStr = await rootBundle.loadString('assets/species_stories_seed.json');
    final Map<String, dynamic> seed = json.decode(jsonStr);
    for (final entry in seed.entries) {
      await box.put(entry.key, Map<String, dynamic>.from(entry.value));
    }
    print('Seeded ${seed.length} cached stories from bundled asset.');
  } catch (e) {
    print('No seed file found or failed to load — starting with empty cache: $e');
  }
}

void main() async {
  await dotenv.load(fileName: ".env"); // Load environment variables from .env file
  await Hive.initFlutter();
  await Hive.openBox('species_stories');
  await seedCacheIfEmpty(); // Seed the cache if it's empty
  // await Hive.box('species_stories').clear(); // Clear the box on app start

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Red List Endangered Species Living Atlas App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: themeProvider.isDark ? Brightness.dark : Brightness.light,),
        useMaterial3: true,
      ),
      home: const SplashScreenOne(),
    );
  }
}