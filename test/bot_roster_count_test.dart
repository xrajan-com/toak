import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bot roster stays capped at 100 with Southeast Asia additions', () {
    final source = File('lib/ui/screens/game_screen.dart').readAsStringSync();

    int countSpecs(String listName) {
      final match = RegExp(
        'const List<_BotSpec> $listName = <_BotSpec>\\[([\\s\\S]*?)\\];',
      ).firstMatch(source);
      expect(match, isNotNull, reason: 'Missing $listName roster.');
      return RegExp(r'_BotSpec\(').allMatches(match!.group(1)!).length;
    }

    expect(countSpecs('_indianBotSpecs'), 25);
    expect(countSpecs('_intlBotSpecs'), 75);
    expect(countSpecs('_indianBotSpecs') + countSpecs('_intlBotSpecs'), 100);

    const southeastAsiaNames = <String>[
      'Anong Srisai',
      'Chaiwat Rattan',
      'Linh Pham',
      'Minh Tran',
      'Sari Wijaya',
      'Bima Santoso',
      'Nur Aisyah',
      'Hakim Rahman',
      'Mei Lin Tan',
      'Darren Lim',
      'Rosa Delgado',
      'Miguel Santos',
      'Thandar Hlaing',
      'Ko Aung Min',
      'Sreymom Vann',
      'Dara Sok',
      'Kanya Vong',
      'Somphone Keo',
      'Liyana Salleh',
      'Azim Mahmud',
      'Ana Soares',
      'Mateus da Costa',
      'Fitri Halim',
      'Van Nguyen',
      'Nattida Kwan',
    ];

    for (final name in southeastAsiaNames) {
      expect(source, contains("'$name'"));
      final slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      expect(
        File('assets/images/avatars/bots/$slug.png').existsSync(),
        isTrue,
        reason: 'Missing Southeast Asia bot avatar for $name.',
      );
    }

    final southeastAsiaBlock = RegExp(
      r'// Southeast Asia([\s\S]*?)\n\n  // --- Super-bots ---',
    ).firstMatch(source);
    expect(southeastAsiaBlock, isNotNull);
    expect(southeastAsiaBlock!.group(1), isNot(contains('hasAvatar: false')));

    const removedIndianNames = <String>[
      'Vidya Patil',
      'Sameer Pawar',
      'Rohan Iyengar',
      'Meenakshi Gowda',
      'Veerendra Wodeyar',
      'Gurdeep Singh',
      'Harjit Sandhu',
      'Pratap Singh',
      'Smriti Vyas',
      'Ishita Shekhawat',
      'Bhavna Joshi',
      'Kishor Mehta',
      'Rupa Desai',
      'Arjun Reddy',
      'Jay Naidu',
      'Tarun Malhotra',
      'Devansh Agrawal',
      'Naveen Rajput',
      'Sonu Biswas',
      'Karan Bhutia',
      'Pema Sherpa',
      'Arvind Chundawat',
      'Farhan Siddiqui',
      'Anil Nair',
      'Mohan Menon',
    ];

    for (final name in removedIndianNames) {
      expect(source, isNot(contains(name)));
    }
  });
}
