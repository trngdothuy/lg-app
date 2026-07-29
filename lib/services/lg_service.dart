import 'package:dartssh2/dartssh2.dart';

// import '../data/species_data.dart';
import '../models/species.dart';
import '../services/species_service.dart';

class LGService {
  final SSHClient client;
  final String host;
  final int screens;

  LGService({
    required this.client,
    required this.host,
    required this.screens,
  });

  Future<void> initialize(List<Species> species) async {
    // Upload initial KML if needed
  }

  Future<void> flyTo({
    required double lat,
    required double lng,
    double range = 500000,
    double tilt = 0,
    double heading = 0,
    int duration = 0,
  }) async {
    // TODO
  }

  Future<void> showSpecies(
    Species species,
    SpeciesStory story,
  ) async {
    // TODO
  }

  Future<void> showHistory(
    Species species,
    SpeciesStory story,
  ) async {
    // TODO
  }

  Future<void> showFuture(
    Species species,
    SpeciesStory story,
  ) async {
    // TODO
  }
}