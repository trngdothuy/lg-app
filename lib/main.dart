import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/splash_screen_one.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Red List Endangered Species Living Atlas App',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreenOne(),
    );
  }
}








// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: Text(widget.title),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: .center,
//           children: [
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
