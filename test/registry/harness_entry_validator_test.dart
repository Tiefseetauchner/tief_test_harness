import 'package:test/test.dart';
import 'package:tief_test_harness/src/registry/harness_entry.dart';
import 'package:tief_test_harness/src/registry/harness_entry_validator.dart';

HarnessEntry _entry(String name, {String functionName = 'buildHarness'}) =>
    HarnessEntry(
      name: name,
      functionName: functionName,
      importPath: '$functionName.dart',
    );

void main() {
  late HarnessEntryValidator validator;

  setUp(() {
    validator = HarnessEntryValidator();
  });

  test('throws when no entries were found for the group', () {
    expect(
      () => validator.validate('marketing', []),
      throwsA(
        isA<HarnessRegistryException>().having(
          (e) => e.message,
          'message',
          contains("group 'marketing'"),
        ),
      ),
    );
  });

  test('accepts a list of entries with unique names', () {
    expect(
      () => validator.validate('marketing', [
        _entry('checkout_flow', functionName: 'buildCheckoutHarness'),
        _entry('onboarding', functionName: 'buildOnboardingHarness'),
      ]),
      returnsNormally,
    );
  });

  test('throws on duplicate names within the same group', () {
    final first = _entry('checkout_flow', functionName: 'buildCheckoutV1');
    final second = _entry('checkout_flow', functionName: 'buildCheckoutV2');

    expect(
      () => validator.validate('marketing', [first, second]),
      throwsA(
        isA<HarnessRegistryException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains("Duplicate harness name 'checkout_flow'"),
            contains('buildCheckoutV1'),
            contains('buildCheckoutV2'),
          ),
        ),
      ),
    );
  });

  test('does not flag duplicate names across different validate calls', () {
    validator.validate('marketing', [_entry('checkout_flow')]);

    expect(
      () => validator.validate('billing', [_entry('checkout_flow')]),
      returnsNormally,
    );
  });
}
