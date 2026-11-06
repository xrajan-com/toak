import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/story.dart';

void main() {
  test('Renoir names the place and the crown, briefly, without shouting', () {
    final List<String> lines = <String>[
      StoryLines.openingLine(kingdom: 'Baroda', firstTable: true),
      StoryLines.openingLine(kingdom: 'Japan', title: 'Daimyo'),
      StoryLines.openingLine(
        kingdom: 'Baroda',
        title: 'Patel',
        fortName: 'Lakhota Fort',
      ),
      StoryLines.openingLine(
        kingdom: 'Britain & Ireland',
        title: 'Baron',
        fortName: 'Bamburgh Castle (England)',
      ),
      StoryLines.openingLine(
        kingdom: 'Baroda',
        title: 'Patel',
        titleMatch: true,
        titleHolder: 'Amara Ndlovu',
      ),
      StoryLines.openingLine(kingdom: 'Baroda', title: 'N/A', titleMatch: true),
      StoryLines.premise,
    ];
    for (final String line in lines) {
      expect(line, isNot(contains('!')));
      expect(line.length, lessThanOrEqualTo(100), reason: line);
    }
    expect(lines[0], contains('Baroda'));
    expect(lines[2], contains('Lakhota Fort'));
    expect(lines[2], contains('Patel'));
    expect(lines[3], isNot(contains('(England)')));
    expect(lines[4], contains('Amara Ndlovu is Patel'));
    expect(lines[5], isNot(contains('N/A')));
  });

  test('a kingdom keeps the same title holder', () {
    const List<String> field = <String>['Kofi', 'Lien', 'Amara', 'Omar'];
    final String? holder = StoryLines.pickTitleHolder(field, 'Baroda');
    expect(holder, isNotNull);
    expect(field, contains(holder));
    expect(
      StoryLines.pickTitleHolder(field.reversed, 'Baroda'),
      holder,
      reason: 'seating order must not change who holds the crown',
    );
    expect(StoryLines.pickTitleHolder(const <String>[], 'Baroda'), isNull);
  });

  test('the title holder note names the crown', () {
    expect(
      StoryLines.titleHolderNote(title: 'Patel', kingdom: 'Baroda'),
      'Patel of Baroda · holds the crown',
    );
  });
}
