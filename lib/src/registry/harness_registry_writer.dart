import 'harness_entry.dart';
import 'harness_identifier.dart';

String _escape(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

class HarnessRegistryWriter {
  String write(String group, List<HarnessEntry> entries) {
    assert(entries.isNotEmpty, 'entries must be non-empty');

    final sorted = [...entries]..sort((a, b) => a.name.compareTo(b.name));
    final members = [for (final entry in sorted) toCamelCase(entry.name)];

    final groupPascal = toPascalCase(group);
    final enumName = '${groupPascal}Harness';
    final className = '${groupPascal}HarnessRegistry';

    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln()
      ..writeln("import 'package:tief_test_harness/tief_test_harness.dart';");

    for (var i = 0; i < sorted.length; i++) {
      buffer.writeln("import '${sorted[i].importPath}' as h$i;");
    }
    buffer.writeln();

    _writeEnum(buffer, enumName, sorted, members);
    buffer.writeln();
    _writeRegistryClass(buffer, className, enumName, sorted, members);

    return buffer.toString();
  }

  void _writeEnum(
    StringBuffer buffer,
    String enumName,
    List<HarnessEntry> sorted,
    List<String> members,
  ) {
    buffer.writeln('enum $enumName {');
    for (var i = 0; i < sorted.length; i++) {
      final separator = i == sorted.length - 1 ? ';' : ',';
      buffer.writeln('  ${members[i]}$separator');
    }
    buffer.writeln();
    buffer.writeln('  String get harnessName => switch (this) {');
    for (var i = 0; i < sorted.length; i++) {
      buffer.writeln(
        "    $enumName.${members[i]} => '${_escape(sorted[i].name)}',",
      );
    }
    buffer.writeln('  };');
    buffer.writeln();
    buffer.writeln('  static $enumName fromHarnessName(String name) =>');
    buffer.writeln('      values.firstWhere(');
    buffer.writeln('        (harness) => harness.harnessName == name,');
    buffer.writeln('        orElse: () => throw ArgumentError.value(');
    buffer.writeln("          name,");
    buffer.writeln("          'name',");
    buffer.writeln("          'No $enumName with this harness name.',");
    buffer.writeln('        ),');
    buffer.writeln('      );');
    buffer.writeln('}');
  }

  void _writeRegistryClass(
    StringBuffer buffer,
    String className,
    String enumName,
    List<HarnessEntry> sorted,
    List<String> members,
  ) {
    buffer.writeln('class $className {');
    buffer.writeln('  const $className() : this._(null);');
    buffer.writeln('  const $className._(this._selected);');
    buffer.writeln();
    buffer.writeln('  final Set<$enumName>? _selected;');
    buffer.writeln();
    buffer.writeln(
      '  static const Map<$enumName, Future<ScenarioHarness> Function()> '
      '_builders = {',
    );
    for (var i = 0; i < sorted.length; i++) {
      buffer.writeln(
        '    $enumName.${members[i]}: h$i.${sorted[i].functionName},',
      );
    }
    buffer.writeln('  };');
    buffer.writeln();
    buffer.writeln('  /// Restricts a subsequent [build] to just [harnesses].');
    buffer.writeln('  $className only(Set<$enumName> harnesses) =>');
    buffer.writeln('      $className._(harnesses);');
    buffer.writeln();
    buffer.writeln(
      '  /// Restricts a subsequent [build] to just the harnesses named '
      '[names].',
    );
    buffer.writeln('  $className onlyNamed(Set<String> names) =>');
    buffer.writeln('      only(names.map($enumName.fromHarnessName).toSet());');
    buffer.writeln();
    buffer.writeln(
      '  /// Calls every selected builder and awaits the results, keyed by '
      'harness name.',
    );
    buffer.writeln('  Future<Map<String, ScenarioHarness>> build() async {');
    buffer.writeln('    final selected = _selected == null');
    buffer.writeln('        ? _builders.entries');
    buffer.writeln(
      '        : _builders.entries.where((entry) => _selected.contains(entry.key));',
    );
    buffer.writeln();
    buffer.writeln('    final resolved = await Future.wait(');
    buffer.writeln(
      '      selected.map((entry) async => MapEntry(entry.key.harnessName, await entry.value())),',
    );
    buffer.writeln('    );');
    buffer.writeln();
    buffer.writeln('    return Map.fromEntries(resolved);');
    buffer.writeln('  }');
    buffer.writeln('}');
  }
}
