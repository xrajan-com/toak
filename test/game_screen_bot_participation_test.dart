import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/renoir_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    SoundFx.instance.setMuted(true);
    RenoirSignals.holeCardsVisible.value = false;
    RenoirSignals.canAct.value = false;
    RenoirSignals.dealingActive.value = false;
  });

  testWidgets('bots take at least one action after the hand opens',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuraPointsService>(
            create: (_) => AuraPointsService(),
          ),
          ChangeNotifierProvider<ProfileService>(
            create: (_) => ProfileService(),
          ),
          ChangeNotifierProvider<CampaignProgressService>(
            create: (_) => CampaignProgressService(),
          ),
        ],
        child: MaterialApp(
          home: GameScreen.guestTable(
            tableName: 'Bot Smoke',
            venue: indianVenues.first,
            playIntroWelcome: false,
          ),
        ),
      ),
    );

    bool sawBotAction = false;
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      final botSeats = tester
          .widgetList<SeatWidget>(find.byType(SeatWidget))
          .where((seatWidget) => !seatWidget.seat.isHero);
      if (botSeats
          .any((seatWidget) => seatWidget.seat.lastAction.trim().isNotEmpty)) {
        sawBotAction = true;
        break;
      }
    }

    final botSeats = tester
        .widgetList<SeatWidget>(find.byType(SeatWidget))
        .where((seatWidget) => !seatWidget.seat.isHero)
        .toList(growable: false);
    final botStateDump = botSeats
        .map((seatWidget) =>
            '${seatWidget.seat.name}:${seatWidget.isTurn}:${seatWidget.seat.bet}:${seatWidget.seat.lastAction}')
        .join(' | ');

    expect(botSeats, isNotEmpty);
    expect(sawBotAction, isTrue,
        reason: 'no bot action was observed before timeout');
    expect(
      botSeats
          .any((seatWidget) => seatWidget.seat.lastAction.trim().isNotEmpty),
      isTrue,
      reason:
          'canAct=${RenoirSignals.canAct.value} holes=${RenoirSignals.holeCardsVisible.value} bots=$botStateDump',
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));
  });
}
