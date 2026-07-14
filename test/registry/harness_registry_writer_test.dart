import 'package:flutter_test/flutter_test.dart';
import 'package:tief_test_harness/src/registry/harness_entry.dart';
import 'package:tief_test_harness/src/registry/harness_registry_writer.dart';

void main() {
  late HarnessRegistryWriter writer;

  setUp(() {
    writer = HarnessRegistryWriter();
  });

  test('asserts entries is non-empty (a 0-value enum is invalid Dart)', () {
    expect(() => writer.write('marketing', []), throwsA(isA<AssertionError>()));
  });

  test('derives the enum and class names from the group', () {
    final source = writer.write('order-fulfillment', [
      HarnessEntry(
        name: 'checkout_flow',
        functionName: 'buildCheckoutHarness',
        importPath: 'checkout_harness.dart',
      ),
    ]);

    expect(source, contains('enum OrderFulfillmentHarness {'));
    expect(source, contains('class OrderFulfillmentHarnessRegistry {'));
  });

  test('aliases each import and maps it to an enum member', () {
    final source = writer.write('marketing', [
      HarnessEntry(
        name: 'checkout_flow',
        functionName: 'buildCheckoutHarness',
        importPath: 'checkout_harness.dart',
      ),
    ]);

    expect(source, contains("import 'checkout_harness.dart' as h0;"));
    expect(source, contains('checkoutFlow;')); // sole enum member
    expect(
      source,
      contains("MarketingHarness.checkoutFlow => 'checkout_flow',"),
    );
    expect(
      source,
      contains('MarketingHarness.checkoutFlow: h0.buildCheckoutHarness,'),
    );
  });

  test('sorts entries by name for deterministic output', () {
    final source = writer.write('marketing', [
      HarnessEntry(
        name: 'checkout_flow',
        functionName: 'buildCheckout',
        importPath: 'checkout.dart',
      ),
      HarnessEntry(
        name: 'account_settings',
        functionName: 'buildAccountSettings',
        importPath: 'account_settings.dart',
      ),
      HarnessEntry(
        name: 'onboarding',
        functionName: 'buildOnboarding',
        importPath: 'onboarding.dart',
      ),
    ]);

    expect(source, contains("import 'account_settings.dart' as h0;"));
    expect(source, contains("import 'checkout.dart' as h1;"));
    expect(source, contains("import 'onboarding.dart' as h2;"));

    final enumStart = source.indexOf('enum MarketingHarness {');
    final enumBody = source.substring(enumStart);
    expect(
      enumBody.indexOf('accountSettings'),
      lessThan(enumBody.indexOf('checkoutFlow')),
    );
    expect(
      enumBody.indexOf('checkoutFlow'),
      lessThan(enumBody.indexOf('onboarding')),
    );
  });

  test('keeps spaces in the display name for pretty test output', () {
    final source = writer.write('marketing', [
      HarnessEntry(
        name: 'Checkout Flow',
        functionName: 'buildCheckoutHarness',
        importPath: 'checkout_harness.dart',
      ),
    ]);

    // The identifier is camelCased...
    expect(source, contains('checkoutFlow;'));
    // ...but the harness's display name keeps its spaces intact.
    expect(
      source,
      contains("MarketingHarness.checkoutFlow => 'Checkout Flow',"),
    );
  });

  test('escapes single quotes and backslashes in harness names', () {
    final source = writer.write('marketing', [
      HarnessEntry(
        name: r"O'Brien's \flow",
        functionName: 'buildHarness',
        importPath: 'harness.dart',
      ),
    ]);

    expect(
      source,
      contains(r"MarketingHarness.oBrienSFlow => 'O\'Brien\'s \\flow',"),
    );
  });
}
