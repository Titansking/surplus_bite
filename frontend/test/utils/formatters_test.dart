import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/utils/formatters.dart';

void main() {
  group('Formatters.currency', () {
    test('formats rupees with 2 decimals', () {
      expect(Formatters.currency(120), '₹120.00');
      expect(Formatters.currency(0), '₹0.00');
    });

    test('uses Indian digit grouping', () {
      expect(Formatters.currency(1234567.5), '₹12,34,567.50');
    });
  });

  group('date/time', () {
    final date = DateTime(2026, 9, 21, 14, 5);

    test('date', () => expect(Formatters.date(date), 'Sep 21, 2026'));
    test('shortDate', () => expect(Formatters.shortDate(date), 'Sep 21'));
    test('time', () => expect(Formatters.time(date), '2:05 PM'));

    test('dateTime', () {
      expect(Formatters.dateTime(date), 'Sep 21, 2026 • 2:05 PM');
    });

    test('pickupWindow', () {
      expect(
        Formatters.pickupWindow(
          DateTime(2026, 9, 21, 9, 0),
          DateTime(2026, 9, 21, 12, 30),
        ),
        '9:00 AM - 12:30 PM',
      );
    });
  });

  group('Formatters.relativeTime', () {
    test('formats recent/past dates without throwing', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      expect(Formatters.relativeTime(past), isNotEmpty);
    });
  });

  group('misc', () {
    test('discount', () => expect(Formatters.discount(40.0), '40% OFF'));
    test('rating', () => expect(Formatters.rating(4.5678), '4.6'));

    test('gramsToKg', () {
      expect(Formatters.gramsToKg(250), '250 g');
      expect(Formatters.gramsToKg(1000), '1.0 kg');
      expect(Formatters.gramsToKg(1500), '1.5 kg');
    });

    test('co2Saved', () => expect(Formatters.co2Saved(12.5), '12.5 kg CO₂ saved'));

    test('toTimestamp returns a Firestore timestamp', () {
      final ts = Formatters.toTimestamp(DateTime(2026, 9, 21));
      expect(ts.toDate(), DateTime(2026, 9, 21));
    });
  });
}