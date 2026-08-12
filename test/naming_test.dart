import 'package:figma_tokens_gen/figma_tokens_gen.dart';
import 'package:test/test.dart';

void main() {
  group('Naming.words', () {
    test('splits camelCase boundaries', () {
      expect(Naming.words('extraLight'), ['extra', 'Light']);
    });

    test('splits separators', () {
      expect(Naming.words('gray-600'), ['gray', '600']);
      expect(Naming.words('background/paper'), ['background', 'paper']);
      expect(Naming.words('text_soft value'), ['text', 'soft', 'value']);
      expect(Naming.words('backgroundBG'), ['background', 'BG']);
    });

    test('drops empty parts and illegal characters', () {
      expect(Naming.words('  primary--main! '), ['primary', 'main']);
    });

    test('returns an empty list for empty input', () {
      expect(Naming.words('   '), isEmpty);
    });
  });

  group('Naming casing', () {
    test('toLowerCamelCase', () {
      expect(Naming.toLowerCamelCase('Extra Light'), 'extraLight');
      expect(Naming.toLowerCamelCase('background'), 'background');
      expect(Naming.toLowerCamelCase(''), '');
    });

    test('toUpperCamelCase', () {
      expect(Naming.toUpperCamelCase('extraLight'), 'ExtraLight');
      expect(Naming.toUpperCamelCase('gray-600'), 'Gray600');
    });

    test('toSnakeCase', () {
      expect(Naming.toSnakeCase('extraLight'), 'extra_light');
      expect(Naming.toSnakeCase('backgroundPaper'), 'background_paper');
    });
  });

  group('Naming.memberName', () {
    test('joins category and token', () {
      expect(Naming.memberName('primary', 'extraLight'), 'primaryExtraLight');
      expect(Naming.memberName('background', 'bg'), 'backgroundBg');
      expect(Naming.memberName('gray', '600'), 'gray600');
    });

    test('falls back to the category when the token is empty', () {
      expect(Naming.memberName('primary', ''), 'primary');
    });

    test('escapes names that would start with a digit', () {
      expect(Naming.memberName('', '600'), r'$600');
    });

    test('escapes Dart reserved words', () {
      expect(Naming.memberName('', 'class'), 'class_');
      expect(Naming.memberName('', 'switch'), 'switch_');
    });
  });
}
