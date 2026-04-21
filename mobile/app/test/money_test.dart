import 'package:flutter_test/flutter_test.dart';
import 'package:offlinepay_app/src/util/money.dart';

void main() {
  group('formatNaira', () {
    test('basic', () {
      expect(formatNaira(0), '₦0.00');
      expect(formatNaira(1), '₦0.01');
      expect(formatNaira(100), '₦1.00');
      expect(formatNaira(250000), '₦2,500.00');
      expect(formatNaira(1000000000), '₦10,000,000.00');
    });
    test('negative', () {
      expect(formatNaira(-50), '-₦0.50');
    });
  });

  group('parseNairaToKobo', () {
    test('round trips', () {
      expect(parseNairaToKobo('2500'), 250000);
      expect(parseNairaToKobo('2,500.00'), 250000);
      expect(parseNairaToKobo('₦2,500.50'), 250050);
      expect(parseNairaToKobo('NGN 0.01'), 1);
      expect(parseNairaToKobo('0.1'), 10);
    });
    test('invalid', () {
      expect(parseNairaToKobo(''), null);
      expect(parseNairaToKobo('abc'), null);
      expect(parseNairaToKobo('1.234'), null);
    });
  });
}
