import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:riverpod/riverpod.dart';

/// Applies provider overrides around [child], returning the widget to pump.
typedef ProviderScopeBuilder = Future<Widget> Function(Widget child);

/// Builds the app under test. Implementations typically wrap [child] in
/// whatever app shell (localization, theming, routing, ...) the consuming
/// project needs, applying [providerScopeBuilder] if given.
typedef AppBuilder =
    Widget Function({
      required Widget child,
      required Locale locale,
      ProviderScopeBuilder? providerScopeBuilder,
    });

/// A callback used in setUpAll/tearDownAll of [HarnessRunner.run].
typedef HarnessRunnerCallback =
    Future<void> Function(
      IntegrationTestWidgetsFlutterBinding binding,
      ProviderContainer ref,
    );

/// The primary callback for a scenario's test logic: interact with the
/// already-pumped app and verify whatever's expected.
typedef TestCallback =
    Future<void> Function(
      WidgetTester tester,
      IntegrationTestWidgetsFlutterBinding binding,
    );

/// Runs once before/after all scenarios in a harness (i.e. `beforeAll`/
/// `afterAll` semantics), e.g. initializing a database or starting a server.
typedef HarnessCallback =
    Future<void> Function(
      IntegrationTestWidgetsFlutterBinding binding,
      ProviderContainer ref,
      String harnessName,
    );

/// Runs before/after every scenario (i.e. `beforeEach`/`afterEach`
/// semantics), whether declared on the [Scenario] itself or as a
/// [ScenarioHarness]-wide default.
typedef ScenarioCallback =
    Future<void> Function(
      WidgetTester tester,
      IntegrationTestWidgetsFlutterBinding binding,
      ProviderContainer ref,
      String harnessName,
      String scenarioName,
    );

/// A scenario is a single test case that can be run in isolation.
class Scenario {
  /// The name of the scenario, used in the testWidgets description.
  final String name;

  /// The scenario's test logic, run after the app has been built and
  /// pumped and [afterEach] hooks are about to fire. Optional - a scenario
  /// with nothing to do here (e.g. a pure screenshot, no interaction) can
  /// omit it.
  final TestCallback? testCallback;

  /// An optional widget to override the app content for this scenario. If not
  /// provided, the app content from the harness will be used.
  final Widget? overrideAppContent;

  /// An optional provider scope builder to pass to the app builder for this
  /// scenario. Useful for overriding providers for a specific scenario.
  final ProviderScopeBuilder? providerScopeBuilder;

  /// Runs before [testCallback], after the harness's own [beforeEach].
  final ScenarioCallback? beforeEach;

  /// Runs after [testCallback], before the harness's own [afterEach]. Use
  /// this for anything that needs to happen once per scenario after its
  /// primary action - taking a screenshot, verifying state, cleaning up
  /// overlays added during the test, etc.
  final ScenarioCallback? afterEach;

  /// Creates a new scenario with the given [name] and optional parameters.
  Scenario({
    required this.name,
    this.testCallback,
    this.overrideAppContent,
    this.providerScopeBuilder,
    this.beforeEach,
    this.afterEach,
  });
}

/// A harness is a collection of scenarios that can be run together. It
/// provides a way to group related scenarios and share setup and teardown
/// logic.
class ScenarioHarness {
  /// The app content to use for all scenarios in this harness. This is typically
  /// the widget under test, e.g. a screen or a page. Scenarios, unless overriding
  /// this, will use this widget as the app content.
  final Widget appContent;

  /// Runs before every scenario in this harness, before that scenario's own
  /// [Scenario.beforeEach].
  final ScenarioCallback? beforeEach;

  /// Runs after every scenario in this harness, after that scenario's own
  /// [Scenario.afterEach].
  final ScenarioCallback? afterEach;

  /// Runs once before any scenario in this harness runs, e.g. initializing
  /// a database or starting a server.
  final HarnessCallback? beforeAll;

  /// Runs once after every scenario in this harness has run, e.g. closing
  /// a database, stopping a server, or uploading collected results.
  final HarnessCallback? afterAll;

  /// Creates a new harness with the given [appContent] and optional
  /// parameters.
  ScenarioHarness({
    required this.appContent,
    this.beforeEach,
    this.afterEach,
    this.beforeAll,
    this.afterAll,
  });

  final List<Scenario> _scenarios = [];

