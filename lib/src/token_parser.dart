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
///
/// Handles the two structures real exports use beyond a flat
/// category/token pair:
///
/// - **Nested groups**, to any depth. Figma's native Variables export writes
///   `color/brand/primary` as three levels of object; the leading key is the
///   category and the rest becomes the token name, so the member is
///   `colorBrandPrimary`.
/// - **Aliases**, the `{group.token}` references a semantic layer uses to
///   point at a primitive one. They resolve against every document passed to
///   [parseDocuments] together, so the primitive may live in another file.
///
/// A token that declares a type other than `color` — `$type` in the DTCG
/// shape, `type` in the legacy one, either set on the token or inherited from
/// a group — is not a colour and is left out. That matters because a bare hex
/// string is accepted without its `#`, so an untyped-looking `"700"` (a font
/// weight) or `"128"` (a spacing) would otherwise parse as a colour.
class TokenParser {
  const TokenParser({
    this.ignoredKeys = defaultIgnoredKeys,
    this.resolveAliases = true,
  });

  /// Top-level keys that carry plugin metadata rather than design tokens.
  static const Set<String> defaultIgnoredKeys = {
    r'$extensions',
    r'$themes',
    r'$metadata',
    r'$description',
    r'$type',
  };

  /// How many aliases may be followed before a chain is treated as broken.
  ///
  /// A cycle is caught outright; this only bounds pathological depth.
  static const int maxAliasHops = 32;

  final Set<String> ignoredKeys;

  /// Whether `{group.token}` values are followed to the token they name.
  ///
  /// Turn it off to treat a reference as an ordinary unparseable value, which
  /// is what versions before 1.1.0 did.
  final bool resolveAliases;

  static final RegExp _reference = RegExp(r'^\{([^{}]+)\}$');
  static final RegExp _referenceSeparator = RegExp(r'[./]');

  /// Parses a single JSON document.
  TokenSet parseJson(String json, {String? source}) =>
      parseDocuments([documentOf(json, source: source)]);

  /// Parses an already-decoded token document.
  TokenSet parseMap(Map<String, Object?> document) =>
      parseDocuments([document]);

  /// Decodes one document without interpreting it, for callers that want to
  /// hand several to [parseDocuments] at once.
  Map<String, Object?> documentOf(String json, {String? source}) {
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
    return decoded;
  }

  /// Parses several documents as one token set.
  ///
  /// Documents are deep-merged in iteration order — groups combine, and a
  /// token declared twice is taken from the last document that declares it —
  /// and only then resolved, so an alias can point at a token defined in an
  /// earlier or later file. Prefer this over [merge] for that reason; [merge]
  /// resolves each document on its own and cannot see across files.
  ///
  /// The inputs are not modified.
  TokenSet parseDocuments(Iterable<Map<String, Object?>> documents) {
    final merged = <String, Object?>{};
    for (final document in documents) {
      _mergeInto(merged, document);
    }
    return _resolve(merged);
  }

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
  ///
  /// Aliases resolve only within this one document; use [parseDocuments] when
  /// the target may be in another file.
  List<TokenCategory> categoriesOf(String json, {String? source}) =>
      parseJson(json, source: source).categories;

  // --- structure -----------------------------------------------------------

  /// Deep-merges [source] into [target], copying every map it takes so the
  /// caller's document is never aliased into the result — [parseDocuments]
  /// promises not to modify its inputs.
  void _mergeInto(Map<String, Object?> target, Map<String, Object?> source) {
    for (final entry in source.entries) {
      final existing = target[entry.key];
      final incoming = entry.value;
      if (_isGroup(existing) && _isGroup(incoming)) {
        _mergeInto(_asMap(existing)!, _asMap(incoming)!);
      } else {
        target[entry.key] = _copy(incoming);
      }
    }
  }

  static Object? _copy(Object? value) {
    final map = _asMap(value);
    if (map == null) return value;
    return <String, Object?>{
      for (final entry in map.entries) entry.key: _copy(entry.value),
    };
  }

  static Map<String, Object?>? _asMap(Object? value) =>
      value is Map<String, Object?> ? value : null;

  /// Whether a node holds child tokens rather than a value of its own.
  ///
  /// A bare colour map (`{"hex": …}`, `{"r": …}`) is a value, not a group,
  /// even though it carries neither wrapper key.
  static bool _isGroup(Object? value) {
    final map = _asMap(value);
    if (map == null) return false;
    if (map.containsKey(r'$value') || map.containsKey('value')) return false;
    return ColorValueParser.parse(map) == null;
  }

  TokenSet _resolve(Map<String, Object?> document) {
    final warnings = <String>[];
    final categories = <TokenCategory>[];

    for (final entry in document.entries) {
      if (ignoredKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value is String) {
        // A bare colour at the root is a token too; anything else — a title,
        // a version string — is not worth a warning.
        if (_looksLikeColour(value)) warnings.add(_rootTokenWarning(entry.key));
        continue;
      }
      if (value is! Map<String, Object?>) continue;

      if (!_isGroup(value)) {
        // A token at the root has no category to prefix its name with, which
        // is the one shape this generator cannot name. Say so rather than
        // dropping it silently.
        warnings.add(_rootTokenWarning(entry.key));
        continue;
      }

      final tokens = <ColorToken>[];
      _collect(
        group: value,
        path: const [],
        root: document,
        inheritedType: _groupType(document),
        category: entry.key,
        out: tokens,
        warnings: warnings,
      );
      if (tokens.isNotEmpty) {
        categories.add(
          TokenCategory(
            name: entry.key,
            tokens: tokens.toList(growable: false),
          ),
        );
      }
    }

    return TokenSet(
      categories.toList(growable: false),
      warnings: warnings.toList(growable: false),
    );
  }

