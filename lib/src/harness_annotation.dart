/// An annotation to register a test harness with the test runner.
/// This annotation should be placed on a top-level function that
/// returns a [ScenarioHarness].
class RegisterHarness {
  final String group;

  /// The harness's name within [group]. Must be unique among all harnesses
  /// registered to the same group.
  final String name;

  /// Creates a new [RegisterHarness] annotation.
  ///
  /// Scopes the harness to a specific group. This is useful for generating
  /// a harness registry for a specific group of test harnesses.
  const RegisterHarness(this.group, {required this.name});
}

/// An annotation to generate a harness registry for a group of test harnesses.
class GenerateHarnessRegistry {
  final String group;

  /// Creates a new [GenerateHarnessRegistry] annotation.
  ///
  /// Scopes the generated harness registry to a specific group. This is useful
  /// for generating a harness registry for a specific group of test harnesses.
  const GenerateHarnessRegistry(this.group);
}
