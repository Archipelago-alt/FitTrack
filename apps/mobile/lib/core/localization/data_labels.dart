import 'app_localizations.dart';

/// Localised labels for values that arrive as data rather than as UI copy.
///
/// Measurement types, chart series keys and units are stable identifiers
/// (`left_thigh`, `body_weight`, `kcal`). Title-casing or printing them raw
/// leaves English on the screen in every language, so each one gets a real
/// translation and anything unrecognised falls back to a readable form of
/// itself rather than a raw key.
extension DataLabels on AppLocalizations {
  /// A body measurement type, e.g. `left_thigh`.
  String measurement(String type) => _lookup(type, _measurements);

  /// A chart series, keyed by the series' stable `key`. [fallback] is the
  /// label the series carried, used when the key is one we don't know.
  String series(String key, [String? fallback]) {
    final String? arbKey = _series[key];
    if (arbKey != null) return t(arbKey);
    final String? measured = _measurements[key];
    if (measured != null) return t(measured);
    return (fallback?.isNotEmpty ?? false) ? fallback! : _humanise(key);
  }

  /// A unit as it appears beside a number, e.g. `kg`, `sessions`.
  String unit(String? unit) {
    if (unit == null || unit.isEmpty) return '';
    final String? arbKey = _units[unit.toLowerCase()];
    return arbKey != null ? t(arbKey) : unit;
  }

  /// "4 × 6-10", "3 × 45s" for timed work, "3 sets" when no rep target is set.
  ///
  /// The numerals stay as they are — the words around them are what changes
  /// between languages.
  String prescription({
    required int sets,
    int? repsMin,
    int? repsMax,
    int? durationSeconds,
  }) {
    if (durationSeconds != null) {
      final String seconds =
          t('prescriptionSeconds', <String, Object?>{'count': durationSeconds});
      return '$sets × $seconds';
    }
    if (repsMin == null && repsMax == null) {
      return t('prescriptionSets', <String, Object?>{'count': sets});
    }
    if (repsMin != null && repsMax != null && repsMin != repsMax) {
      return '$sets × $repsMin-$repsMax';
    }
    return '$sets × ${repsMax ?? repsMin}';
  }

  String _lookup(String value, Map<String, String> keys) {
    final String? arbKey = keys[value];
    return arbKey != null ? t(arbKey) : _humanise(value);
  }

  static String _humanise(String value) => value
      .split('_')
      .map((String part) =>
          part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
      .join(' ');

  static const Map<String, String> _measurements = <String, String>{
    'waist': 'measureWaist',
    'chest': 'measureChest',
    'hips': 'measureHips',
    'neck': 'measureNeck',
    'shoulders': 'measureShoulders',
    'left_arm': 'measureLeftArm',
    'right_arm': 'measureRightArm',
    'left_thigh': 'measureLeftThigh',
    'right_thigh': 'measureRightThigh',
    'left_calf': 'measureLeftCalf',
    'right_calf': 'measureRightCalf',
    'body_fat': 'measureBodyFat',
  };

  static const Map<String, String> _series = <String, String>{
    'body_weight': 'seriesBodyWeight',
    'weight': 'seriesBodyWeight',
    'volume': 'seriesVolume',
    'frequency': 'seriesWorkouts',
    'workouts': 'seriesWorkouts',
    'calories': 'nutritionCalories',
    'protein': 'nutritionProtein',
    'carbs': 'nutritionCarbs',
    'fat': 'nutritionFat',
    'fiber': 'seriesFiber',
    'water': 'nutritionWater',
  };

  static const Map<String, String> _units = <String, String>{
    'kg': 'commonKg',
    'lb': 'unitLb',
    'lbs': 'unitLb',
    'cm': 'unitCm',
    'in': 'unitIn',
    'kcal': 'unitKcal',
    'g': 'unitG',
    'ml': 'unitMl',
    'sessions': 'unitSessions',
    'workouts': 'unitWorkouts',
    'reps': 'unitReps',
    'min': 'unitMinutes',
    'minutes': 'unitMinutes',
    'days': 'unitDays',
    'steps': 'unitSteps',
    '%': 'unitPercent',
  };
}
