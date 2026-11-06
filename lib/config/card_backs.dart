/// Bundled card-back image assets.
///
/// One per game, picked at random. Only the classic engraved backs in the
/// two brand colours, red and blue (docs/ART_DIRECTION.md): the animal
/// prints (zebra 01, giraffe 08, leopard 11), the paint splash (19) and the
/// green and black backs stay in assets/images/cards but are not dealt.
const List<String> kCardBackAssets = <String>[
  'assets/images/cards/back_custom_07.webp',
  'assets/images/cards/back_custom_12.webp',
  'assets/images/cards/back_custom_13.webp',
  'assets/images/cards/back_custom_16.webp',
  'assets/images/cards/back_custom_09.webp',
  'assets/images/cards/back_custom_15.webp',
  'assets/images/cards/back_custom_17.webp',
  'assets/images/cards/back_custom_20.webp',
];

/// Fallback card back asset (must exist in `pubspec.yaml` assets).
const String kFallbackCardBackAsset = 'assets/images/cards/back_custom_07.webp';
