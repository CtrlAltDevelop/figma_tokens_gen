import 'package:figma_tokens_gen/figma_tokens_gen.dart';
import 'package:test/test.dart';

final _tokens = TokenSet([
  const TokenCategory(
    name: 'primary',
    tokens: [
      ColorToken(name: 'main', argb: 0xFF1A2B3C),
      ColorToken(name: 'extraLight', argb: 0x80AABBCC),
    ],
  ),
  const TokenCategory(name: 'empty', tokens: []),
]);

void main() {
  test('emits constants with generated-code markers', () {
    final source = const DartColorsEmitter().emit(_tokens);

    expect(source, contains('// GENERATED CODE - DO NOT MODIFY BY HAND'));
    expect(source, contains("import 'package:flutter/material.dart';"));
    expect(source, contains('abstract final class AppColors {'));
    expect(
      source,
      contains('static const Color primaryMain = Color(0xFF1A2B3C);'),
    );
    expect(
      source,
      contains('static const Color primaryExtraLight = Color(0x80AABBCC);'),
    );
  });

  test('emits palette maps by default', () {
    final source = const DartColorsEmitter().emit(_tokens);

    expect(source, contains('abstract final class AppColorPalette {'));
    expect(source, contains('static const Map<String, Color> primary = {'));
    expect(source, contains("'extraLight': Color(0x80AABBCC),"));
  });

  test('palettes can be disabled', () {
    final source = const DartColorsEmitter(emitPalettes: false).emit(_tokens);

    expect(source, isNot(contains('AppColorPalette')));
  });

  test('class and file names are configurable', () {
    const emitter = DartColorsEmitter(
      className: 'BrandColors',
      paletteClassName: 'BrandPalette',
      fileName: 'brand_colors.dart',
    );

    expect(emitter.fileName, 'brand_colors.dart');
    expect(emitter.emit(_tokens), contains('abstract final class BrandColors'));
    expect(
        emitter.emit(_tokens), contains('abstract final class BrandPalette'));
  });

  test('skips empty categories', () {
    final source = const DartColorsEmitter().emit(_tokens);

    expect(source, isNot(contains('// empty')));
  });

  test('output contains no timestamp, so reruns produce no spurious diff', () {
    final first = const DartColorsEmitter().emit(_tokens);
    final second = const DartColorsEmitter().emit(_tokens);

    expect(first, second);
  });
}