  static String _rootTokenWarning(String key) =>
      'Token "$key" sits at the root of the document, outside any category, '
      'and was skipped.';

  /// Whether a root-level string is plainly meant as a colour: a `#` hex or an
  /// alias. A bare `100` could as well be a version number, so it is not.
  bool _looksLikeColour(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('#')
        ? ColorValueParser.parse(trimmed) != null
        : _referenceOf(trimmed) != null;
  }

  /// Walks one category, descending through nested groups and appending a
  /// [ColorToken] for every leaf that resolves to a colour.
  ///
  /// [inheritedType] is the `$type` declared by the nearest enclosing group.
  void _collect({
    required Map<String, Object?> group,
    required List<String> path,
    required Map<String, Object?> root,
    required String? inheritedType,
    required String category,
    required List<ColorToken> out,
    required List<String> warnings,
  }) {
    final groupType = _groupType(group) ?? inheritedType;
    for (final entry in group.entries) {
      if (ignoredKeys.contains(entry.key)) continue;
      final childPath = [...path, entry.key];

      if (_isGroup(entry.value)) {
        _collect(
          group: _asMap(entry.value)!,
          path: childPath,
          root: root,
          inheritedType: groupType,
          category: category,
          out: out,
          warnings: warnings,
        );
        continue;
      }

      final name = childPath.join('/');
      final argb = _valueOf(
        entry.value,
        inheritedType: groupType,
        root: root,
        label: '$category/$name',
        warnings: warnings,
      );
      if (argb != null) out.add(ColorToken(name: name, argb: argb));
    }
  }

  // --- values --------------------------------------------------------------

  /// Resolves one token entry to a colour, following any alias chain.
  ///
  /// Accepts the three shapes seen in real exports: a DTCG wrapper
  /// (`{"$value": …}`), the legacy wrapper (`{"value": …}`), and a bare value
  /// (`"#RRGGBB"` or an rgb map). Returns `null` for anything that is not a
  /// colour — a spacing token, a broken alias — and records a warning in the
  /// cases a design team would want to know about.
  ///
  /// [inheritedType] is the `$type` the entry's group declares. The type of
  /// every token along an alias chain is checked, so an alias to a font weight
  /// is no more a colour than the font weight itself.
  int? _valueOf(
    Object? entry, {
    required String? inheritedType,
    required Map<String, Object?> root,
    required String label,
    required List<String> warnings,
  }) {
    var node = entry;
    var inherited = inheritedType;
    final visited = <String>{};

    for (var hop = 0; hop <= maxAliasHops; hop++) {
      if (!_isColourType(_typeOf(node) ?? inherited)) return null;

      final raw = _unwrap(node);
      final reference = _referenceOf(raw);
      if (reference == null) return ColorValueParser.parse(raw);

      if (!visited.add(reference)) {
        warnings.add(
          'Token "$label" is part of an alias cycle through '
          '"{$reference}" and was skipped.',
        );
        return null;
      }

      final found = _lookup(root, reference);
      final target = found?.node;
      if (target == null) {
        warnings.add(
          'Token "$label" references "{$reference}", which no token defines. '
          'It was skipped.',
        );
        return null;
      }
      if (_isGroup(target)) {
        warnings.add(
          'Token "$label" references "{$reference}", which is a group of '
          'tokens rather than a single token. It was skipped.',
        );
        return null;
      }
      node = target;
      inherited = found!.inheritedType;
    }

    warnings.add(
      'Token "$label" was skipped: its alias chain is longer than '
      '$maxAliasHops references.',
    );
    return null;
  }

  /// Strips the DTCG or legacy wrapper from a token node, if it has one.
  static Object? _unwrap(Object? node) {
    final map = _asMap(node);
    if (map == null) return node;
    if (map.containsKey(r'$value')) return map[r'$value'];
    if (map.containsKey('value')) return map['value'];
    return node;
  }

  /// The type a token node declares for itself, or `null` when it declares
  /// none. Only a wrapper can: `$type`, or `type` in the legacy shape.
  static String? _typeOf(Object? node) {
    final map = _asMap(node);
    if (map == null) return null;
    if (!map.containsKey(r'$value') && !map.containsKey('value')) return null;
    final type = map[r'$type'] ?? map['type'];
    return type is String ? type : null;
  }

  /// The `$type` a group declares for the tokens below it, if any.
  static String? _groupType(Map<String, Object?> group) {
    final type = group[r'$type'];
    return type is String ? type : null;
  }

  /// An undeclared type is given the benefit of the doubt: plenty of exports
  /// never write one, and their values are colours.
  static bool _isColourType(String? type) =>
      type == null || type.trim().toLowerCase() == 'color';

  /// The path inside a `{group.token}` reference, or `null` if [raw] is not
  /// one.
  String? _referenceOf(Object? raw) {
    if (!resolveAliases || raw is! String) return null;
    final match = _reference.firstMatch(raw.trim());
    final path = match?.group(1)?.trim();
    return (path == null || path.isEmpty) ? null : path;
  }

  /// Walks [reference] — dot- or slash-separated — down from the document
  /// root. Returns the node it names along with the `$type` its enclosing
  /// groups declare, or `null` if the path does not exist.
  static ({Object? node, String? inheritedType})? _lookup(
    Map<String, Object?> root,
    String reference,
  ) {
    Object? node = root;
    String? inheritedType;
    for (final segment in reference.split(_referenceSeparator)) {
      final map = _asMap(node);
      if (map == null || !map.containsKey(segment)) return null;
      inheritedType = _groupType(map) ?? inheritedType;
      node = map[segment];
    }
    return (node: node, inheritedType: inheritedType);
  }
}
