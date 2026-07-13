import 'harness_entry.dart';
import 'harness_identifier.dart';

class HarnessRegistryException implements Exception {
  final String message;

  HarnessRegistryException(this.message);

  @override
  String toString() => message;
}

class HarnessEntryValidator {
  void validate(String group, List<HarnessEntry> entries) {
    if (entries.isEmpty) {
      throw HarnessRegistryException(
        "No @RegisterHarness functions found for group '$group'. Check "
        'the group name on @GenerateHarnessRegistry and the source_glob '
        'builder option.',
      );
    }

    final seenByName = <String, HarnessEntry>{};
    final seenByIdentifier = <String, HarnessEntry>{};

    for (final entry in entries) {
      final existingByName = seenByName[entry.name];
      if (existingByName != null) {
        throw HarnessRegistryException(
          "Duplicate harness name '${entry.name}' in group '$group': "
          '${existingByName.functionName} (${existingByName.importPath}) and '
          '${entry.functionName} (${entry.importPath}) both use it. '
          'Harness names must be unique within a group.',
        );
      }
      seenByName[entry.name] = entry;

      final identifier = toCamelCase(entry.name);
      if (!isUsableDartIdentifier(identifier)) {
        throw HarnessRegistryException(
          "Harness name '${entry.name}' in group '$group' can't be turned "
          "into a valid enum member ('$identifier'). Build the name out of "
          "letters, digits, and underscores/hyphens/spaces as word "
          "separators, e.g. 'checkout_flow'.",
        );
      }

      final existingByIdentifier = seenByIdentifier[identifier];
      if (existingByIdentifier != null) {
        throw HarnessRegistryException(
          "Harness names '${existingByIdentifier.name}' and '${entry.name}' "
          "in group '$group' both map to the enum member '$identifier'. "
          'Pick names that are distinct once converted to camelCase.',
        );
      }
      seenByIdentifier[identifier] = entry;
    }
  }
}
