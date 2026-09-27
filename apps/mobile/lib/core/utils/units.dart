import 'dart:math' as math;

/// The words that sit next to a number.
///
/// They are data rather than literals so the formatters below can stay
/// synchronous and context-free — a screen deep in a list cannot reasonably
/// pass localisations into every `Units.weight()` call. [Units.labels] is set
/// once per build from the active locale.
class UnitLabels {
  const UnitLabels({
    this.kg = 'kg',
    this.lb = 'lb',
    this.cm = 'cm',
    this.inch = 'in',
    this.km = 'km',
    this.metre = 'm',
    this.mile = 'mi',
    this.foot = 'ft',
    this.hour = 'h',
    this.minute = 'm',
  });

  final String kg;
  final String lb;
  final String cm;
  final String inch;
  final String km;
  final String metre;
  final String mile;
  final String foot;
  final String hour;
  final String minute;

  static const UnitLabels english = UnitLabels();
}

/// Unit conversion and display formatting.
///
/// Everything is stored in metric; the imperial preference is purely a
/// presentation concern, converted at the edge.
class Units {
  const Units._();

  /// The words used by every formatter here. English until the app sets it
  /// from the active locale, which keeps tests and non-UI callers working.
  static UnitLabels labels = UnitLabels.english;

  static const double kgPerLb = 0.45359237;
  static const double cmPerInch = 2.54;

  static double kgToLb(double kg) => kg / kgPerLb;

  static double lbToKg(double lb) => lb * kgPerLb;

  static double cmToInch(double cm) => cm / cmPerInch;

  static double inchToCm(double inches) => inches * cmPerInch;

  /// Weight for display, rounded to a precision that matches the unit.
  static String weight(double? kg,
      {required bool imperial, bool withUnit = true}) {
    if (kg == null) return '—';
    final double value = imperial ? kgToLb(kg) : kg;
    final String number = _trim(value, imperial ? 1 : 1);
    return withUnit ? '$number ${imperial ? labels.lb : labels.kg}' : number;
  }

  static String length(double? cm,
      {required bool imperial, bool withUnit = true}) {
    if (cm == null) return '—';
    final double value = imperial ? cmToInch(cm) : cm;
    final String number = _trim(value, 1);
    return withUnit ? '$number ${imperial ? labels.inch : labels.cm}' : number;
  }

  /// Height reads as feet and inches in imperial, where "70 in" would not.
  static String height(double? cm, {required bool imperial}) {
    if (cm == null) return '—';
    if (!imperial) return '${_trim(cm, 0)} ${labels.cm}';
    final double totalInches = cmToInch(cm);
    final int feet = totalInches ~/ 12;
    final int inches = (totalInches - feet * 12).round();
    return inches == 12 ? '${feet + 1}\' 0"' : '$feet\' $inches"';
  }

  static String distance(double? metres, {required bool imperial}) {
    if (metres == null) return '—';
    if (imperial) {
      final double miles = metres / 1609.344;
      return miles >= 0.1
          ? '${_trim(miles, 2)} ${labels.mile}'
          : '${_trim(metres * 3.28084, 0)} ${labels.foot}';
    }
    return metres >= 1000
        ? '${_trim(metres / 1000, 2)} ${labels.km}'
        : '${_trim(metres, 0)} ${labels.metre}';
  }

  /// `mm:ss`, or `h:mm:ss` once a session passes an hour.
  static String duration(int? seconds) {
    if (seconds == null) return '—';
    final int safe = math.max(0, seconds);
    final int hours = safe ~/ 3600;
    final int minutes = (safe % 3600) ~/ 60;
    final int remaining = safe % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = remaining.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// Long-form duration for summaries: "1h 12m".
  static String durationLong(int? seconds) {
    if (seconds == null || seconds <= 0) return '—';
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$minutes${labels.minute}';
    return minutes == 0
        ? '$hours${labels.hour}'
        : '$hours${labels.hour} $minutes${labels.minute}';
  }

  static String volume(double? kg, {required bool imperial}) {
    if (kg == null) return '—';
    final double value = imperial ? kgToLb(kg) : kg;
    if (value >= 1000) {
      // "k" stays as it is: a numeric shorthand rather than a word.
      return '${_trim(value / 1000, 1)}k ${imperial ? labels.lb : labels.kg}';
    }
    return '${_trim(value, 0)} ${imperial ? labels.lb : labels.kg}';
  }

  /// The smallest weight step the increment buttons should use.
  static double step({required bool imperial}) => imperial ? lbToKg(2.5) : 1.25;

  static String _trim(double value, int decimals) {
    final String text = value.toStringAsFixed(decimals);
    if (!text.contains('.')) return text;
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
