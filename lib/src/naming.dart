/// Converts Figma token identifiers into valid Dart identifiers.
///
/// Kept free of any I/O or JSON knowledge so the casing rules can be tested in
/// isolation — they are the part most likely to need tweaking per design team.
abstract final class Naming {
  static final RegExp _camelBoundary = RegExp(r'([a-z0-9])([A-Z])');
  static final RegExp _separators = RegExp(r'[-_\s/.]+');
  static final RegExp _illegal = RegExp(r'[^A-Za-z0-9_$]');

  /// Reserved words that cannot be used bare as Dart member names.
  static const _reservedWords = <String>{
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'sealed',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'when',
    'while',
    'with',
    'yield',
  };

  /// Splits an arbitrary identifier into its word parts, preserving case.
  ///
  /// `extraLight` → `[extra, Light]`, `gray-600` → `[gray, 600]`,
  /// `BG` → `[BG]`.
  ///
  /// Case is deliberately preserved: design systems use acronym tokens like
  /// `BG` and `USD`, and lowercasing them here would emit `backgroundBg`
  /// instead of the `backgroundBG` the designer named.
  static List<String> words(String source) {
    final spaced = source.trim().replaceAllMapped(
          _camelBoundary,
          (match) => '${match[1]} ${match[2]}',
        );
    return spaced
        .split(_separators)
        .map((part) => part.replaceAll(_illegal, ''))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  /// `Extra Light` → `extraLight`. Returns an empty string for empty input.
  static String toLowerCamelCase(String source) {
    final parts = words(source);
    if (parts.isEmpty) return '';
    final buffer = StringBuffer(parts.first.toLowerCase());
    for (final part in parts.skip(1)) {
      buffer.write(_capitalise(part));
    }
    return _sanitise(buffer.toString());
  }

  /// `extraLight` → `ExtraLight`, `BG` → `BG`. Empty input gives an empty
  /// string.
  static String toUpperCamelCase(String source) {
    final parts = words(source);
    if (parts.isEmpty) return '';
    return parts.map(_capitalise).join();
  }

  /// `extraLight` → `extra_light`. Returns an empty string for empty input.
  static String toSnakeCase(String source) =>
      words(source).map((part) => part.toLowerCase()).join('_');

  /// Builds the flat constant name for a token, e.g. (`primary`, `extraLight`)
  /// → `primaryExtraLight`.
  static String memberName(String category, String token) {
    final categoryPart = toLowerCamelCase(category);
    final tokenPart = toUpperCamelCase(token);
    if (tokenPart.isEmpty) return categoryPart;
    if (categoryPart.isEmpty) return toLowerCamelCase(token);
    return _sanitise('$categoryPart$tokenPart');
  }

  /// Upper-cases the first letter and leaves the rest untouched, so an
  /// all-caps token such as `BG` survives intact.
  static String _capitalise(String part) =>
      part.isEmpty ? part : part[0].toUpperCase() + part.substring(1);

  /// Guards against output that would not compile: leading digits and
  /// reserved words both produce invalid Dart member names.
  static String _sanitise(String identifier) {
    if (identifier.isEmpty) return identifier;
    final prefixed =
        RegExp(r'^[0-9]').hasMatch(identifier) ? r'$' + identifier : identifier;
    return _reservedWords.contains(prefixed) ? '${prefixed}_' : prefixed;
  }
}
