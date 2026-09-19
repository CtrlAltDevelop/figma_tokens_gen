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

  group('nested groups', () {
    test('flattens a group below the category into the token name', () {
      // What Figma's native Variables export writes for `color/brand/*`.
      final tokens = _parser.parseJson(r'''
      {
        "color": {
          "brand": {
            "primary": {"$value": "#3B5BFF", "$type": "color"},
            "onPrimary": {"$value": "#FFFFFF", "$type": "color"}
          },
          "surface": {"$value": "#F7F8FA", "$type": "color"}
        }
      }
      ''');

      expect(tokens.categories.single.name, 'color');
      expect(tokens.categories.single.tokens.map((t) => t.name), [
        'brand/primary',
        'brand/onPrimary',
        'surface',
      ]);
      expect(tokens.colorCount, 3);
    });

    test('descends to any depth', () {
      final tokens = _parser.parseJson(r'''
      {"a": {"b": {"c": {"d": {"$value": "#010203"}}}}}
      ''');

      expect(tokens.categories.single.tokens.single.name, 'b/c/d');
      expect(tokens.categories.single.tokens.single.argb, 0xFF010203);
    });

    test('a bare rgb map is a value, not a group to descend into', () {
      final tokens = _parser.parseJson('''
      {"primary": {"main": {"r": 26, "g": 43, "b": 60}}}
      ''');

      expect(tokens.categories.single.tokens.single.argb, 0xFF1A2B3C);
    });

    test('warns about a token at the root, which has no category', () {
      final tokens = _parser.parseJson(r'''
      {"white": {"$value": "#FFFFFF"}, "text": {"soft": "#112233"}}
      ''');

      expect(tokens.categories.map((c) => c.name), ['text']);
      expect(tokens.warnings.single, contains('"white"'));
    });

    test('merges nested groups across documents rather than replacing', () {
      final tokens = _parser.parseDocuments([
        _parser.documentOf('{"color": {"brand": {"primary": "#000000"}}}'),
        _parser.documentOf('{"color": {"brand": {"accent": "#FFFFFF"}}}'),
      ]);

      expect(tokens.categories.single.tokens.map((t) => t.name), [
        'brand/primary',
        'brand/accent',
      ]);
    });

    test('parseDocuments does not modify the documents it is given', () {
      final first = _parser.documentOf(
        '{"color": {"brand": {"a": "#000000"}}}',
      );
      final second = _parser.documentOf(
        '{"color": {"brand": {"b": "#FFFFFF"}}}',
      );

      _parser.parseDocuments([first, second]);

      final brand = (first['color']! as Map)['brand']! as Map;
      expect(brand.keys, ['a'], reason: 'the input map must be untouched');
    });
  });

  group('aliases', () {
    test('follows a {group.token} reference', () {
      final tokens = _parser.parseJson(r'''
      {
        "primitive": {"blue500": {"$value": "#3B5BFF", "$type": "color"}},
        "action": {"default": {"$value": "{primitive.blue500}"}}
      }
      ''');

      expect(tokens.warnings, isEmpty);
      expect(tokens.categories.last.tokens.single.argb, 0xFF3B5BFF);
    });

    test('resolves across documents, so layers can live in separate files', () {
      // The common Tokens Studio split: primitives in one file, the semantic
      // layer that points at them in another.
      final tokens = _parser.parseDocuments([
        _parser.documentOf('{"primitive": {"blue500": "#3B5BFF"}}'),
        _parser.documentOf(
          r'{"action": {"main": {"$value": "{primitive.blue500}"}}}',
        ),
      ]);

      expect(tokens.warnings, isEmpty);
      expect(tokens.categories.last.tokens.single.argb, 0xFF3B5BFF);
    });

    test('follows a chain, and slash-separated paths, into nested groups', () {
      final tokens = _parser.parseJson(r'''
      {
        "primitive": {"blue": {"500": "#3B5BFF"}},
        "middle": {"link": {"$value": "{primitive/blue/500}"}},
        "action": {"main": {"$value": "{middle.link}"}}
      }
      ''');

      expect(tokens.warnings, isEmpty);
      expect(tokens.categories.last.tokens.single.argb, 0xFF3B5BFF);
    });

    test('warns and skips when the target does not exist', () {
      final tokens = _parser.parseJson(r'''
      {
        "primitive": {"blue500": "#3B5BFF"},
        "action": {"main": {"$value": "{primitive.blue600}"}}
      }
      ''');

      expect(tokens.categories.map((c) => c.name), ['primitive']);
      expect(tokens.warnings.single, contains('{primitive.blue600}'));
    });

    test('warns and skips a reference to a group', () {
      final tokens = _parser.parseJson(r'''
      {
        "primitive": {"blue": {"500": "#3B5BFF"}},
        "action": {"main": {"$value": "{primitive.blue}"}}
      }
      ''');

      expect(tokens.categories.map((c) => c.name), ['primitive']);
      expect(tokens.warnings.single, contains('group'));
    });

    test('warns and skips a cycle instead of looping forever', () {
      final tokens = _parser.parseJson(r'''
      {
        "a": {"one": {"$value": "{b.two}"}},
        "b": {"two": {"$value": "{a.one}"}}
      }
      ''');

      expect(tokens.categories, isEmpty);
      expect(tokens.warnings, hasLength(2));
      expect(tokens.warnings.first, contains('cycle'));
    });

    test('can be turned off, leaving a reference unparseable', () {
      const literal = TokenParser(resolveAliases: false);
      final tokens = literal.parseJson(r'''
      {
        "primitive": {"blue500": "#3B5BFF"},
        "action": {"main": {"$value": "{primitive.blue500}"}}
      }
      ''');

      expect(tokens.categories.map((c) => c.name), ['primitive']);
      expect(tokens.warnings, isEmpty, reason: 'not treated as an alias');
    });
  });

  group('token types', () {
    test('a token declaring another type is not a colour', () {
      // Bare hex is accepted without its `#`, so these values are all valid
      // hex digits and would each come out as a colour if the type were not
      // consulted: 700 -> #770000, 1234 -> #11223344, 128 -> #112288.
      final tokens = _parser.parseJson(r'''
      {
        "font": {
          "weight": {"$value": "700", "$type": "fontWeight"},
          "size":   {"value": "1234", "type": "fontSizes"}
        },
        "space": {"lg": {"$value": "128", "$type": "dimension"}},
        "color": {"red": {"$value": "#ff0000", "$type": "color"}}
      }
      ''');

      expect(tokens.categories.map((c) => c.name), ['color']);
      expect(tokens.warnings, isEmpty);
    });

    test('a type declared on the group covers every token below it', () {
      final tokens = _parser.parseJson(r'''
      {
        "weights": {
          "$type": "fontWeight",
          "body": {"$value": "400"},
          "deep": {"bold": {"$value": "700"}}
        },
        "brand": {"$type": "color", "main": {"$value": "1A2B3C"}}
      }
      ''');

      expect(tokens.categories.map((c) => c.name), ['brand']);
      expect(tokens.categories.single.tokens.single.argb, 0xFF1A2B3C);
    });

    test('a token type overrides the group type', () {
      final tokens = _parser.parseJson(r'''
      {
        "mixed": {
          "$type": "dimension",
          "gap":   {"$value": "128"},
          "brand": {"$value": "1A2B3C", "$type": "color"}
        }
      }
      ''');

      expect(tokens.categories.single.tokens.map((t) => t.name), ['brand']);
    });

    test('an alias to a non-colour token is not a colour', () {
      final tokens = _parser.parseJson(r'''
      {
        "font": {"$type": "fontWeight", "bold": {"$value": "700"}},
        "text": {"weight": {"$value": "{font.bold}"}, "ok": "#111111"}
      }
      ''');

      expect(tokens.categories.single.tokens.map((t) => t.name), ['ok']);
      expect(tokens.warnings, isEmpty);
    });

    test('an alias still follows a typed colour', () {
      final tokens = _parser.parseJson(r'''
      {
        "base": {"$type": "color", "blue": {"$value": "1A2B3C"}},
        "text": {"link": {"$value": "{base.blue}"}}
      }
      ''');

      expect(tokens.categories.last.tokens.single.argb, 0xFF1A2B3C);
    });

    test('a type of "color" is matched regardless of case', () {
      final tokens = _parser.parseJson(
        r'{"c": {"a": {"value": "#111111", "type": "Color"}}}',
      );

      expect(tokens.colorCount, 1);
    });
  });

  group('root-level tokens', () {
    test('a bare colour at the root is reported, not dropped silently', () {
      final tokens = _parser.parseJson(
        r'{"white": "#FFFFFF", "alias": "{c.a}", "c": {"a": "#000000"}}',
      );

      expect(tokens.colorCount, 1);
      expect(
        tokens.warnings,
        allOf(hasLength(2), everyElement(contains('root of the document'))),
      );
    });

    test('a root string that is not a colour is left alone', () {
      final tokens = _parser.parseJson(
        r'{"name": "Brand", "version": "100", "c": {"a": "#000000"}}',
      );

      expect(tokens.warnings, isEmpty);
    });
  });
}
