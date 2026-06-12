List<double> balancedSeatArcFractions({
  required int seatCount,
  required int heroIndex,
}) {
  if (seatCount <= 0) return const <double>[];

  final int normalizedHero =
      (heroIndex >= 0 && heroIndex < seatCount) ? heroIndex : 0;
  final List<int> signedOffsets =
      List<int>.generate(seatCount, (int seatIndex) {
    if (seatIndex == normalizedHero) return 0;

    final int forward = (seatIndex - normalizedHero + seatCount) % seatCount;
    final int backward = (normalizedHero - seatIndex + seatCount) % seatCount;

    // When a seat is exactly opposite the hero on even-sized tables, keep the
    // extra seat on the positive side so the hero remains visually centered.
    if (forward <= backward) return forward;
    return -backward;
  }, growable: false);

  int positiveCount = 0;
  int negativeCount = 0;
  for (final int offset in signedOffsets) {
    if (offset > positiveCount) positiveCount = offset;
    if (-offset > negativeCount) negativeCount = -offset;
  }

  return List<double>.generate(seatCount, (int seatIndex) {
    final int offset = signedOffsets[seatIndex];
    if (offset == 0) return 0.5;
    if (offset > 0) {
      return 0.5 + (0.5 * offset / positiveCount);
    }
    return 0.5 - (0.5 * (-offset) / negativeCount);
  }, growable: false);
}
