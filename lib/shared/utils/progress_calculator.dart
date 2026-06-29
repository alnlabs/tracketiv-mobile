class ProgressCalculator {
  static double? percent({
    required double? startValue,
    required double? currentValue,
    required double? targetValue,
  }) {
    if (startValue == null || currentValue == null || targetValue == null) return null;
    final total = (startValue - targetValue).abs();
    if (total == 0) return 100;
    final progress = (startValue - currentValue).abs();
    return (progress / total * 100).clamp(0, 100);
  }
}
