import 'package:flutter_test/flutter_test.dart';
import 'package:tief_test_harness/src/registry/harness_identifier.dart';

void main() {
  group('toCamelCase', () {
    test('converts snake_case', () {
      expect(toCamelCase('checkout_flow'), 'checkoutFlow');
    });

    test('converts kebab-case', () {
      expect(toCamelCase('checkout-flow'), 'checkoutFlow');
    });

    test('converts space-separated words', () {
      expect(toCamelCase('Checkout Flow'), 'checkoutFlow');
    });

    test('lowercases a single word', () {
      expect(toCamelCase('Checkout'), 'checkout');
    });

    test('collapses mixed separators to the same identifier', () {
      expect(toCamelCase('checkout_flow'), toCamelCase('checkout-flow'));
      expect(toCamelCase('checkout_flow'), toCamelCase('Checkout Flow'));
    });
  });

  group('toPascalCase', () {
    test('converts snake_case', () {
      expect(toPascalCase('order_fulfillment'), 'OrderFulfillment');
    });

    test('converts kebab-case', () {
      expect(toPascalCase('order-fulfillment'), 'OrderFulfillment');
    });

    test('capitalizes a single lowercase word', () {
      expect(toPascalCase('marketing'), 'Marketing');
    });
  });

  group('isUsableDartIdentifier', () {
    test('accepts a plain camelCase identifier', () {
      expect(isUsableDartIdentifier('checkoutFlow'), isTrue);
    });

    test('rejects an identifier starting with a digit', () {
      expect(isUsableDartIdentifier('123flow'), isFalse);
    });

    test('rejects a reserved word', () {
      expect(isUsableDartIdentifier('class'), isFalse);
    });

    test('accepts a built-in (non-reserved) keyword', () {
      // `async` is a contextual/built-in keyword in Dart, not reserved -
      // it's legal as an identifier.
      expect(isUsableDartIdentifier('async'), isTrue);
    });

    test('rejects names that collide with enum-synthesized members', () {
      expect(isUsableDartIdentifier('values'), isFalse);
      expect(isUsableDartIdentifier('index'), isFalse);
      expect(isUsableDartIdentifier('hashCode'), isFalse);
    });
  });
}
