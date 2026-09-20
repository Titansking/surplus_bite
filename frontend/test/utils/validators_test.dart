import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('rejects empty', () => expect(Validators.email(''), 'Email is required'));
    test('rejects null', () => expect(Validators.email(null), 'Email is required'));
    test('rejects malformed', () {
      expect(Validators.email('not-an-email'), 'Enter a valid email');
      expect(Validators.email('a@b'), 'Enter a valid email');
    });
    test('accepts valid email', () {
      expect(Validators.email('priya@gmail.com'), isNull);
      expect(Validators.email('a.b-c@example.co.in'), isNull);
    });
  });

  group('Validators.password', () {
    test('rejects empty', () {
      expect(Validators.password(''), 'Password is required');
    });
    test('rejects short', () {
      expect(Validators.password('abc12'), 'Password must be at least 6 characters');
    });
    test('accepts 6+ chars', () => expect(Validators.password('secret123'), isNull));
  });

  group('Validators.required', () {
    test('rejects empty/whitespace', () {
      expect(Validators.required(''), 'This field is required');
      expect(Validators.required('   '), 'This field is required');
      expect(Validators.required('', 'Title'), 'Title is required');
    });
    test('accepts value', () => expect(Validators.required('x', 'Title'), isNull));
  });

  group('Validators.phone', () {
    test('rejects empty', () {
      expect(Validators.phone(''), 'Phone number is required');
    });
    test('rejects short', () {
      expect(Validators.phone('12345'), 'Enter a valid phone number');
    });
    test('accepts formatted', () {
      expect(Validators.phone('+91 98765 43210'), isNull);
      expect(Validators.phone('9876543210'), isNull);
    });
  });

  group('Validators.price', () {
    test('rejects empty/invalid/negative', () {
      expect(Validators.price(''), 'Price is required');
      expect(Validators.price('abc'), 'Enter a valid price');
      expect(Validators.price('-5'), 'Enter a valid price');
    });
    test('accepts valid price', () {
      expect(Validators.price('0'), isNull);
      expect(Validators.price('149.50'), isNull);
    });
  });

  group('Validators.quantity', () {
    test('rejects empty/invalid/zero/negative', () {
      expect(Validators.quantity(''), 'Quantity is required');
      expect(Validators.quantity('abc'), 'Enter a valid quantity');
      expect(Validators.quantity('0'), 'Enter a valid quantity');
      expect(Validators.quantity('-2'), 'Enter a valid quantity');
    });
    test('accepts positive', () => expect(Validators.quantity('3'), isNull));
  });

  group('Validators.confirmPassword', () {
    test('rejects empty and mismatch', () {
      expect(Validators.confirmPassword('', 'abc'), 'Please confirm password');
      expect(Validators.confirmPassword('zzz', 'abc'), 'Passwords do not match');
    });
    test('accepts match', () {
      expect(Validators.confirmPassword('secret', 'secret'), isNull);
    });
  });

  group('Validators.name', () {
    test('rejects empty/short', () {
      expect(Validators.name(''), 'Name is required');
      expect(Validators.name('A'), 'Name must be at least 2 characters');
    });
    test('accepts long enough', () => expect(Validators.name('Priya'), isNull));
  });

  group('Validators.description', () {
    test('rejects empty/short', () {
      expect(Validators.description(''), 'Description is required');
      expect(
        Validators.description('too short'),
        'Description must be at least 10 characters',
      );
    });
    test('accepts 10+ chars', () {
      expect(Validators.description('Fresh food today.'), isNull);
    });
  });
}