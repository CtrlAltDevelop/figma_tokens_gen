import '../models/color_token.dart';
import '../naming.dart';
import 'token_emitter.dart';

/// Emits a Flutter `Color` constant class, and optionally a companion class of
/// `Map<String, Color>` palettes for lookup by name.
class DartColorsEmitter implements TokenEmitter {
  const DartColorsEmitter({
    this.className = defaultClassName,
    this.paletteClassName = defaultPaletteClassName,
    this.fileName = defaultFileName,
    this.materialImport = defaultMaterialImport,
    this.emitPalettes = true,
    this.header,
  });

  static const String defaultClassName = 'AppColors';
  static const String defaultPaletteClassName = 'AppColorPalette';
  static const String defaultFileName = 'app_colors.dart';

  /// Flutter 3.47 moved the Material widgets into their own `material_ui`
  /// package; `dart fix --code=migrate_design_widgets` rewrites imports to it.
  static const String defaultMaterialImport =
      'package:material_ui/material_ui.dart';

  /// The pre-3.47 import, for projects that have not migrated yet.
  static const String legacyMaterialImport = 'package:flutter/material.dart';

  final String className;
  final String paletteClassName;

  /// The import the generated file uses to get `Color`.
  ///
  /// Defaults to [defaultMaterialImport]. Set it to [legacyMaterialImport] on
  /// a project still importing `package:flutter/material.dart`.
  final String materialImport;

  @override
  final String fileName;

  /// Whether to also emit the `Map<String, Color>` palette class.
  final bool emitPalettes;

  /// Replaces the default doc comment at the top of the file.
  final String? header;

  @override
  String emit(TokenSet tokens) {
    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// Regenerate with: dart run figma_tokens_gen')
      ..writeln('// ignore_for_file: constant_identifier_names')
      ..writeln()
      ..writeln("import '${_escapeLiteral(materialImport)}';")
      ..writeln();

    _writeHeader(buffer);
    _writeConstantsClass(buffer, tokens);
    if (emitPalettes) {
      buffer.writeln();
      _writePaletteClass(buffer, tokens);
    }
    return buffer.toString();
  }

  /// Escapes a value for use inside a single-quoted Dart string literal, so a
  /// token named `it's` or `a$b` cannot break the generated file.
  static String _escapeLiteral(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      // A raw newline inside a single-quoted literal does not compile.
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');

  /// Returns [candidate] if nothing has claimed it yet, otherwise the first
  /// numbered variant that is free, recording the result in [taken].
  ///
  /// Flattening nested groups makes collisions reachable: `brand/primary` and
  /// `brandPrimary` under the same category both want `brandPrimary`. Two
  /// members of that name would not compile, and two identical keys in a
  /// `const` map literal are an error outright — so uniqueness is enforced
  /// here, deterministically, and the rename is called out in the output.
  static String _unique(String candidate, Set<String> taken) {
    if (taken.add(candidate)) return candidate;
    for (var suffix = 2; ; suffix++) {
      final variant = '$candidate$suffix';
      if (taken.add(variant)) return variant;
    }
  }

  /// The comment written above a member the collision rule had to rename.
  ///
  /// Split across two lines so the generated file stays inside 80 columns for
  /// realistic token names.
  static String _renameNote(String indent, String authored, String emitted) =>
      '$indent// `$authored` collides with an earlier token in this '
      'category.\n'
      '$indent// Renamed to `$emitted`.\n';

  void _writeHeader(StringBuffer buffer) {
    final text =
        header ??
        'Colour tokens exported from Figma.\n'
            '\n'
            'To update: change the token in Figma, re-export the JSON, then\n'
            'run the generator again. Editing this file by hand will be lost.';
    for (final line in text.split('\n')) {
      buffer.writeln(line.isEmpty ? '///' : '/// $line');
    }
  }

  void _writeConstantsClass(StringBuffer buffer, TokenSet tokens) {
    buffer
      ..writeln('abstract final class $className {')
      ..write(_membersOf(tokens))
      ..writeln('}');
  }

  String _membersOf(TokenSet tokens) {
    final buffer = StringBuffer();
    final taken = <String>{};
    var first = true;
    for (final category in tokens.categories) {
      if (category.isEmpty) continue;
      if (!first) buffer.writeln();
      first = false;
      buffer.writeln('  // ${category.name}');
      for (final token in category.tokens) {
        final requested = Naming.memberName(category.name, token.name);
        final name = _unique(requested, taken);
        if (name != requested) {
          buffer.write(_renameNote('  ', token.name, name));
        }
        buffer.writeln(
          '  static const Color $name = Color(${token.hexLiteral});',
        );
      }
    }
    return buffer.toString();
  }

  void _writePaletteClass(StringBuffer buffer, TokenSet tokens) {
    buffer
      ..writeln('/// The same tokens grouped by category, for lookup by name.')
      ..writeln('abstract final class $paletteClassName {');

    var first = true;
    for (final category in tokens.categories) {
      if (category.isEmpty) continue;
      if (!first) buffer.writeln();
      first = false;
      final field = Naming.toLowerCamelCase(category.name);
      buffer
        ..writeln('  /// Tokens under the `${category.name}` category.')
        ..writeln('  static const Map<String, Color> $field = {');
      final taken = <String>{};
      for (final token in category.tokens) {
        final requested = Naming.toLowerCamelCaseLabel(token.name);
        final key = _unique(requested, taken);
        if (key != requested) {
          buffer.write(_renameNote('    ', token.name, key));
        }
        buffer.writeln(
          "    '${_escapeLiteral(key)}': Color(${token.hexLiteral}),",
        );
      }
      buffer.writeln('  };');
    }

    buffer.writeln('}');
  }
}
