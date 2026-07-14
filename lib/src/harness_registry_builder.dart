import 'dart:async';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'harness_annotation.dart';
import 'registry/harness_entry_validator.dart';
import 'registry/harness_registry_writer.dart';
import 'registry/harness_source_scanner.dart';

class HarnessRegistryBuilder implements Builder {
  static const _registryChecker = TypeChecker.fromRuntime(
    GenerateHarnessRegistry,
  );

  final String sourceGlob;

  HarnessRegistryBuilder(BuilderOptions options)
    : sourceGlob =
          options.config['source_glob'] as String? ?? '**/*_harness.dart';

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.th.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    if (!await buildStep.resolver.isLibrary(inputId)) return;

    final library = await buildStep.resolver.libraryFor(inputId);
    final registrations = LibraryReader(
      library,
    ).annotatedWithExact(_registryChecker).toList();

    if (registrations.isEmpty) return;

    final group = registrations.first.annotation.read('group').stringValue;
    final outputId = buildStep.allowedOutputs.single;

    final entries = await HarnessSourceScanner(
      buildStep: buildStep,
      sourceGlob: sourceGlob,
      outputId: outputId,
    ).scanGroup(group);

    HarnessEntryValidator().validate(group, entries);

    await buildStep.writeAsString(
      outputId,
      HarnessRegistryWriter().write(group, entries),
    );
  }
}

Builder harnessRegistryBuilder(BuilderOptions options) =>
    HarnessRegistryBuilder(options);
