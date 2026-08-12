import 'dart:io';

import 'package:args/args.dart';
import 'package:figma_tokens_gen/figma_tokens_gen.dart';

const _version = '0.1.0';

Future<void> main(List<String> arguments) async {
  final parser = _buildArgParser();

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln();
    stderr.writeln(_usage(parser));
    exitCode = 64; // EX_USAGE
    return;
  }

  if (args.flag('help')) {
    stdout.writeln(_usage(parser));
    return;
  }
  if (args.flag('version')) {
    stdout.writeln('figma_tokens_gen $_version');
    return;
  }

  final quiet = args.flag('quiet');
  final converter = TokenConverter(
    emitter: DartColorsEmitter(
      className: args.option('class-name')!,
      paletteClassName: args.option('palette-class-name')!,
      fileName: args.option('file-name')!,
      emitPalettes: args.flag('palettes'),
    ),
  );

  try {
    final result = await converter.convert(
      inputPath: args.option('input')!,
      outputPath: args.option('output')!,
    );
    if (!quiet) _report(result);
  } on ConversionException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exitCode = 1;
  } on TokenParseException catch (e) {
    stderr.writeln('Error: $e');
    exitCode = 1;
  } on FileSystemException catch (e) {
    stderr.writeln('Error: ${e.message} (${e.path})');
    exitCode = 1;
  }
}

ArgParser _buildArgParser() => ArgParser()
  ..addOption(
    'input',
    abbr: 'i',
    defaultsTo: 'tokens',
    help: 'Directory (searched recursively) or single Figma token JSON file.',
    valueHelp: 'path',
  )
  ..addOption(
    'output',
    abbr: 'o',
    defaultsTo: 'lib/generated/theme',
    help: 'Directory the generated Dart file is written to.',
    valueHelp: 'path',
  )
  ..addOption(
    'class-name',
    defaultsTo: DartColorsEmitter.defaultClassName,
    help: 'Name of the generated colour constants class.',
    valueHelp: 'name',
  )
  ..addOption(
    'palette-class-name',
    defaultsTo: DartColorsEmitter.defaultPaletteClassName,
    help: 'Name of the generated palette-map class.',
    valueHelp: 'name',
  )
  ..addOption(
    'file-name',
    defaultsTo: DartColorsEmitter.defaultFileName,
    help: 'Name of the generated file.',
    valueHelp: 'file.dart',
  )
  ..addFlag(
    'palettes',
    defaultsTo: true,
    help: 'Also emit Map<String, Color> palettes grouped by category.',
  )
  ..addFlag('quiet', abbr: 'q', negatable: false, help: 'Suppress output.')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.')
  ..addFlag('version', negatable: false, help: 'Print the version.');

String _usage(ArgParser parser) => '''
Generate Flutter Color constants from Figma design-token JSON.

Usage: dart run figma_tokens_gen [options]

${parser.usage}''';

void _report(ConversionResult result) {
  stdout.writeln('Read ${result.inputFiles.length} token file(s):');
  for (final file in result.inputFiles) {
    stdout.writeln('  $file');
  }
  stdout.writeln(
    'Wrote ${result.colorCount} colours across ${result.categoryCount} '
    'categories to ${result.outputFile}',
  );
}
