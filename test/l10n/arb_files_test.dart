import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The message keys of an ARB file, without the `@` metadata keys.
Set<String> messageKeys(String locale) {
  final json = jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync());
  return {
    for (final key in (json as Map<String, Object?>).keys)
      if (!key.startsWith('@')) key,
  };
}

void main() {
  test('French has a text for every English text, and no other', () {
    final english = messageKeys('en');
    final french = messageKeys('fr');

    expect(english.difference(french), isEmpty, reason: 'missing in French');
    expect(french.difference(english), isEmpty, reason: 'unknown in English');
  });
}
