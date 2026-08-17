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
}
