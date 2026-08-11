import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/core.dart';
import 'package:ten_of_a_kind_poker/game/equity/hero_equity.dart';
import 'package:ten_of_a_kind_poker/game/equity/preflop_equity_table.dart';

void main() {
  setUp(HeroEquityEngine.clearCacheForTests);

  test('preflop table covers canonical suited offsuit and pair classes', () {
    expect(
      canonicalPreflopClass(
        const Card(Rank.ace, Suit.spades),
        const Card(Rank.king, Suit.spades),
      ),
      'AKs',
    );
    expect(
      canonicalPreflopClass(
        const Card(Rank.king, Suit.hearts),
        const Card(Rank.ace, Suit.clubs),
      ),
      'AKo',
    );
    expect(
      canonicalPreflopClass(
        const Card(Rank.ace, Suit.diamonds),
        const Card(Rank.ace, Suit.clubs),
      ),
      'AA',
    );

    for (int players = 2; players <= 10; players++) {
      expect(
        lookupPreflopEquity(
          const <Card>[
            Card(Rank.seven, Suit.spades),
            Card(Rank.two, Suit.hearts),
          ],
          players,
        ),
        isNotNull,
      );
    }
  });

  test('bundled preflop lookup is calibrated and scales with field size', () {
    final headsUp = lookupPreflopEquity(
      const <Card>[
        Card(Rank.ace, Suit.spades),
        Card(Rank.ace, Suit.hearts),
      ],
      2,
    )!;
    final tenHanded = lookupPreflopEquity(
      const <Card>[
        Card(Rank.ace, Suit.spades),
        Card(Rank.ace, Suit.hearts),
      ],
      10,
    )!;

    expect(headsUp.equity, closeTo(0.852, 0.01));
    expect(tenHanded.equity, lessThan(headsUp.equity));
    expect(headsUp.samples, 50000);
  });

  test('preview immediately supplies percentages while detailed odds refine',
      () {
    const engine = HeroEquityEngine();
    final request = _request(
      hero: const <Card>[
        Card(Rank.king, Suit.clubs),
        Card(Rank.five, Suit.clubs),
      ],
      board: const <Card>[],
      seats: <HeroEquitySeat>[
        const HeroEquitySeat(
            seatIndex: 0, active: true, allIn: false, contribution: 100),
        HeroEquitySeat(
          seatIndex: 1,
          active: true,
          allIn: false,
          contribution: 100,
          range: VisibleOpponentRange.fromPublicAction('CALL 100'),
        ),
        const HeroEquitySeat(
            seatIndex: 2, active: true, allIn: false, contribution: 100),
        const HeroEquitySeat(
            seatIndex: 3, active: true, allIn: false, contribution: 100),
      ],
    );

    expect(engine.immediateEstimate(request), isNull);
    final HeroEquityEstimate? preview = engine.previewEstimate(request);

    expect(preview, isNotNull);
    expect(preview!.method, 'Quick deterministic preview');
    expect(preview.samples, greaterThanOrEqualTo(120));
    expect(preview.winProbability, inInclusiveRange(0, 1));
    expect(preview.tieProbability, inInclusiveRange(0, 1));
    expect(preview.equity, inInclusiveRange(0, 1));
    expect(preview.equity, greaterThanOrEqualTo(preview.winProbability));
  });

  test('river enumeration separates a forced tie from fractional equity',
      () async {
    const engine = HeroEquityEngine(yieldEvery: 100);
    final estimate = await engine.estimate(
      _request(
        hero: const <Card>[
          Card(Rank.two, Suit.clubs),
          Card(Rank.three, Suit.diamonds),
        ],
        board: const <Card>[
          Card(Rank.ace, Suit.spades),
          Card(Rank.king, Suit.spades),
          Card(Rank.queen, Suit.spades),
          Card(Rank.jack, Suit.spades),
          Card(Rank.ten, Suit.spades),
        ],
        seats: const <HeroEquitySeat>[
          HeroEquitySeat(
              seatIndex: 0, active: true, allIn: false, contribution: 100),
          HeroEquitySeat(
              seatIndex: 1, active: true, allIn: false, contribution: 100),
        ],
      ),
    );

    expect(estimate, isNotNull);
    expect(estimate!.exact, isTrue);
    expect(estimate.winProbability, 0);
    expect(estimate.tieProbability, 1);
    expect(estimate.equity, 0.5);
    expect(estimate.method, contains('river enumeration'));
  });

  test('river enumeration identifies an unbeatable private royal flush',
      () async {
    const engine = HeroEquityEngine(yieldEvery: 100);
    final estimate = await engine.estimate(
      _request(
        hero: const <Card>[
          Card(Rank.ace, Suit.spades),
          Card(Rank.king, Suit.spades),
        ],
        board: const <Card>[
          Card(Rank.queen, Suit.spades),
          Card(Rank.jack, Suit.spades),
          Card(Rank.ten, Suit.spades),
          Card(Rank.two, Suit.diamonds),
          Card(Rank.three, Suit.clubs),
        ],
        seats: const <HeroEquitySeat>[
          HeroEquitySeat(
              seatIndex: 0, active: true, allIn: false, contribution: 100),
          HeroEquitySeat(
              seatIndex: 1, active: true, allIn: false, contribution: 100),
        ],
      ),
    );

    expect(estimate!.winProbability, 1);
    expect(estimate.tieProbability, 0);
    expect(estimate.equity, 1);
  });

  test('turn enumeration exhausts every opponent and river combination',
      () async {
    const engine = HeroEquityEngine(yieldEvery: 500);
    final estimate = await engine.estimate(
      _request(
        hero: const <Card>[
          Card(Rank.ace, Suit.spades),
          Card(Rank.king, Suit.spades),
        ],
        board: const <Card>[
          Card(Rank.queen, Suit.spades),
          Card(Rank.jack, Suit.spades),
          Card(Rank.ten, Suit.spades),
          Card(Rank.two, Suit.diamonds),
        ],
        seats: const <HeroEquitySeat>[
          HeroEquitySeat(
              seatIndex: 0, active: true, allIn: false, contribution: 100),
          HeroEquitySeat(
              seatIndex: 1, active: true, allIn: false, contribution: 100),
        ],
      ),
    );

    expect(estimate!.exact, isTrue);
    expect(estimate.samples, 45540);
    expect(estimate.winProbability, 1);
    expect(estimate.method, contains('turn enumeration'));
  });

  test('adaptive postflop estimator uses stratified runouts and target budget',
      () async {
    const engine = HeroEquityEngine(
      minimumSamples: 800,
      maximumSamples: 1200,
      targetMargin95: 0.02,
      yieldEvery: 100,
    );
    final estimate = await engine.estimate(
      _request(
        hero: const <Card>[
          Card(Rank.ace, Suit.hearts),
          Card(Rank.king, Suit.hearts),
        ],
        board: const <Card>[
          Card(Rank.queen, Suit.hearts),
          Card(Rank.jack, Suit.clubs),
          Card(Rank.two, Suit.hearts),
        ],
        seats: const <HeroEquitySeat>[
          HeroEquitySeat(
              seatIndex: 0, active: true, allIn: false, contribution: 100),
          HeroEquitySeat(
              seatIndex: 1, active: true, allIn: false, contribution: 100),
          HeroEquitySeat(
              seatIndex: 2, active: true, allIn: false, contribution: 100),
        ],
      ),
    );

    expect(estimate, isNotNull);
    expect(estimate!.exact, isFalse);
    expect(estimate.method, 'Stratified adaptive Monte Carlo');
    expect(estimate.samples, inInclusiveRange(800, 1200));
    expect(estimate.equity, inInclusiveRange(0, 1));
  });

  test('public aggressive action changes range without hidden-card input',
      () async {
    const engine = HeroEquityEngine(
      minimumSamples: 2500,
      maximumSamples: 2500,
      yieldEvery: 250,
    );
    const hero = <Card>[
      Card(Rank.eight, Suit.clubs),
      Card(Rank.eight, Suit.diamonds),
    ];
    const board = <Card>[
      Card(Rank.ace, Suit.spades),
      Card(Rank.seven, Suit.hearts),
      Card(Rank.two, Suit.clubs),
    ];
    final neutral = await engine.estimate(
      _request(
        hero: hero,
        board: board,
        seats: const <HeroEquitySeat>[
          HeroEquitySeat(
              seatIndex: 0, active: true, allIn: false, contribution: 100),
          HeroEquitySeat(
              seatIndex: 1, active: true, allIn: false, contribution: 100),
          HeroEquitySeat(
              seatIndex: 2, active: true, allIn: false, contribution: 100),
        ],
      ),
    );
    final aggressive = await engine.estimate(
      _request(
        hero: hero,
        board: board,
        seats: <HeroEquitySeat>[
          const HeroEquitySeat(
              seatIndex: 0, active: true, allIn: false, contribution: 100),
          HeroEquitySeat(
            seatIndex: 1,
            active: true,
            allIn: true,
            contribution: 100,
            range: VisibleOpponentRange.fromPublicAction('ALL-IN', allIn: true),
          ),
          const HeroEquitySeat(
              seatIndex: 2, active: true, allIn: false, contribution: 100),
        ],
      ),
    );

    final range = VisibleOpponentRange.fromPublicAction(
      'ALL-IN',
      allIn: true,
    );
    expect(
      range.weightFor(
        const <Card>[
          Card(Rank.ace, Suit.hearts),
          Card(Rank.ace, Suit.diamonds),
        ],
        board,
      ),
      greaterThan(
        range.weightFor(
          const <Card>[
            Card(Rank.three, Suit.hearts),
            Card(Rank.four, Suit.diamonds),
          ],
          board,
        ),
      ),
    );
    expect((aggressive!.equity - neutral!.equity).abs(), greaterThan(0.002));
  });

  test('side-pot share caps an all-in hero even with the nuts', () async {
    const engine = HeroEquityEngine(
      minimumSamples: 100,
      maximumSamples: 100,
      yieldEvery: 25,
    );
    final estimate = await engine.estimate(
      _request(
        hero: const <Card>[
          Card(Rank.ace, Suit.spades),
          Card(Rank.king, Suit.spades),
        ],
        board: const <Card>[
          Card(Rank.queen, Suit.spades),
          Card(Rank.jack, Suit.spades),
          Card(Rank.ten, Suit.spades),
          Card(Rank.two, Suit.diamonds),
          Card(Rank.three, Suit.clubs),
        ],
        visiblePot: 700,
        seats: const <HeroEquitySeat>[
          HeroEquitySeat(
              seatIndex: 0, active: true, allIn: true, contribution: 100),
          HeroEquitySeat(
              seatIndex: 1, active: true, allIn: false, contribution: 300),
          HeroEquitySeat(
              seatIndex: 2, active: true, allIn: false, contribution: 300),
        ],
      ),
    );

    expect(estimate!.equity, 1);
    expect(estimate.sidePotAware, isTrue);
    expect(estimate.expectedPotShare, closeTo(300 / 700, 0.000001));
  });
}

HeroEquityRequest _request({
  required List<Card> hero,
  required List<Card> board,
  required List<HeroEquitySeat> seats,
  double visiblePot = 200,
}) {
  return HeroEquityRequest(
    heroSeatIndex: 0,
    heroHole: hero,
    revealedBoard: board,
    seats: seats,
    visiblePot: visiblePot,
  );
}
