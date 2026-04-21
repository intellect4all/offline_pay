import 'package:flutter/services.dart';

class Haptics {
  Haptics._();

  static void tap() => HapticFeedback.lightImpact();

  static void selection() => HapticFeedback.selectionClick();

  static void success() => HapticFeedback.mediumImpact();

  static void error() => HapticFeedback.heavyImpact();
}
