import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/services/rival_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('an opponent becomes a rival after two games, with the record', () async {
    final rivals = RivalService();
    await rivals.load();
    await rivals.recordGame({'Peter Power': true, 'Shawn': false});
    expect(rivals.rivals(), isEmpty);
    expect(rivals.noteFor('Peter Power'), isNull);

    await rivals.recordGame({'Peter Power': true, 'Shawn': false});
    await rivals.recordGame({'Peter Power': false});
    expect(rivals.rivals().first, 'Peter Power');
    expect(rivals.noteFor('Peter Power'), 'Rival · you lead 2-1');
    expect(rivals.noteFor('Shawn'), 'Rival · leads you 2-0');
  });

  test('the record survives a restart', () async {
    final first = RivalService();
    await first.load();
    await first.recordGame({'Dung Le': true});
    await first.recordGame({'Dung Le': false});

    final second = RivalService();
    await second.load();
    expect(second.noteFor('Dung Le'), 'Rival · level 1-1');
  });

  test('only rivals in the pool are seated, at most two, by chance', () async {
    final rivals = RivalService();
    await rivals.load();
    for (int i = 0; i < 3; i++) {
      await rivals.recordGame({'A': true, 'B': true, 'C': false, 'D': true});
    }
    expect(rivals.rivalsToSeat(['A', 'B', 'C'], () => 0.0).length, 2);
    expect(rivals.rivalsToSeat(['A', 'B', 'C'], () => 0.99), isEmpty);
    expect(rivals.rivalsToSeat(['D'], () => 0.0), ['D']);
    expect(rivals.rivalsToSeat(['Z'], () => 0.0), isEmpty);
  });

  test('a corrupt store starts fresh instead of failing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'rivals_v1': 'not json',
    });
    final rivals = RivalService();
    await rivals.load();
    expect(rivals.loaded, isTrue);
    expect(rivals.rivals(), isEmpty);
  });
}
