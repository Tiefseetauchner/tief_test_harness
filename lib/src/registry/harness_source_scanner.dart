import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import '../harness_annotation.dart';
import 'harness_entry.dart';

class HarnessSourceScanner {
  static const _harnessChecker = TypeChecker.fromRuntime(RegisterHarness);

  final BuildStep buildStep;
  final String sourceGlob;
  final AssetId outputId;

  HarnessSourceScanner({
    required this.buildStep,
    required this.sourceGlob,
    required this.outputId,
  });

  Future<List<HarnessEntry>> scanGroup(String group) async {
    final entries = <HarnessEntry>[];

    await for (final asset in buildStep.findAssets(Glob(sourceGlob))) {
      if (!await buildStep.resolver.isLibrary(asset)) continue;
      final library = await buildStep.resolver.libraryFor(asset);

      for (final annotated in LibraryReader(
        library,
      ).annotatedWithExact(_harnessChecker)) {
        final reader = annotated.annotation;
        if (reader.read('group').stringValue != group) continue;

        final element = annotated.element;

        entries.add(
          HarnessEntry(
            name: reader.read('name').stringValue,
            functionName: element.name!,
            importPath: p.url.relative(
              asset.path,
              from: p.url.dirname(outputId.path),
            ),
          ),
        );
      }
    }

    return entries;
  }
}
