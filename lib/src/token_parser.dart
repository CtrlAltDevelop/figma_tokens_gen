import 'dart:convert';

import 'color_value_parser.dart';
import 'models/color_token.dart';

/// Thrown when a token file cannot be understood.
class TokenParseException implements Exception {
  const TokenParseException(this.message, {this.source});

  final String message;

  /// The file or document the failure came from, when known.
  final String? source;

  @override
  String toString() =>
      'TokenParseException: $message${source == null ? '' : ' (in $source)'}';
}

/// Turns raw Figma token JSON into a [TokenSet].
///
/// Deliberately has no knowledge of the filesystem so it can be unit-tested
/// against string fixtures and reused by callers that fetch tokens over HTTP.
class TokenParser {
  const TokenParser({this.ignoredKeys = defaultIgnoredKeys});

  /// Top-level keys that carry plugin metadata rather than design tokens.
  static const Set<String> defaultIgnoredKeys = {
    r'$extensions',
    r'$themes',
    r'$metadata',
    r'$description',
    r'$type',
  };

  final Set<String> ignoredKeys;

  /// Parses a single JSON document.
  TokenSet parseJson(String json, {String? source}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw TokenParseException('Invalid JSON: ${e.message}', source: source);
    }
    if (decoded is! Map<String, Object?>) {
      throw TokenParseException(
        'Expected a JSON object at the root, got ${decoded.runtimeType}',
        source: source,
      );
    }
    return parseMap(decoded);
  }

  /// Parses an already-decoded token document.
  TokenSet parseMap(Map<String, Object?> document) =>
      merge([_categoriesOf(document)]);

  /// Merges several parsed documents, later categories extending earlier ones
  /// of the same name. Token order is preserved; a repeated token name wins
  /// from the last document that declares it.
  TokenSet merge(Iterable<List<TokenCategory>> documents) {
    final byName = <String, Map<String, ColorToken>>{};
    for (final categories in documents) {
      for (final category in categories) {
        final bucket = byName.putIfAbsent(category.name, () => {});
        for (final token in category.tokens) {
          bucket[token.name] = token;
        }
      }
    }
    return TokenSet([
      for (final entry in byName.entries)
        TokenCategory(
          name: entry.key,
          tokens: entry.value.values.toList(growable: false),
        ),
    ]);
  }

  /// Exposed so callers can merge across files without re-encoding to JSON.
  List<TokenCategory> categoriesOf(String json, {String? source}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw TokenParseException('Invalid JSON: ${e.message}', source: source);
    }
    if (decoded is! Map<String, Object?>) {
      throw TokenParseException(
        'Expected a JSON object at the root, got ${decoded.runtimeType}',
        source: source,
      );
    }
    return _categoriesOf(decoded);
  }

  List<TokenCategory> _categoriesOf(Map<String, Object?> document) {
    final categories = <TokenCategory>[];
    for (final entry in document.entries) {
      if (ignoredKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value is! Map<String, Object?>) continue;
      final tokens = _tokensOf(value);
      if (tokens.isNotEmpty) {
        categories.add(TokenCategory(name: entry.key, tokens: tokens));
      }
    }
    return categories;
  }

  List<ColorToken> _tokensOf(Map<String, Object?> category) {
    final tokens = <ColorToken>[];
    for (final entry in category.entries) {
      if (ignoredKeys.contains(entry.key)) continue;
      final argb = _valueOf(entry.value);
      if (argb != null) {
        tokens.add(ColorToken(name: entry.key, argb: argb));
      }
    }
    return tokens;
  }

  /// Resolves one token entry to a colour, accepting the three shapes seen in
  /// real exports: a DTCG wrapper (`{"$value": ...}`), the legacy wrapper
  /// (`{"value": ...}`), and a bare value (`"#RRGGBB"` or an rgb map).
  int? _valueOf(Object? entry) {
    if (entry is Map<String, Object?>) {
      if (entry.containsKey(r'$value')) {
        return ColorValueParser.parse(entry[r'$value']);
      }
      if (entry.containsKey('value')) {
        return ColorValueParser.parse(entry['value']);
      }
    }
    return ColorValueParser.parse(entry);
  }
}
