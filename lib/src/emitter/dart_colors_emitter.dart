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
    this.emitPalettes = true,
    this.header,
  });

  static const String defaultClassName = 'AppColors';
  static const String defaultPaletteClassName = 'AppColorPalette';
  static const String defaultFileName = 'app_colors.dart';

  final String className;
  final String paletteClassName;

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
      ..writeln('// ignore_for_file: unused_field, constant_identifier_names')
      ..writeln()
      ..writeln("import 'package:flutter/material.dart';")
      ..writeln();

    _writeHeader(buffer);
    _writeConstantsClass(buffer, tokens);
    if (emitPalettes) {
      buffer.writeln();
      _writePaletteClass(buffer, tokens);
    }
    return buffer.toString();
  }

  void _writeHeader(StringBuffer buffer) {
    final text = header ??
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
    var first = true;
    for (final category in tokens.categories) {
      if (category.isEmpty) continue;
      if (!first) buffer.writeln();
      first = false;
      buffer.writeln('  // ${category.name}');
      for (final token in category.tokens) {
        final name = Naming.memberName(category.name, token.name);
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
      for (final token in category.tokens) {
        final key = Naming.toLowerCamelCase(token.name);
        buffer.writeln("    '$key': Color(${token.hexLiteral}),");
      }
      buffer.writeln('  };');
    }

    buffer.writeln('}');
  }
}
