class BunkMath {
  final int attended;
  final int total;
  final double currentPct;
  final int S;
  final int bunksLeft;
  final int xMax;
  final int classesToGain1Bunk;

  const BunkMath({
    required this.attended,
    required this.total,
    required this.currentPct,
    required this.S,
    required this.bunksLeft,
    required this.xMax,
    required this.classesToGain1Bunk,
  });

  static BunkMath compute({required int attended, required int total}) {
    final A = attended;
    final T = total;

    double pct = (T == 0) ? 0.0 : (A / T) * 100;

    final S = 4 * A - 3 * T;

    int bunks = (S / 3).floor();
    bunks = bunks < 0 ? 0 : bunks;

    int xMax = ((A / 0.75) - T).floor();
    xMax = xMax < 0 ? 0 : xMax;

    final base = (S / 3).floor();
    final targetS = 3 * (base + 1);
    final minTargetS = S >= 0 ? targetS : 3;

    int classesToGain = minTargetS - S;
    if (classesToGain < 0) classesToGain = 0;

    return BunkMath(
      attended: A,
      total: T,
      currentPct: pct,
      S: S,
      bunksLeft: bunks,
      xMax: xMax,
      classesToGain1Bunk: classesToGain,
    );
  }

  bool get isCloseTo75 =>
      (currentPct >= 75 && currentPct < 77) || (S >= 0 && S <= 2);
}