  /// Adds a scenario to this harness. Scenarios are run in the order they are
  /// added.
  void addScenario(Scenario scenario) {
    _scenarios.add(scenario);
  }

  /// Returns an unmodifiable list of scenarios in this harness.
  List<Scenario> get scenarios => List.unmodifiable(_scenarios);
}

/// A runner that runs a map of [ScenarioHarness]es, each containing a list
/// of [Scenario]s. It provides a way to run multiple harnesses and scenarios
/// in a single test run, with shared setup and teardown logic.
class HarnessRunner {
  /// The harnesses to run, keyed by harness name. The name shows up in the
  /// testWidgets description and is passed to every callback as
  /// `harnessName`.
  final Map<String, ScenarioHarness> harnesses;

  /// The app builder to use for all scenarios. This is typically a function that
  /// wraps the app content in whatever app shell (localization, theming, routing,
  /// ...) the consuming project needs, applying [providerScopeBuilder] if given.
  final AppBuilder appBuilder;

  /// Creates a new runner with the given [harnesses] and [appBuilder].
  HarnessRunner({required this.harnesses, required this.appBuilder});

  /// Runs all harnesses and scenarios, applying the given [locale] and optional
  /// [setUp] and [tearDown] callbacks. [setUp] runs in a setUpAll block once for
  /// the whole run; [tearDown] runs in a tearDownAll block once for the whole
  /// run. Both receive the [IntegrationTestWidgetsFlutterBinding] and a
  /// [ProviderContainer] for managing provider state.
  ///
  /// Must be called (and awaited) directly from `main()` - package:test starts
  /// running whatever's registered as soon as this yields once without
  /// completing, so this method deliberately does no async work of its own
  /// during declaration.
  Future<void> run({
    Locale locale = const Locale("en", "US"),
    HarnessRunnerCallback? setUp,
    HarnessRunnerCallback? tearDown,
  }) async {
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    final ref = ProviderContainer();

    setUpAll(() async {
      if (setUp != null) await setUp(binding, ref);
    });

    for (final harnessEntry in harnesses.entries) {
      final harnessName = harnessEntry.key;
      final harness = harnessEntry.value;

      group(harnessName, () {
        final harnessBeforeAll = harness.beforeAll;
        if (harnessBeforeAll != null) {
          setUpAll(() => harnessBeforeAll(binding, ref, harnessName));
        }

        final harnessAfterAll = harness.afterAll;
        if (harnessAfterAll != null) {
          tearDownAll(() => harnessAfterAll(binding, ref, harnessName));
        }

        for (final scenario in harness.scenarios) {
          _runScenario(
            scenario,
            binding: binding,
            ref: ref,
            harness: harness,
            harnessName: harnessName,
            appBuilder: appBuilder,
            locale: locale,
          );
        }
      });
    }

    tearDownAll(() async {
      if (tearDown != null) await tearDown(binding, ref);
      ref.dispose();
    });
  }

  void _runScenario(
    Scenario scenario, {
    required IntegrationTestWidgetsFlutterBinding binding,
    required ProviderContainer ref,
    required ScenarioHarness harness,
    required String harnessName,
    required AppBuilder appBuilder,
    required Locale locale,
  }) {
    testWidgets("Run Test $harnessName ${scenario.name}", (
      WidgetTester tester,
    ) async {
      final harnessBeforeEach = harness.beforeEach;
      if (harnessBeforeEach != null) {
        await harnessBeforeEach(
          tester,
          binding,
          ref,
          harnessName,
          scenario.name,
        );
      }

      final scenarioBeforeEach = scenario.beforeEach;
      if (scenarioBeforeEach != null) {
        await scenarioBeforeEach(
          tester,
          binding,
          ref,
          harnessName,
          scenario.name,
        );
      }

      final app = appBuilder(
        locale: locale,
        providerScopeBuilder: scenario.providerScopeBuilder,
        child: scenario.overrideAppContent ?? harness.appContent,
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      if (scenario.testCallback != null) {
        await scenario.testCallback!(tester, binding);
      }

      final scenarioAfterEach = scenario.afterEach;
      if (scenarioAfterEach != null) {
        await scenarioAfterEach(
          tester,
          binding,
          ref,
          harnessName,
          scenario.name,
        );
      }

      final harnessAfterEach = harness.afterEach;
      if (harnessAfterEach != null) {
        await harnessAfterEach(
          tester,
          binding,
          ref,
          harnessName,
          scenario.name,
        );
      }
    });
  }
}
