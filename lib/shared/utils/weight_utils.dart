class WeightUtils {
  static const lbsPerKg = 2.2046226218;

  static double kgToDisplay(double kg, String unit) {
    return unit == 'lbs' ? kg * lbsPerKg : kg;
  }

  static double displayToKg(double value, String unit) {
    return unit == 'lbs' ? value / lbsPerKg : value;
  }

  static String unitLabel(String unit) => unit == 'lbs' ? 'lbs' : 'kg';
}
