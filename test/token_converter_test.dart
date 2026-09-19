import 'dart:io';

import 'package:figma_tokens_gen/figma_tokens_gen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late String input;
  late String output;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('figma_tokens_gen_test');
    input = p.join(sandbox.path, 'tokens');
    output = p.join(sandbox.path, 'out');
    Directory(input).createSync(recursive: true);
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  void writeTokens(String name, String contents) {
    File(p.join(input, name)).writeAsStringSync(contents);
  }

  test('converts a directory of token files into one Dart file', () async {
    writeTokens('a.json', '{"primary": {"main": {"\$value": "#1A2B3C"}}}');
    writeTokens('b.json', '{"text": {"soft": {"\$value": "#AABBCC"}}}');

    final result = await TokenConverter().convert(
      inputPath: input,
      outputPath: output,
    );

    expect(result.inputFiles, hasLength(2));
    expect(result.colorCount, 2);
    expect(result.categoryCount, 2);
    expect(File(result.outputFile).existsSync(), isTrue);
    expect(
      File(result.outputFile).readAsStringSync(),
      contains('static const Color primaryMain = Color(0xFF1A2B3C);'),
    );
  });

  test('accepts a single file as the input path', () async {
    writeTokens('a.json', '{"primary": {"main": {"\$value": "#1A2B3C"}}}');

    final result = await TokenConverter().convert(
      inputPath: p.join(input, 'a.json'),
      outputPath: output,
    );

    expect(result.inputFiles, hasLength(1));
  });

  test('creates the output directory when missing', () async {
    writeTokens('a.json', '{"primary": {"main": {"\$value": "#1A2B3C"}}}');

    final nested = p.join(output, 'deeply', 'nested');
    await TokenConverter().convert(inputPath: input, outputPath: nested);

    expect(Directory(nested).existsSync(), isTrue);
  });

  test('reads files in a stable order so merges are deterministic', () async {
    writeTokens('z.json', '{"primary": {"main": {"\$value": "#FFFFFF"}}}');
    writeTokens('a.json', '{"primary": {"main": {"\$value": "#000000"}}}');

    final result = await TokenConverter().convert(
      inputPath: input,
      outputPath: output,
    );

    expect(result.inputFiles.map(p.basename), ['a.json', 'z.json']);
    expect(
      File(result.outputFile).readAsStringSync(),
      contains('Color(0xFFFFFFFF)'),
      reason: 'z.json sorts last and therefore wins',
    );
  });

  test('throws when the input path does not exist', () {
    expect(
      () => TokenConverter().convert(
        inputPath: p.join(sandbox.path, 'nope'),
        outputPath: output,
      ),
      throwsA(isA<ConversionException>()),
    );
  });

  test('throws when no json files are present', () {
    expect(
      () => TokenConverter().convert(inputPath: input, outputPath: output),
      throwsA(isA<ConversionException>()),
    );
  });

  test('throws when json files contain no colours', () {
    writeTokens('a.json', '{"spacing": {"sm": {"\$value": 4}}}');

    expect(
      () => TokenConverter().convert(inputPath: input, outputPath: output),
      throwsA(isA<ConversionException>()),
    );
  });

  test('resolves an alias whose target is in another file', () async {
    writeTokens('1_primitive.json', '{"primitive": {"blue500": "#3B5BFF"}}');
    writeTokens(
      '2_semantic.json',
      r'{"action": {"main": {"$value": "{primitive.blue500}"}}}',
    );

    final result = await TokenConverter().convert(
      inputPath: input,
      outputPath: output,
    );

    expect(result.warnings, isEmpty);
    expect(
      File(result.outputFile).readAsStringSync(),
      contains('static const Color actionMain = Color(0xFF3B5BFF);'),
    );
  });

  test('reports a broken alias without failing the run', () async {
    writeTokens('a.json', '{"primary": {"main": "#1A2B3C"}}');
    writeTokens(
      'b.json',
      r'{"action": {"main": {"$value": "{primary.nope}"}}}',
    );

    final result = await TokenConverter().convert(
      inputPath: input,
      outputPath: output,
    );

    expect(result.colorCount, 1, reason: 'the good token still generates');
    expect(result.warnings.single, contains('{primary.nope}'));
  });

  test('nested groups across the tree end up in one file', () async {
    writeTokens(
      'a.json',
      r'{"color": {"brand": {"primary": {"$value": "#3B5BFF"}}}}',
    );

    final result = await TokenConverter().convert(
      inputPath: input,
      outputPath: output,
    );

    expect(
      File(result.outputFile).readAsStringSync(),
      contains('static const Color colorBrandPrimary = Color(0xFF3B5BFF);'),
    );
  });

  test('a file whose only tokens are broken aliases explains why', () {
    writeTokens('a.json', r'{"action": {"main": {"$value": "{nope.nope}"}}}');

    expect(
      () => TokenConverter().convert(inputPath: input, outputPath: output),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.message,
          'message',
          contains('{nope.nope}'),
        ),
      ),
    );
  });

  test('skips Tokens Studio bookkeeping files in a directory', () async {
    // `$themes.json` is an array, which is not a token document and used to
    // fail the whole run.
    writeTokens('a.json', '{"primary": {"main": {"\$value": "#1A2B3C"}}}');
    writeTokens(r'$themes.json', '[{"id": "x", "name": "Base"}]');
    writeTokens(r'$metadata.json', '{"tokenSetOrder": ["a"]}');

    final result = await TokenConverter().convert(
      inputPath: input,
      outputPath: output,
    );

    expect(result.inputFiles.map(p.basename), ['a.json']);
    expect(result.colorCount, 1);
  });
}
