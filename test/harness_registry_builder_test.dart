import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:tief_test_harness/src/harness_registry_builder.dart';

// `testBuilder` resolves imports against a synthetic package universe built
// purely from the given source assets - it has no access to this project's
// real `lib/`. So every test provides its own minimal stand-in for
// `package:tief_test_harness`, just enough to declare the annotations and a
// `ScenarioHarness` the fixtures can return, without pulling in Flutter.
const _stubPackage = {
  'tief_test_harness|lib/tief_test_harness.dart': '''
    class RegisterHarness {
      final String group;
      final String name;
      const RegisterHarness(this.group, {required this.name});
    }

    class GenerateHarnessRegistry {
      final String group;
      const GenerateHarnessRegistry(this.group);
    }

    class ScenarioHarness {
      final Object? appContent;
      ScenarioHarness({required this.appContent});
    }
  ''',
};

const _registryHeader =
    "import 'package:tief_test_harness/tief_test_harness.dart';";

String _registry(String group) =>
    '''
$_registryHeader

@GenerateHarnessRegistry('$group')
void generateRegistry() {}
''';

String _harness(String group, String name, String functionName) =>
    '''
$_registryHeader

@RegisterHarness('$group', name: '$name')
Future<ScenarioHarness> $functionName() async {
  return ScenarioHarness(appContent: null);
}
''';

typedef _BuildResult = ({
  bool succeeded,
  Map<String, List<int>> outputs,
  List<LogRecord> logs,
});

Future<_BuildResult> _runBuilder(
  Map<String, String> sourceAssets, {
  Map<String, String>? builderConfig,
}) async {
  final logs = <LogRecord>[];
  final builder = HarnessRegistryBuilder(
    BuilderOptions(builderConfig ?? const {}),
  );

  final result = await testBuilder(
    builder,
    {..._stubPackage, ...sourceAssets},
    rootPackage: 'a',
    onLog: logs.add,
    flattenOutput: true,
  );

  final outputs = <String, List<int>>{};
  for (final id in result.outputs) {
    outputs['${id.package}|${id.path}'] = result.readerWriter.testing.readBytes(
      id,
    );
  }

  return (succeeded: result.succeeded, outputs: outputs, logs: logs);
}

String _decode(List<int> bytes) => String.fromCharCodes(bytes);

