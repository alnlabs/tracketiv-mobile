class MetricFormConfig {
  const MetricFormConfig({
    required this.showStartValue,
    required this.showTargetValue,
    required this.showTargetDate,
    required this.targetRequired,
    required this.targetLabel,
    required this.logValueLabel,
    this.startLabel,
    this.startHint,
    this.targetHint,
    this.logValueHint,
  });

  final bool showStartValue;
  final bool showTargetValue;
  final bool showTargetDate;
  final bool targetRequired;
  final String? startLabel;
  final String targetLabel;
  final String logValueLabel;
  final String? startHint;
  final String? targetHint;
  final String? logValueHint;
}

class MetricUtils {
  static String formatUnit(String? unit) {
    switch (unit) {
      case 'kg':
        return 'kg';
      case 'lbs':
        return 'lbs';
      case 'steps':
        return 'steps';
      case 'glasses':
        return 'glasses';
      case 'minutes':
        return 'minutes';
      case 'hours':
        return 'hours';
      case 'seconds':
        return 'seconds';
      case 'km':
        return 'km';
      case 'reps':
        return 'reps';
      case 'sessions':
        return 'sessions';
      case 'doses':
        return 'doses';
      case 'kcal':
        return 'kcal';
      case 'usd':
        return 'USD';
      case 'days':
        return 'days';
      case 'entries':
        return 'entries';
      case 'tasks':
        return 'tasks';
      case 'times':
        return 'times';
      case 'g':
        return 'grams';
      default:
        return unit ?? '';
    }
  }

  static String _periodLabel(String cadence) {
    switch (cadence) {
      case 'weekly':
        return 'week';
      case 'monthly':
        return 'month';
      default:
        return 'day';
    }
  }

  static MetricFormConfig config(
    String metricType,
    String? metricUnit, {
    String cadence = 'daily',
  }) {
    final unit = formatUnit(metricUnit);
    final period = _periodLabel(cadence);
    final unitInParens = unit.isNotEmpty ? ' ($unit)' : '';

    switch (metricType) {
      case 'weight':
        return MetricFormConfig(
          showStartValue: true,
          showTargetValue: true,
          showTargetDate: true,
          targetRequired: true,
          startLabel: 'Starting weight$unitInParens',
          targetLabel: 'Target weight$unitInParens',
          logValueLabel: "Today's weight$unitInParens",
          startHint: 'Your current weight',
          targetHint: 'Weight you want to reach',
          logValueHint: 'e.g. 82.5',
        );
      case 'steps':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: true,
          targetLabel: 'Daily step goal',
          logValueLabel: 'Steps today',
          targetHint: 'e.g. 10000',
          logValueHint: 'e.g. 8500',
        );
      case 'distance':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: true,
          targetLabel: '$period distance goal$unitInParens',
          logValueLabel: 'Distance logged$unitInParens',
          targetHint: 'e.g. 5',
          logValueHint: 'e.g. 3.2',
        );
      case 'volume':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: true,
          targetLabel: 'Daily intake goal$unitInParens',
          logValueLabel: 'Amount today$unitInParens',
          targetHint: unit == 'glasses' ? 'e.g. 8' : null,
          logValueHint: 'How much you had today',
        );
      case 'duration':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: true,
          targetLabel: '$period goal$unitInParens',
          logValueLabel: 'Time spent$unitInParens',
          targetHint: unit == 'minutes' ? 'e.g. 30' : unit == 'hours' ? 'e.g. 8' : 'e.g. 60',
          logValueHint: 'How long you did it',
        );
      case 'currency':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: true,
          targetRequired: true,
          targetLabel: 'Monthly savings target ($unit)',
          logValueLabel: 'Amount saved ($unit)',
          targetHint: 'e.g. 500',
          logValueHint: 'e.g. 200',
        );
      case 'count':
        return _countConfig(unit, metricUnit, period, unitInParens);
      default:
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: false,
          targetLabel: 'Target$unitInParens',
          logValueLabel: 'Value$unitInParens',
        );
    }
  }

  static MetricFormConfig _countConfig(
    String unit,
    String? rawUnit,
    String period,
    String unitInParens,
  ) {
    switch (rawUnit) {
      case 'days':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: false,
          showTargetDate: false,
          targetRequired: false,
          targetLabel: 'Daily habit',
          logValueLabel: 'Done today?',
          logValueHint: 'Enter 1 if completed',
        );
      case 'doses':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: false,
          targetLabel: 'Doses per $period',
          logValueLabel: 'Doses taken',
          targetHint: 'Usually 1',
          logValueHint: 'e.g. 1',
        );
      case 'entries':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: false,
          targetLabel: 'Entries per $period',
          logValueLabel: 'Entries logged',
          targetHint: 'e.g. 1',
          logValueHint: 'e.g. 1',
        );
      case 'sessions':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: true,
          targetLabel: 'Sessions per $period',
          logValueLabel: 'Sessions completed',
          targetHint: 'e.g. 3',
          logValueHint: 'e.g. 1',
        );
      case 'reps':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: true,
          targetLabel: 'Reps per $period',
          logValueLabel: 'Reps completed',
          targetHint: 'e.g. 50',
          logValueHint: 'e.g. 25',
        );
      case 'tasks':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: true,
          targetLabel: 'Tasks per $period',
          logValueLabel: 'Tasks done',
          targetHint: 'e.g. 5',
          logValueHint: 'e.g. 2',
        );
      case 'times':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: false,
          targetLabel: 'Times per $period',
          logValueLabel: 'Times completed',
          targetHint: 'e.g. 1',
          logValueHint: 'e.g. 1',
        );
      case 'kcal':
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: true,
          targetLabel: 'Daily calorie target',
          logValueLabel: 'Calories today',
          targetHint: 'e.g. 2000',
          logValueHint: 'e.g. 1850',
        );
      default:
        return MetricFormConfig(
          showStartValue: false,
          showTargetValue: true,
          showTargetDate: false,
          targetRequired: false,
          targetLabel: 'Target per $period$unitInParens',
          logValueLabel: 'Amount$unitInParens',
        );
    }
  }

  static String progressLabel(String metricType, String? metricUnit) {
    return config(metricType, metricUnit).logValueLabel;
  }

  /// Whether logging a lower number means progress (e.g. weight loss).
  static bool isLowerBetter(String? metricType, {String? metricUnit}) {
    final type = metricType?.trim().toLowerCase();
    if (type == 'weight') return true;

    switch (metricUnit) {
      case 'kg':
      case 'lbs':
        return true;
      default:
        return false;
    }
  }
}
