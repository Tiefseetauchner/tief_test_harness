import 'package:analyzer/dart/ast/token.dart';

final _wordBoundary = RegExp(r'[^a-zA-Z0-9]+');
final _validIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

final _dartReservedWords = {
  for (final keyword in Keyword.values)
    if (keyword.isReservedWord) keyword.lexeme,
};

// Not reserved words, but an enum can't declare a value with these names.
// `values` collides with the synthesized static getter, and the rest
// collide with members inherited from Object/Enum.
const _enumMemberNames = {
  'values',
  'index',
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
};

List<String> _words(String input) =>
    input.split(_wordBoundary).where((word) => word.isNotEmpty).toList();

String _capitalize(String word) => word.isEmpty
    ? word
    : word[0].toUpperCase() + word.substring(1).toLowerCase();

String toPascalCase(String input) => _words(input).map(_capitalize).join();

String toCamelCase(String input) {
  final words = _words(input);
  if (words.isEmpty) return '';
  return words.first.toLowerCase() + words.skip(1).map(_capitalize).join();
}

bool isUsableDartIdentifier(String input) =>
    _validIdentifier.hasMatch(input) &&
    !_dartReservedWords.contains(input) &&
    !_enumMemberNames.contains(input);
