import 'dart:io';

import 'package:path/path.dart' as p;

import 'emitter/dart_colors_emitter.dart';
import 'emitter/token_emitter.dart';
import 'models/color_token.dart';
import 'token_parser.dart';

/// The outcome of a conversion run.
class ConversionResult {
  const ConversionResult({
    required this.inputFiles,
    required this.outputFile,
    required this.tokens,
  });

  /// Paths of the token files that were read, in the order they were read.
  final List<String> inputFiles;

  /// Path of the generated Dart file.
  final String outputFile;

  final TokenSet tokens;

  int get colorCount => tokens.colorCount;
  int get categoryCount => tokens.categories.length;
}

/// Thrown when a run cannot produce output.
class ConversionException implements Exception {
  const ConversionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads Figma token JSON from disk and writes generated Dart source.
///
/// This is the only class in the package that touches the filesystem; parsing
/// and emitting stay pure so they can be tested and reused independently.
class TokenConverter {
  TokenConverter({
    TokenParser? parser,
    TokenEmitter? emitter,
  })  : _parser = parser ?? const TokenParser(),
        _emitter = emitter ?? const DartColorsEmitter();

  final TokenParser _parser;
  final TokenEmitter _emitter;

  /// Converts every `.json` file under [inputPath] into a single generated
  /// file inside [outputPath].
  ///
  /// [inputPath] may be a directory (searched recursively) or a single file.
  Future<ConversionResult> convert({
    required String inputPath,
    required String outputPath,
  }) async {
    final files = _collectInputFiles(inputPath);
    if (files.isEmpty) {
      throw ConversionException('No .json token files found in "$inputPath".');
    }

    final documents = <List<TokenCategory>>[];
    for (final file in files) {
      documents.add(
        _parser.categoriesOf(await file.readAsString(), source: file.path),
      );
    }

    final tokens = _parser.merge(documents);
    if (tokens.isEmpty) {
      throw ConversionException(
        'Parsed ${files.length} file(s) but found no colour tokens. '
        'Check that values are under a "\$value" or "value" key.',
      );
    }

    final outputDirectory = Directory(outputPath);
    await outputDirectory.create(recursive: true);
    final outputFile = File(p.join(outputPath, _emitter.fileName));
    await outputFile.writeAsString(_emitter.emit(tokens));

    return ConversionResult(
      inputFiles: files.map((f) => f.path).toList(growable: false),
      outputFile: outputFile.path,
      tokens: tokens,
    );
  }

  List<File> _collectInputFiles(String inputPath) {
    final asFile = File(inputPath);
    if (asFile.existsSync()) return [asFile];

    final directory = Directory(inputPath);
    if (!directory.existsSync()) {
      throw ConversionException('Input path not found: "$inputPath".');
    }

    final files = directory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList()
      // Sorted so a repeated token name resolves deterministically rather
      // than depending on filesystem enumeration order.
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
