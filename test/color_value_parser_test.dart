import 'package:figma_tokens_gen/figma_tokens_gen.dart';
import 'package:test/test.dart';

void main() {
  group('hex strings', () {
    test('parses 6-digit hex as fully opaque', () {
      expect(ColorValueParser.parse('#1A2B3C'), 0xFF1A2B3C);
      expect(ColorValueParser.parse('1a2b3c'), 0xFF1A2B3C);
    });

    test('moves trailing alpha to the front for 8-digit hex', () {
      expect(ColorValueParser.parse('#1A2B3C80'), 0x801A2B3C);
    });

    test('expands shorthand hex', () {
      expect(ColorValueParser.parse('#ABC'), 0xFFAABBCC);
      expect(ColorValueParser.parse('#ABCD'), 0xDDAABBCC);
    });

    test('rejects malformed input', () {
      expect(ColorValueParser.parse('#12345'), isNull);
      expect(ColorValueParser.parse('not-a-colour'), isNull);
      expect(ColorValueParser.parse(''), isNull);
    });
  });

  group('maps', () {
    test('reads the hex field', () {
      expect(ColorValueParser.parse({'hex': '#1A2B3C'}), 0xFF1A2B3C);
    });

    test('overlays a separate alpha channel onto a hex value', () {
      expect(ColorValueParser.parse({'hex': '#1A2B3C', 'a': 0.5}), 0x801A2B3C);
    });

    test('reads normalised rgb channels', () {
      expect(ColorValueParser.parse({'r': 1, 'g': 0, 'b': 0}), 0xFFFF0000);
    });

    test('reads 0-255 rgb channels', () {
      expect(ColorValueParser.parse({'r': 26, 'g': 43, 'b': 60}), 0xFF1A2B3C);
    });

    test('overlays a W3C alpha onto a hex that carries none', () {
      // The shape Figma's variable export writes for a translucent colour.
      expect(
        ColorValueParser.parse({
          'colorSpace': 'srgb',
          'components': [0.2, 0.4, 0.8],
          'alpha': 0.5,
          'hex': '#3366CC',
        }),
        0x803366CC,
      );
    });

    test('reads sRGB components when there is no hex', () {
      expect(
        ColorValueParser.parse({
          'colorSpace': 'srgb',
          'components': [1, 0, 0],
          'alpha': 0.5,
        }),
        0x80FF0000,
      );
      expect(
        ColorValueParser.parse({
          'colorSpace': 'srgb',
          'components': [0, 0, 1],
        }),
        0xFF0000FF,
      );
    });

    test('will not guess at components in another colour space', () {
      expect(
        ColorValueParser.parse({
          'colorSpace': 'display-p3',
          'components': [1, 0, 0],
        }),
        isNull,
      );
      expect(
        ColorValueParser.parse({
          'colorSpace': 'display-p3',
          'components': [1, 0, 0],
          'hex': '#FF0000',
        }),
        0xFFFF0000,
        reason: 'the hex is still a usable fallback',
      );
    });

    test('returns null when channels are missing', () {
      expect(ColorValueParser.parse({'r': 1, 'g': 0}), isNull);
      expect(ColorValueParser.parse(<String, Object?>{}), isNull);
    });
  });

  test('returns null for unsupported types', () {
    expect(ColorValueParser.parse(null), isNull);
    expect(ColorValueParser.parse(42), isNull);
    expect(ColorValueParser.parse(<String>['#fff']), isNull);
  });

  test('a hash anywhere but the front is not a colour', () {
    // Stripping every `#` would have read this as the valid hex `123456`.
    expect(ColorValueParser.parse('1#23456'), isNull);
    expect(ColorValueParser.parse('#1A2B3C'), 0xFF1A2B3C);
    expect(ColorValueParser.parse('1A2B3C'), 0xFF1A2B3C);
  });
}
