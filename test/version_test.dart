import 'dart:io';

import 'package:test/test.dart';

/// The CLI hard-codes its version string, because a pure-Dart package has no
/// way to read its own pubspec at runtime once compiled. That duplication has
/// drifted before — `--version` reported `0.1.0` from 1.0.0 — so it is pinned
/// here rather than left to review.
void main() {
  test('the version the CLI prints matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    expect(declared, isNotNull, reason: 'pubspec.yaml declares no version');

    final cli = File('bin/figma_tokens_gen.dart').readAsStringSync();
    final hardCoded = RegExp(r"""_version\s*=\s*['"]([^'"]+)['"]""")
        .firstMatch(cli)
        ?.group(1);

    expect(hardCoded, declared);
  });
}
