import 'dart:io';

import 'package:args/args.dart';
import 'package:figma_tokens_gen/figma_tokens_gen.dart';
import 'package:path/path.dart' as p;

const _version = '1.2.1';

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
  final check = args.flag('check');
  final converter = TokenConverter(
    emitter: DartColorsEmitter(
      className: args.option('class-name')!,
      paletteClassName: args.option('palette-class-name')!,
      fileName: args.option('file-name')!,
      materialImport: args.option('material-import')!,
      emitPalettes: args.flag('palettes'),
    ),
  );

  try {
    final result = await converter.convert(
      inputPath: args.option('input')!,
      outputPath: args.option('output')!,
      checkOnly: check,
    );
    _reportWarnings(result.warnings);
    if (result.isStale) {
      _fail(
        '${_shown(result.outputFile)} is out of date. '
        'Run figma_tokens_gen without --check to regenerate it.',
      );
      return;
    }
    if (!quiet) _report(result, check: check);
    if (args.flag('strict') && result.warnings.isNotEmpty) {
      _fail('${result.warnings.length} warning(s) with --strict.');
    }
  } on ConversionException catch (e) {
    _fail(e.message);
  } on TokenParseException catch (e) {
    _fail('$e');
  } on FileSystemException catch (e) {
    _fail('${e.message} (${e.path})');
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
  ..addOption(
    'material-import',
    defaultsTo: DartColorsEmitter.defaultMaterialImport,
    help:
        'Import the generated file uses for Color. Pass\n'
        '${DartColorsEmitter.legacyMaterialImport} on Flutter below 3.47.',
    valueHelp: 'uri',
  )
  ..addFlag(
    'palettes',
    defaultsTo: true,
    help: 'Also emit Map<String, Color> palettes grouped by category.',
  )
  ..addFlag(
    'strict',
    negatable: false,
    help:
        'Exit non-zero if any token was skipped, e.g. a broken alias.\n'
        'Warnings are printed either way.',
  )
  ..addFlag(
    'check',
    negatable: false,
    help:
        'Write nothing; exit non-zero if the generated file is missing or\n'
        'out of date. For CI.',
  )
  ..addFlag(
    'quiet',
    abbr: 'q',
    negatable: false,
    help: 'Suppress progress output. Warnings are still printed.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.')
  ..addFlag('version', negatable: false, help: 'Print the version.');

String _usage(ArgParser parser) => '''
Generate Flutter Color constants from Figma design-token JSON.

Usage: dart run figma_tokens_gen [options]

${parser.usage}''';

/// Printed even under `--quiet`: a skipped token is not progress noise, it is
/// a token missing from the generated file.
void _reportWarnings(List<String> warnings) {
  for (final warning in warnings) {
    stderr.writeln('${_paint(stderr, '33', '⚠')} $warning');
  }
}

void _fail(String message) {
  stderr.writeln('${_paint(stderr, '31', '✗')} $message');
  exitCode = 1;
}

void _report(ConversionResult result, {required bool check}) {
  final files = result.inputFiles.length;
  stdout.writeln(
    _ok('Read ${_bold('$files')} token file${files == 1 ? '' : 's'}'),
  );
  for (final file in result.inputFiles) {
    stdout.writeln('    ${_dim(stdout, _shown(file))}');
  }
  stdout.writeln(
    _ok(
      '${check ? 'Up to date' : 'Wrote'} ${_bold('${result.colorCount}')} '
      'colours in ${_bold('${result.categoryCount}')} '
      'categor${result.categoryCount == 1 ? 'y' : 'ies'}',
    ),
  );
  stdout.writeln('    ${_dim(stdout, _shown(result.outputFile))}');
}

// --- output styling --------------------------------------------------------

/// Colour only where it will be read by a person: a terminal, with `NO_COLOR`
/// (https://no-color.org) unset.
bool _colour(Stdout out) =>
    out.hasTerminal && !Platform.environment.containsKey('NO_COLOR');

String _paint(Stdout out, String code, String text) =>
    _colour(out) ? '\x1B[${code}m$text\x1B[0m' : text;

String _ok(String text) => '${_paint(stdout, '32', '✓')} $text';
String _dim(Stdout out, String text) => _paint(out, '2', text);
String _bold(String text) => _paint(stdout, '1', text);

/// A path as the user would type it: relative to where they are.
String _shown(String path) {
  final relative = p.relative(path);
  return relative.startsWith('..') ? path : relative;
}
