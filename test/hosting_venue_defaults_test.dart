import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosting venue tabs prioritize international circuit by default', () {
    final indexHtml = File('hosting/index.html').readAsStringSync();
    final styles = File('hosting/styles.css').readAsStringSync();

    expect(
      indexHtml,
      contains(
        '<button class="venue-tab active" data-target="world" '
        'role="tab" aria-selected="true">International Circuit</button>',
      ),
    );
    expect(
      indexHtml,
      contains(
        '<button class="venue-tab" data-target="india" '
        'role="tab" aria-selected="false">Royal Indian Circuit</button>',
      ),
    );
    expect(
      indexHtml,
      contains('<div class="venue-grid active" data-group="world"'),
    );

    final worldActive = RegExp(
      r'\.venue-tab\[data-target="world"\]\.active\s*\{[^}]*background:\s*#ff2800;',
      multiLine: true,
    );
    final indiaActive = RegExp(
      r'\.venue-tab\[data-target="india"\]\.active\s*\{[^}]*background:\s*linear-gradient\(120deg, #24b6ff, #00a6e8\);',
      multiLine: true,
    );

    expect(styles, matches(worldActive));
    expect(styles, matches(indiaActive));
  });
}
