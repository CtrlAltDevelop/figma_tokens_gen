import 'package:figma_tokens_gen/figma_tokens_gen.dart';
import 'package:test/test.dart';

const _parser = TokenParser();

void main() {
  test('parses categories and tokens', () {
    final tokens = _parser.parseJson('''
    {
      "primary": {
        "main":  {"\$value": {"hex": "#1A2B3C"}, "\$type": "color"},
        "light": {"\$value": "#AABBCC"}
      },
      "text": {
        "soft": {"value": "#112233"}
      }
    }
    ''');

    expect(tokens.categories.map((c) => c.name), ['primary', 'text']);
    expect(tokens.colorCount, 3);
    expect(tokens.categories.first.tokens.first.argb, 0xFF1A2B3C);
    expect(tokens.categories.last.tokens.single.name, 'soft');
  });

  test('reads current and older export shapes mixed in one category', () {
    // A partly re-exported token set: newer tokens carry `$value`, ones the
    // plugin has not rewritten yet still carry `value` or a bare string.
    final tokens = _parser.parseJson('''
    {
      "primary": {
        "dtcg":   {"\$value": {"hex": "#3B5BFF"}, "\$type": "color"},
        "legacy": {"value": "#8FA3FF"},
        "bare":   "#E4E9FF"
      }
    }
    ''');

    expect(tokens.colorCount, 3);
    expect(tokens.categories.single.tokens.map((t) => t.argb), [
      0xFF3B5BFF,
      0xFF8FA3FF,
      0xFFE4E9FF,
    ]);
  });

  test('skips plugin metadata keys', () {
    final tokens = _parser.parseJson('''
    {
      "\$extensions": {"anything": {"\$value": "#FFFFFF"}},
      "\$themes": {"dark": {"\$value": "#000000"}},
      "primary": {"main": {"\$value": "#1A2B3C"}}
    }
    ''');

    expect(tokens.categories.map((c) => c.name), ['primary']);
  });

  test('skips entries that are not colours', () {
    final tokens = _parser.parseJson('''
    {
      "spacing": {"sm": {"\$value": 4, "\$type": "dimension"}},
      "primary": {"main": {"\$value": "#1A2B3C"}}
    }
    ''');

    expect(tokens.categories.map((c) => c.name), ['primary']);
  });

  test('merge extends categories and lets later documents win', () {
    final base = _parser.categoriesOf(
      '{"primary": {"main": "#000000", "light": {"\$value": "#111111"}}}',
    );
    final override = _parser.categoriesOf(
      '{"primary": {"main": {"\$value": "#FFFFFF"}}, '
      '"text": {"soft": {"\$value": "#222222"}}}',
    );

    final merged = _parser.merge([base, override]);

    expect(merged.categories.map((c) => c.name), ['primary', 'text']);
    final primary = merged.categories.first.tokens;
    expect(primary.map((t) => t.name), ['main', 'light']);
    expect(primary.first.argb, 0xFFFFFFFF, reason: 'later document wins');
  });

  test('throws a descriptive error on invalid JSON', () {
    expect(
      () => _parser.parseJson('{ not json', source: 'themes.json'),
      throwsA(
        isA<TokenParseException>().having(
          (e) => e.toString(),
          'message',
          contains('themes.json'),
        ),
      ),
    );
  });

  test('throws when the root is not an object', () {
    expect(() => _parser.parseJson('[]'), throwsA(isA<TokenParseException>()));
  });
}
