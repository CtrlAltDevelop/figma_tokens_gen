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
    expect(source, contains("import 'package:material_ui/material_ui.dart';"));
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

  test('palette keys are strings, so a digit-leading token is not escaped', () {
    final source = const DartColorsEmitter().emit(
      TokenSet([
        const TokenCategory(
          name: 'gray',
          tokens: [ColorToken(name: '500', argb: 0xFFE5E7EB)],
        ),
      ]),
    );

    // r'$500' would be read as string interpolation and fail to compile.
    expect(source, contains("'500': Color(0xFFE5E7EB),"));
    expect(source, isNot(contains(r"'$500'")));
    expect(source, contains('static const Color gray500 = Color(0xFFE5E7EB);'));
  });

  test('palette keys escape characters that would break the literal', () {
    final source = const DartColorsEmitter().emit(
      TokenSet([
        const TokenCategory(
          name: 'brand',
          tokens: [ColorToken(name: r'a$b', argb: 0xFF000000)],
        ),
      ]),
    );

    expect(source, contains(r"'a\$b': Color(0xFF000000),"));
  });

  test('the material import can be pointed back at flutter/material', () {
    final source = const DartColorsEmitter(
      materialImport: DartColorsEmitter.legacyMaterialImport,
    ).emit(_tokens);

    expect(source, contains("import 'package:flutter/material.dart';"));
    expect(source, isNot(contains('material_ui')));
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
      emitter.emit(_tokens),
      contains('abstract final class BrandPalette'),
    );
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

  test('a nested token path becomes one camelCase member', () {
    final source = const DartColorsEmitter().emit(
      TokenSet([
        const TokenCategory(
          name: 'color',
          tokens: [ColorToken(name: 'brand/primary', argb: 0xFF3B5BFF)],
        ),
      ]),
    );

    expect(
      source,
      contains('static const Color colorBrandPrimary = Color(0xFF3B5BFF);'),
    );
    expect(source, contains("'brandPrimary': Color(0xFF3B5BFF),"));
  });

  test('colliding names are made unique so the output compiles', () {
    // Flattening makes this reachable: `brand/primary` and `brandPrimary`
    // both ask for `colorBrandPrimary`, and duplicate keys in a const map
    // literal are a compile error outright.
    final source = const DartColorsEmitter().emit(
      TokenSet([
        const TokenCategory(
          name: 'color',
          tokens: [
            ColorToken(name: 'brand/primary', argb: 0xFF000001),
            ColorToken(name: 'brandPrimary', argb: 0xFF000002),
          ],
        ),
      ]),
    );

    expect(source, contains('Color colorBrandPrimary = Color(0xFF000001);'));
    expect(source, contains('Color colorBrandPrimary2 = Color(0xFF000002);'));
    expect(source, contains("'brandPrimary': Color(0xFF000001),"));
    expect(source, contains("'brandPrimary2': Color(0xFF000002),"));
    expect(source, contains('Renamed to'), reason: 'renames are visible');
  });

  test('the same palette key may be reused in a different category', () {
    final source = const DartColorsEmitter().emit(
      TokenSet([
        const TokenCategory(
          name: 'light',
          tokens: [ColorToken(name: 'bg', argb: 0xFFFFFFFF)],
        ),
        const TokenCategory(
          name: 'dark',
          tokens: [ColorToken(name: 'bg', argb: 0xFF000000)],
        ),
      ]),
    );

    expect(source, contains("'bg': Color(0xFFFFFFFF),"));
    expect(source, contains("'bg': Color(0xFF000000),"));
    expect(source, isNot(contains('bg2')));
  });

  test('a quote or newline in the import cannot break the import line', () {
    // Palette keys are normalised by Naming before they get here, so the
    // literal escaping exists for the one string that reaches the output
    // verbatim: the --material-import value.
    final source = const DartColorsEmitter(
      materialImport: "package:a'b\nc/d.dart",
    ).emit(_tokens);

    expect(source, contains(r"import 'package:a\'b\nc/d.dart';"));
  });
}
