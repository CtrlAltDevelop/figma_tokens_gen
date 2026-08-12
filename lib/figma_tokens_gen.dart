/// Generates Flutter `Color` constants from Figma design-token JSON exports.
///
/// Use it as a command-line tool:
///
/// ```sh
/// dart run figma_tokens_gen --input tokens --output lib/generated/theme
/// ```
///
/// or as a library, when you need to customise parsing or code generation:
///
/// ```dart
/// final converter = TokenConverter(
///   emitter: const DartColorsEmitter(className: 'BrandColors'),
/// );
/// final result = await converter.convert(
///   inputPath: 'tokens',
///   outputPath: 'lib/generated/theme',
/// );
/// print('Generated ${result.colorCount} colours.');
/// ```
library;

export 'src/color_value_parser.dart';
export 'src/emitter/dart_colors_emitter.dart';
export 'src/emitter/token_emitter.dart';
export 'src/models/color_token.dart';
export 'src/naming.dart';
export 'src/token_converter.dart';
export 'src/token_parser.dart';
