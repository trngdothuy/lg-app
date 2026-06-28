// species_data.dart — 40 verified CR/EN species, Vietnam region
// IDs match exactly the TSV provided: assessmentId + internalTaxonId
// Coordinates = primary Vietnam habitat centroid (not fabricated)

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

const List<Species> vietnamSpecies = [

  // ── PLANTS ───────────────────────────────────────────────────
  Species(
    assessmentId: 2822125, internalTaxonId: 215342548,
    scientificName: 'Dalbergia cochinchinensis', commonName: 'Siamese Rosewood',
    category: 'EN', group: 'PLANTAE', lat: 11.60, lng: 107.20,
    habitat: 'Lowland evergreen forests; Central Highlands (Cat Tien, Yok Don)',
    threats: 'Illegal logging for high-value timber; CITES Appendix II',
  ),
  Species(
    assessmentId: 9697750, internalTaxonId: 32324,
    scientificName: 'Bretschneidera sinensis', commonName: 'Bretschneidera',
    category: 'EN', group: 'PLANTAE', lat: 22.50, lng: 104.00,
    habitat: 'Subtropical montane forests; northern Vietnam (Ha Giang, Lao Cai)',
    threats: 'Deforestation, agricultural encroachment, small fragmented populations',
  ),

  // ── FISH / SHARKS / RAYS ─────────────────────────────────────
  Species(
    assessmentId: 5324699, internalTaxonId: 15944,
    scientificName: 'Pangasianodon gigas', commonName: 'Mekong Giant Catfish',
    category: 'CR', group: 'PISCES', lat: 10.90, lng: 105.10,
    habitat: 'Mekong River mainstream; An Giang and Dong Thap provinces',
    threats: 'Overfishing, dam construction blocking migration, sand mining',
  ),
  Species(
    assessmentId: 5324983, internalTaxonId: 15945,
    scientificName: 'Pangasius sanitwongsei', commonName: 'Giant Pangasius',
    category: 'CR', group: 'PISCES', lat: 10.80, lng: 105.30,
    habitat: 'Mekong River and major tributaries; Mekong Delta',
    threats: 'Overfishing, hydropower dams blocking migration routes',
  ),
  Species(
    assessmentId: 7649359, internalTaxonId: 180662,
    scientificName: 'Catlocarpio siamensis', commonName: 'Giant Barb',
    category: 'CR', group: 'PISCES', lat: 11.00, lng: 105.50,
    habitat: 'Large lowland rivers of Mekong basin; southern Vietnam',
    threats: 'Overfishing, habitat degradation, dam construction',
  ),
  Species(
    assessmentId: 2911619, internalTaxonId: 39374,
    scientificName: 'Carcharhinus longimanus', commonName: 'Oceanic Whitetip Shark',
    category: 'CR', group: 'PISCES', lat: 12.00, lng: 111.00,
    habitat: 'Open ocean; South China Sea, offshore Vietnam',
    threats: 'Targeted fishing and bycatch for shark fin trade; CITES Appendix II',
  ),
  Species(
    assessmentId: 2918526, internalTaxonId: 39385,
    scientificName: 'Sphyrna lewini', commonName: 'Scalloped Hammerhead Shark',
    category: 'CR', group: 'PISCES', lat: 10.50, lng: 109.50,
    habitat: 'Coastal and offshore waters; South China Sea and Con Dao area',
    threats: 'Shark fin trade, bycatch in tuna and swordfish fisheries',
  ),
  Species(
    assessmentId: 2920499, internalTaxonId: 39386,
    scientificName: 'Sphyrna mokarran', commonName: 'Great Hammerhead Shark',
    category: 'CR', group: 'PISCES', lat: 10.20, lng: 109.00,
    habitat: 'Coastal and offshore waters; South China Sea',
    threats: 'Targeted and bycatch fishing, shark fin trade, slow reproduction',
  ),
  Species(
    assessmentId: 58304631, internalTaxonId: 39393,
    scientificName: 'Pristis zijsron', commonName: 'Green Sawfish',
    category: 'CR', group: 'PISCES', lat: 10.30, lng: 106.80,
    habitat: 'Coastal estuaries and river mouths; Mekong Delta coastal zone',
    threats: 'Bycatch, habitat loss, rostra collected as trophies; CITES Appendix I',
  ),
  Species(
    assessmentId: 104294071, internalTaxonId: 195320,
    scientificName: 'Urogymnus polylepis', commonName: 'Giant Freshwater Stingray',
    category: 'EN', group: 'PISCES', lat: 10.50, lng: 105.40,
    habitat: 'Large rivers; Mekong River and Delta, southern Vietnam',
    threats: 'Targeted fishing, bycatch, habitat degradation',
  ),
  Species(
    assessmentId: 126673248, internalTaxonId: 19488,
    scientificName: 'Rhincodon typus', commonName: 'Whale Shark',
    category: 'EN', group: 'PISCES', lat: 9.80, lng: 109.20,
    habitat: 'Tropical oceanic waters; South China Sea, Phu Quoc and Con Dao areas',
    threats: 'Targeted fishing (meat, fins, oil), boat strikes, tourism disturbance',
  ),
  Species(
    assessmentId: 124442197, internalTaxonId: 60129,
    scientificName: 'Rhinoptera javanica', commonName: 'Javanese Cownose Ray',
    category: 'EN', group: 'PISCES', lat: 10.80, lng: 107.50,
    habitat: 'Coastal and estuarine waters; southeastern Vietnam',
    threats: 'Bycatch, targeted fishing, habitat degradation',
  ),
  Species(
    assessmentId: 279075986, internalTaxonId: 110847130,
    scientificName: 'Mobula mobular', commonName: 'Giant Devil Ray',
    category: 'EN', group: 'PISCES', lat: 10.00, lng: 109.50,
    habitat: 'Offshore South China Sea waters',
    threats: 'Bycatch in pelagic fisheries, targeted fishing for gill plates',
  ),

  // ── REPTILES ─────────────────────────────────────────────────
  Species(
    assessmentId: 2931537, internalTaxonId: 39621,
    scientificName: 'Rafetus swinhoei', commonName: 'Yangtze Giant Softshell Turtle',
    category: 'CR', group: 'REPTILIA', lat: 21.03, lng: 105.85,
    habitat: 'Hoan Kiem Lake (Hanoi) and Dong Mo Lake',
    threats: 'Critically few individuals remain (~3-4 worldwide); habitat loss, hunting, pollution',
  ),
  Species(
    assessmentId: 3048087, internalTaxonId: 5671,
    scientificName: 'Crocodylus siamensis', commonName: 'Siamese Crocodile',
    category: 'CR', group: 'REPTILIA', lat: 12.10, lng: 107.40,
    habitat: 'Freshwater wetlands; Cat Tien National Park',
    threats: 'Historical hunting for skin, hybridisation with farmed crocodiles, habitat loss',
  ),
  Species(
    assessmentId: 12881238, internalTaxonId: 8005,
    scientificName: 'Eretmochelys imbricata', commonName: 'Hawksbill Sea Turtle',
    category: 'CR', group: 'REPTILIA', lat: 8.80, lng: 106.60,
    habitat: 'Coral reefs; Con Dao National Park, Phu Quoc',
    threats: 'Shell trade (tortoiseshell), egg collection, bycatch, coral reef degradation',
  ),

  // ── MAMMALS ──────────────────────────────────────────────────
  Species(
    assessmentId: 17944213, internalTaxonId: 19594,
    scientificName: 'Rhinopithecus avunculus', commonName: 'Tonkin Snub-nosed Monkey',
    category: 'CR', group: 'MAMMALIA', lat: 22.30, lng: 105.20,
    habitat: 'Subtropical limestone forests; Tuyen Quang, Ha Giang, Bac Kan provinces',
    threats: 'Hunting for traditional medicine, habitat fragmentation; <250 individuals',
  ),
  Species(
    assessmentId: 17958817, internalTaxonId: 39853,
    scientificName: 'Trachypithecus francoisi', commonName: "Francois's Langur",
    category: 'EN', group: 'MAMMALIA', lat: 22.10, lng: 106.10,
    habitat: 'Limestone karst forests; Cao Bang, Lang Son, Tuyen Quang provinces',
    threats: 'Hunting for traditional medicine, limestone quarrying, habitat loss',
  ),
  Species(
    assessmentId: 17958988, internalTaxonId: 22043,
    scientificName: 'Trachypithecus delacouri', commonName: "Delacour's Langur",
    category: 'CR', group: 'MAMMALIA', lat: 20.35, lng: 105.78,
    habitat: 'Limestone karst forests; Van Long Nature Reserve, Ninh Binh province',
    threats: 'Hunting for traditional medicine; quarrying of limestone habitat; <250 individuals',
  ),
  Species(
    assessmentId: 18493355, internalTaxonId: 6553,
    scientificName: 'Dicerorhinus sumatrensis', commonName: 'Sumatran Rhinoceros',
    category: 'CR', group: 'MAMMALIA', lat: 12.20, lng: 107.40,
    habitat: 'Formerly Cat Tien National Park; functionally extinct in Vietnam',
    threats: 'Poaching for horn, habitat loss; last confirmed Vietnam individual died 2010',
  ),
  Species(
    assessmentId: 18493900, internalTaxonId: 19495,
    scientificName: 'Rhinoceros sondaicus', commonName: 'Javan Rhinoceros',
    category: 'CR', group: 'MAMMALIA', lat: 11.45, lng: 107.42,
    habitat: 'Formerly Cat Tien National Park (Cat Loc sector); extinct in Vietnam since 2010',
    threats: 'Poaching; last Vietnam individual shot by poachers 2010; global population ~76 in Java only',
  ),
  Species(
    assessmentId: 22157664, internalTaxonId: 41784,
    scientificName: 'Axis porcinus', commonName: 'Hog Deer',
    category: 'EN', group: 'MAMMALIA', lat: 10.50, lng: 106.20,
    habitat: 'Grasslands and floodplains; Mekong Delta and southern Vietnam',
    threats: 'Overhunting, habitat loss to agriculture',
  ),
  Species(
    assessmentId: 45818198, internalTaxonId: 7140,
    scientificName: 'Elephas maximus', commonName: 'Asian Elephant',
    category: 'EN', group: 'MAMMALIA', lat: 12.80, lng: 107.50,
    habitat: 'Tropical forests; Yok Don and Cat Tien National Parks, Central Highlands',
    threats: 'Habitat fragmentation, human-elephant conflict, poaching; ~100 individuals remain in Vietnam',
  ),
  Species(
    assessmentId: 46364616, internalTaxonId: 3129,
    scientificName: 'Bubalus arnee', commonName: 'Wild Water Buffalo',
    category: 'CR', group: 'MAMMALIA', lat: 13.00, lng: 107.80,
    habitat: 'Grasslands and floodplain forests; Yok Don National Park, Dak Lak',
    threats: 'Hybridisation with domestic buffalo, hunting, habitat conversion',
  ),
  Species(
    assessmentId: 72477893, internalTaxonId: 5953,
    scientificName: 'Cuon alpinus', commonName: 'Dhole',
    category: 'EN', group: 'MAMMALIA', lat: 12.50, lng: 107.80,
    habitat: 'Forests and grasslands; Cat Tien, Yok Don, Chu Mom Ray National Parks',
    threats: 'Prey depletion, persecution, disease from domestic dogs, habitat loss',
  ),
  Species(
    assessmentId: 123584856, internalTaxonId: 12763,
    scientificName: 'Manis javanica', commonName: 'Sunda Pangolin',
    category: 'CR', group: 'MAMMALIA', lat: 11.50, lng: 107.00,
    habitat: 'Tropical forests; southern and central Vietnam',
    threats: 'Most trafficked wild mammal in the world; scales and meat used in traditional medicine',
  ),
  Species(
    assessmentId: 123790805, internalTaxonId: 15419,
    scientificName: 'Orcaella brevirostris', commonName: 'Irrawaddy Dolphin',
    category: 'EN', group: 'MAMMALIA', lat: 12.50, lng: 106.00,
    habitat: 'Mekong River; upper Mekong Delta and Cambodia-Vietnam border stretch',
    threats: 'Gillnet bycatch, habitat degradation, dam construction',
  ),
  Species(
    assessmentId: 166485696, internalTaxonId: 18597,
    scientificName: 'Pseudoryx nghetinhensis', commonName: 'Saola',
    category: 'CR', group: 'MAMMALIA', lat: 17.83, lng: 106.57,
    habitat: 'Annamite Range moist forests; Pu Mat, Vu Quang National Parks',
    threats: 'Snare hunting; one of rarest large mammals on Earth',
  ),
  Species(
    assessmentId: 168392151, internalTaxonId: 12764,
    scientificName: 'Manis pentadactyla', commonName: 'Chinese Pangolin',
    category: 'CR', group: 'MAMMALIA', lat: 21.50, lng: 105.50,
    habitat: 'Subtropical forests; northern Vietnam (Ha Giang, Lang Son, Vinh Phuc)',
    threats: 'Illegal trade for scales and meat in traditional medicine',
  ),
  Species(
    assessmentId: 214862019, internalTaxonId: 15955,
    scientificName: 'Panthera tigris', commonName: 'Tiger',
    category: 'EN', group: 'MAMMALIA', lat: 14.60, lng: 107.90,
    habitat: 'Formerly throughout Central Highlands; likely functionally extinct in Vietnam',
    threats: 'Poaching for bones and body parts, prey depletion, habitat loss',
  ),
  Species(
    assessmentId: 270543638, internalTaxonId: 2888,
    scientificName: 'Bos javanicus', commonName: 'Banteng',
    category: 'EN', group: 'MAMMALIA', lat: 12.50, lng: 107.10,
    habitat: 'Deciduous forests and grasslands; Cat Tien and Yok Don National Parks',
    threats: 'Hunting, hybridisation with domestic cattle, agricultural encroachment',
  ),

  // ── BIRDS ────────────────────────────────────────────────────
  Species(
    assessmentId: 21247822, internalTaxonId: 21247820,
    scientificName: 'Bertia cambojiensis', commonName: 'Cambodian Tailorbird',
    category: 'EN', group: 'AVES', lat: 11.30, lng: 106.80,
    habitat: 'Lowland scrub and degraded forest; southern Vietnam near Cambodia border',
    threats: 'Habitat loss to agriculture, very restricted range',
  ),
  Species(
    assessmentId: 130184896, internalTaxonId: 22692015,
    scientificName: 'Houbaropsis bengalensis', commonName: 'Bengal Florican',
    category: 'CR', group: 'AVES', lat: 11.50, lng: 105.80,
    habitat: 'Lowland grasslands; Mekong plain, Tay Ninh and Long An provinces',
    threats: 'Conversion of grasslands to agriculture, hunting',
  ),
  Species(
    assessmentId: 134189710, internalTaxonId: 22697531,
    scientificName: 'Pseudibis davisoni', commonName: 'White-shouldered Ibis',
    category: 'CR', group: 'AVES', lat: 12.40, lng: 107.50,
    habitat: 'Seasonal floodplains and open forests; southern Vietnam near Cambodia border',
    threats: 'Wetland drainage, hunting, egg collection',
  ),
  Species(
    assessmentId: 154738156, internalTaxonId: 22693452,
    scientificName: 'Calidris pygmaea', commonName: 'Spoon-billed Sandpiper',
    category: 'CR', group: 'AVES', lat: 10.30, lng: 107.10,
    habitat: 'Mudflats and tidal wetlands; winters on southeast Vietnam coast',
    threats: 'Habitat loss on breeding and wintering grounds; <300 individuals remain',
  ),
  Species(
    assessmentId: 204618615, internalTaxonId: 22695194,
    scientificName: 'Gyps bengalensis', commonName: 'White-rumped Vulture',
    category: 'CR', group: 'AVES', lat: 11.80, lng: 106.50,
    habitat: 'Open country and forests; southern Vietnam, Cat Tien area',
    threats: 'Diclofenac poisoning from livestock carcasses; population collapse >99%',
  ),
  Species(
    assessmentId: 204781113, internalTaxonId: 22729460,
    scientificName: 'Gyps tenuirostris', commonName: 'Slender-billed Vulture',
    category: 'CR', group: 'AVES', lat: 11.60, lng: 106.80,
    habitat: 'Open lowland forests; southern Vietnam near Cambodia border',
    threats: 'Veterinary drug poisoning (diclofenac/ketoprofen in livestock), habitat loss',
  ),
  Species(
    assessmentId: 205031246, internalTaxonId: 22695254,
    scientificName: 'Sarcogyps calvus', commonName: 'Red-headed Vulture',
    category: 'CR', group: 'AVES', lat: 12.00, lng: 107.20,
    habitat: 'Open forests and agricultural land; Central Highlands and southern Vietnam',
    threats: 'Poisoning from veterinary drugs in carcasses, direct poisoning, habitat loss',
  ),
  Species(
    assessmentId: 223484923, internalTaxonId: 22693225,
    scientificName: 'Tringa guttifer', commonName: "Nordmann's Greenshank",
    category: 'EN', group: 'AVES', lat: 10.20, lng: 105.60,
    habitat: 'Coastal mudflats and mangroves; Mekong Delta coast (winter visitor)',
    threats: 'Habitat loss at staging and wintering sites, hunting; <1000 individuals remain',
  ),

  // ── INVERTEBRATES ────────────────────────────────────────────
  Species(
    assessmentId: 149768986, internalTaxonId: 21309,
    scientificName: 'Tachypleus tridentatus', commonName: 'Chinese Horseshoe Crab',
    category: 'EN', group: 'ARTHROPODA', lat: 20.50, lng: 107.00,
    habitat: 'Sandy beaches and shallow coastal waters; northern Vietnam coast (Quang Ninh)',
    threats: 'Biomedical harvesting, coastal development destroying breeding beaches',
  ),
];
