import 'dart:io';

import 'package:figma_tokens_gen/figma_tokens_gen.dart';

/// Converts `example/tokens/*.json` into `example/generated/brand_colors.dart`.
///
/// `themes.json` holds the primitives; `semantic.json` shows the two shapes a
/// real export adds on top — nested groups, and `{primitive.token}` aliases
/// pointing across files.
///
/// Run from the package root:
///
/// ```sh
/// dart run example/figma_tokens_gen_example.dart
/// ```
///
/// The equivalent from the command line, with the default names, is:
///
/// ```sh
/// dart run figma_tokens_gen --input tokens --output lib/generated/theme
/// ```
Future<void> main() async {
  final converter = TokenConverter(
    emitter: const DartColorsEmitter(
      className: 'BrandColors',
      paletteClassName: 'BrandPalette',
      fileName: 'brand_colors.dart',
    ),
  );

  try {
    final result = await converter.convert(
      inputPath: 'example/tokens',
      outputPath: 'example/generated',
    );

    for (final warning in result.warnings) {
      stderr.writeln('Warning: $warning');
    }

    stdout.writeln(
      'Wrote ${result.colorCount} colours to ${result.outputFile}',
    );
    for (final category in result.tokens.categories) {
      stdout.writeln('  ${category.name}: ${category.tokens.length}');
    }
  } on ConversionException catch (e) {
    stderr.writeln('Conversion failed: ${e.message}');
    exitCode = 1;
  }
}
