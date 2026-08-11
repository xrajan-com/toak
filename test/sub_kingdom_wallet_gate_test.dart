import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/sub_kingdom_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=');
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets('an unlocked paid fort cannot open with insufficient AUP',
      (tester) async {
    const group = VenueGroup.india;
    final kingdom = indianVenues.first;
    final order = ce.subKingdomIndicesByPrizePool(
      group: group,
      kingdomName: kingdom.name,
    );
    final freeIndex = ce.freeSubKingdomIndexFor(
      group: group,
      kingdomName: kingdom.name,
    );
    final nextIndex = order[order.indexOf(freeIndex) + 1];

    final wallet = AuraPointsService();
    await wallet.init();
    final progress = CampaignProgressService()
      ..markCleared(
        group: group,
        kingdomName: kingdom.name,
        subKingdomIndex: freeIndex,
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuraPointsService>.value(value: wallet),
          ChangeNotifierProvider<CampaignProgressService>.value(
            value: progress,
          ),
        ],
        child: MaterialApp(
          home: SubKingdomScreen(kingdom: kingdom, group: group),
        ),
      ),
    );
    await tester.pump();

    final freeFort = find.byKey(ValueKey<String>('fort-$freeIndex'));
    final freeFortName = subKingdomDisplayName(
      group: group,
      kingdomName: kingdom.name,
      index: freeIndex,
    );
    expect(find.descendant(of: freeFort, matching: find.text(freeFortName)),
        findsOneWidget);
    expect(
      find.descendant(
        of: freeFort,
        matching: find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('Entry FREE') &&
            widget.data!.contains('Prize AUP')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: freeFort,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsNothing,
    );

    final paidFort = find.byKey(ValueKey<String>('fort-$nextIndex'));
    expect(paidFort, findsOneWidget);
    final String paidFortName = subKingdomDisplayName(
      group: group,
      kingdomName: kingdom.name,
      index: nextIndex,
    );
    expect(
      find.descendant(of: paidFort, matching: find.text(paidFortName)),
      findsOneWidget,
    );
    final Finder paidFortDetails = find.descendant(
      of: paidFort,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Text || widget.data == null) return false;
        return widget.data!.contains('Entry AUP') &&
            widget.data!.contains('Prize AUP');
      }),
    );
    expect(paidFortDetails, findsOneWidget);
    final Text detailsText = tester.widget<Text>(paidFortDetails);
    final String details = detailsText.data!;
    expect(details, contains('Entry AUP'));
    expect(details, contains('Prize AUP'));
    expect(
      find.descendant(
        of: paidFort,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );

    final int laterIndex = order[order.indexOf(freeIndex) + 2];
    final Finder laterFort = find.byKey(ValueKey<String>('fort-$laterIndex'));
    final String laterFortName = subKingdomDisplayName(
      group: group,
      kingdomName: kingdom.name,
      index: laterIndex,
    );
    expect(find.descendant(of: laterFort, matching: find.text(laterFortName)),
        findsOneWidget);
    expect(
        find.descendant(
          of: laterFort,
          matching: find.byWidgetPredicate((widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('Entry AUP') &&
              widget.data!.contains('Prize AUP')),
        ),
        findsOneWidget);
    expect(
      find.descendant(
        of: laterFort,
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(paidFort);
    await tester.tap(paidFort);
    await tester.pumpAndSettle();

    expect(find.text('Need more AUP?'), findsOneWidget);
    expect(wallet.indiaAup, 0);
  });

  testWidgets('entry tap lock survives a provider rebuild', (tester) async {
    const group = VenueGroup.india;
    final kingdom = indianVenues.first;
    final freeIndex = ce.freeSubKingdomIndexFor(
      group: group,
      kingdomName: kingdom.name,
    );
    final wallet = _DelayedReservationAura();
    await wallet.init();
    final progress = CampaignProgressService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuraPointsService>.value(value: wallet),
          ChangeNotifierProvider<CampaignProgressService>.value(
            value: progress,
          ),
        ],
        child: MaterialApp(
          home: SubKingdomScreen(kingdom: kingdom, group: group),
        ),
      ),
    );
    await tester.pump();

    final fort = find.byKey(ValueKey<String>('fort-$freeIndex'));
    await tester.ensureVisible(fort);
    await tester.tap(fort);
    await tester.pump();
    expect(wallet.reserveCalls, 1);

    wallet.triggerRebuild();
    await tester.pump();
    await tester.tap(fort);
    await tester.pump();
    expect(wallet.reserveCalls, 1);

    wallet.completeReservation();
    await tester.pumpAndSettle();
    expect(wallet.reserveCalls, 1);
  });
}

class _DelayedReservationAura extends AuraPointsService {
  final Completer<EntryPaymentResult> _reservation =
      Completer<EntryPaymentResult>();
  int reserveCalls = 0;

  void triggerRebuild() => notifyListeners();

  void completeReservation() {
    _reservation.complete(
      const EntryPaymentResult(
        status: EntryPaymentStatus.rejected,
        reason: 'test_rejection',
      ),
    );
  }

  @override
  Future<EntryPaymentResult> reserveCampaignEntry({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
    required int expectedEntryFee,
  }) {
    reserveCalls += 1;
    return _reservation.future;
  }
}