void main() {
  test('does nothing for a file with no @GenerateHarnessRegistry', () async {
    final result = await _runBuilder({
      'a|lib/checkout_harness.dart': _harness(
        'marketing',
        'checkout_flow',
        'buildCheckoutHarness',
      ),
    });

    expect(result.succeeded, isTrue);
    expect(result.outputs, isEmpty);
  });

  test('generates a registry for a single harness', () async {
    final result = await _runBuilder({
      'a|lib/registry.dart': _registry('marketing'),
      'a|lib/checkout_harness.dart': _harness(
        'marketing',
        'checkout_flow',
        'buildCheckoutHarness',
      ),
    });

    expect(result.succeeded, isTrue);
    expect(result.outputs, hasLength(1));

    final source = _decode(result.outputs.values.single);
    expect(source, contains("import 'checkout_harness.dart' as h0;"));
    expect(source, contains('enum MarketingHarness {'));
    expect(source, contains('class MarketingHarnessRegistry {'));
    expect(
      source,
      contains("MarketingHarness.checkoutFlow => 'checkout_flow',"),
    );
    expect(
      source,
      contains('MarketingHarness.checkoutFlow: h0.buildCheckoutHarness,'),
    );
  });

  test('collects harnesses from nested directories in sorted order', () async {
    final result = await _runBuilder({
      'a|lib/registry.dart': _registry('marketing'),
      'a|lib/z_harness.dart': _harness(
        'marketing',
        'zebra_flow',
        'buildZebraHarness',
      ),
      'a|lib/sub/a_harness.dart': _harness(
        'marketing',
        'account_flow',
        'buildAccountHarness',
      ),
    });

    expect(result.succeeded, isTrue);
    final source = _decode(result.outputs.values.single);

    final accountImport = source.indexOf("'sub/a_harness.dart'");
    final zebraImport = source.indexOf("'z_harness.dart'");
    expect(accountImport, greaterThanOrEqualTo(0));
    expect(zebraImport, greaterThanOrEqualTo(0));
    expect(accountImport, lessThan(zebraImport));

    final mapStart = source.indexOf('_builders = {');
    final mapBody = source.substring(mapStart);
    expect(
      mapBody.indexOf('MarketingHarness.accountFlow'),
      lessThan(mapBody.indexOf('MarketingHarness.zebraFlow')),
    );
  });

  test('ignores harnesses registered to a different group', () async {
    final result = await _runBuilder({
      'a|lib/registry.dart': _registry('marketing'),
      'a|lib/checkout_harness.dart': _harness(
        'marketing',
        'checkout_flow',
        'buildCheckoutHarness',
      ),
      'a|lib/billing_harness.dart': _harness(
        'billing',
        'invoice_flow',
        'buildInvoiceHarness',
      ),
    });

    expect(result.succeeded, isTrue);
    final source = _decode(result.outputs.values.single);
    expect(source, contains('checkout_flow'));
    expect(source, isNot(contains('invoice_flow')));
  });

  test('ignores files outside the configured source_glob', () async {
    final result = await _runBuilder(
      {
        'a|lib/registry.dart': _registry('marketing'),
        'a|lib/included_harness.dart': _harness(
          'marketing',
          'included_flow',
          'buildIncludedHarness',
        ),
        'a|lib/other/excluded_harness.dart': _harness(
          'marketing',
          'excluded_flow',
          'buildExcludedHarness',
        ),
      },
      builderConfig: {'source_glob': 'lib/*_harness.dart'},
    );

    expect(result.succeeded, isTrue);
    final source = _decode(result.outputs.values.single);
    expect(source, contains('included_flow'));
    expect(source, isNot(contains('excluded_flow')));
  });

  test(
    'warns and skips a @RegisterHarness on a non-function top-level element',
    () async {
      final result = await _runBuilder({
        'a|lib/registry.dart': _registry('marketing'),
        'a|lib/checkout_harness.dart': _harness(
          'marketing',
          'checkout_flow',
          'buildCheckoutHarness',
        ),
        'a|lib/nested_harness.dart':
            '''
$_registryHeader

@RegisterHarness('marketing', name: 'nested_flow')
final buildNestedHarness = null;
''',
      });

      expect(result.succeeded, isTrue);
      final source = _decode(result.outputs.values.single);
      expect(source, contains('checkout_flow'));
      expect(source, isNot(contains('nested_flow')));

      expect(
        result.logs,
        contains(
          isA<LogRecord>()
              .having((r) => r.level, 'level', Level.WARNING)
              .having(
                (r) => r.message,
                'message',
                contains('only top-level functions are supported'),
              ),
        ),
      );
    },
  );

  test('fails the build when the group has no matching harnesses', () async {
    final result = await _runBuilder({
      'a|lib/registry.dart': _registry('marketing'),
    });

    expect(result.succeeded, isFalse);
    expect(
      result.logs,
      contains(
        isA<LogRecord>().having(
          (r) => r.message,
          'message',
          contains(
            "No @RegisterHarness functions found for group "
            "'marketing'",
          ),
        ),
      ),
    );
  });

  test('fails the build on duplicate harness names within a group', () async {
    final result = await _runBuilder({
      'a|lib/registry.dart': _registry('marketing'),
      'a|lib/checkout_v1_harness.dart': _harness(
        'marketing',
        'checkout_flow',
        'buildCheckoutV1Harness',
      ),
      'a|lib/checkout_v2_harness.dart': _harness(
        'marketing',
        'checkout_flow',
        'buildCheckoutV2Harness',
      ),
    });

    expect(result.succeeded, isFalse);
    expect(
      result.logs,
      contains(
        isA<LogRecord>().having(
          (r) => r.message,
          'message',
          contains("Duplicate harness name 'checkout_flow'"),
        ),
      ),
    );
  });

  test(
    'fails the build when a harness name cannot become a Dart identifier',
    () async {
      final result = await _runBuilder({
        'a|lib/registry.dart': _registry('marketing'),
        'a|lib/checkout_harness.dart': _harness(
          'marketing',
          '123 flow',
          'buildCheckoutHarness',
        ),
      });

      expect(result.succeeded, isFalse);
      expect(
        result.logs,
        contains(
          isA<LogRecord>().having(
            (r) => r.message,
            'message',
            contains(
              "Harness name '123 flow' in group 'marketing' can't be "
              'turned into a valid enum member',
            ),
          ),
        ),
      );
    },
  );

  test('fails the build when two names collide once camelCased', () async {
    final result = await _runBuilder({
      'a|lib/registry.dart': _registry('marketing'),
      'a|lib/checkout_a_harness.dart': _harness(
        'marketing',
        'checkout-flow',
        'buildCheckoutAHarness',
      ),
      'a|lib/checkout_b_harness.dart': _harness(
        'marketing',
        'checkout_flow',
        'buildCheckoutBHarness',
      ),
    });

    expect(result.succeeded, isFalse);
    expect(
      result.logs,
      contains(
        isA<LogRecord>().having(
          (r) => r.message,
          'message',
          contains("both map to the enum member 'checkoutFlow'"),
        ),
      ),
    );
  });
}
