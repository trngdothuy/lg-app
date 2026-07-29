// Species class only

class Species {
  final int assessmentId;
  final int internalTaxonId;
  final String scientificName;
  final String commonName;
  final String category;   // 'CR' | 'EN'
  final String group;      // MAMMALIA | AVES | REPTILIA | PISCES | PLANTAE | ARTHROPODA
  final double lat;
  final double lng;
  final String habitat;
  final String threats;

  const Species({
    required this.assessmentId,
    required this.internalTaxonId,
    required this.scientificName,
    required this.commonName,
    required this.category,
    required this.group,
    required this.lat,
    required this.lng,
    required this.habitat,
    required this.threats,
  });

  String get id => internalTaxonId.toString();

  String get iucnUrl =>
      'https://www.iucnredlist.org/species/$internalTaxonId/$assessmentId';
}
