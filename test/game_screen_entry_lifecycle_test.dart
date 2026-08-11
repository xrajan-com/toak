import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/features/venue/game_mode.dart';
import 'package:ten_of_a_kind_poker/services/app_settings_service.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/ui.dart';
import 'package:ten_of_a_kind_poker/ui/screens/sub_kingdom_screen.dart';

class _ControlledAuraPointsService extends AuraPointsService {
  _ControlledAuraPointsService(this.reservation);

  final EntryReservation reservation;
  final Completer<EntryPaymentResult> commitCompleter =
      Completer<EntryPaymentResult>();
  int commitCalls = 0;
  int abandonCalls = 0;
  int recoveryCalls = 0;

  @override
  bool get isLoaded => true;

  @override
  bool get isReady => true;

  @override
  bool get isAuthorityUnavailable => false;

  @override
  int aupForGroup(VenueGroup group) => 100000;

  @override
  List<EntryReservation> get activeCommittedEntries =>
      <EntryReservation>[reservation];

  @override
  bool get hasPendingCampaignSettlements => false;

  @override
  Future<bool> reconcilePendingEconomy() async => false;

  @override
  Future<EntryPaymentResult> commitEntry(
    EntryReservation reservation,
  ) {
    commitCalls++;
    return commitCompleter.future;
  }

  @override
  Future<CampaignSettlementResult> finalizeCampaignAbandon({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
    required String entryAttemptId,
    required int totalPlayers,
  }) async {
    abandonCalls++;
    return const CampaignSettlementResult(
      status: CampaignSettlementStatus.accepted,
    );
  }

  @override
  Future<EntryPaymentResult> recoverOrphanedEntry({
    required String attemptId,
  }) async {
    recoveryCalls++;
    return const EntryPaymentResult(
      status: EntryPaymentStatus.recovered,
      reason: 'abandoned_entry_recovered',
    );
  }
}

Widget _providers({
  required AuraPointsService aura,
  required Widget child,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsService>(
          create: (_) => AppSettingsService(),
        ),
        ChangeNotifierProvider<AuraPointsService>.value(value: aura),
        ChangeNotifierProvider<ProfileService>(
          create: (_) => ProfileService(),
        ),
        ChangeNotifierProvider<CampaignProgressService>(
          create: (_) => CampaignProgressService(),
        ),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const EntryReservation reservedEntry = EntryReservation(
    attemptId: 'attempt-1',
    campaignId: 'sk:india:maratha_empire:1',
    group: VenueGroup.india,
    amount: 0,
    state: 'reserved',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    SoundFx.instance.setMuted(true);
  });

  test('career tournament construction requires a persisted entry', () {
    expect(
      () => GameScreen.guestTable(
        tableName: 'Career',
        venue: indianVenues.first,
        venueMode: VenueEntryMode.career,
        campaignGroup: VenueGroup.india,
        campaignSubKingdomIndex: 1,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('career table deals only after its exact entry commits',
      (WidgetTester tester) async {
    final _ControlledAuraPointsService aura =
        _ControlledAuraPointsService(reservedEntry);

    await tester.pumpWidget(_providers(
      aura: aura,
      child: GameScreen.guestTable(
        tableName: 'Career',
        venue: indianVenues.first,
        playIntroWelcome: false,
        venueMode: VenueEntryMode.career,
        campaignGroup: VenueGroup.india,
        campaignSubKingdomIndex: 1,
        campaignEntryReservation: reservedEntry,
      ),
    ));
    await tester.pump();

    expect(aura.commitCalls, 1);
    expect(find.text('SECURING TOURNAMENT ENTRY…'), findsOneWidget);
    expect(find.byType(GameScreenUI), findsNothing);

    aura.commitCompleter.complete(
      EntryPaymentResult(
        status: EntryPaymentStatus.free,
        reservation: reservedEntry.copyWith(state: 'committed'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(GameScreenUI), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(aura.abandonCalls, 1);
  });

  testWidgets('pending entry commit never starts the engine',
      (WidgetTester tester) async {
    final _ControlledAuraPointsService aura =
        _ControlledAuraPointsService(reservedEntry);

    await tester.pumpWidget(_providers(
      aura: aura,
      child: GameScreen.guestTable(
        tableName: 'Career',
        venue: indianVenues.first,
        playIntroWelcome: false,
        venueMode: VenueEntryMode.career,
        campaignGroup: VenueGroup.india,
        campaignSubKingdomIndex: 1,
        campaignEntryReservation: reservedEntry,
      ),
    ));
    aura.commitCompleter.complete(
      EntryPaymentResult(
        status: EntryPaymentStatus.pending,
        reservation: reservedEntry.copyWith(state: 'committing'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(GameScreenUI), findsNothing);
    expect(find.textContaining('still being reconciled'), findsOneWidget);
  });

  testWidgets('interrupted committed entry is visible and recoverable',
      (WidgetTester tester) async {
    final EntryReservation interrupted =
        reservedEntry.copyWith(state: 'committed');
    final _ControlledAuraPointsService aura =
        _ControlledAuraPointsService(interrupted);

    await tester.pumpWidget(_providers(
      aura: aura,
      child: SubKingdomScreen(
        kingdom: indianVenues.first,
        group: VenueGroup.india,
      ),
    ));
    await tester.pump();

    expect(find.textContaining('previous tournament was interrupted'),
        findsOneWidget);
    expect(find.text('RECOVER'), findsOneWidget);

    await tester.tap(find.text('RECOVER'));
    await tester.pump();
    expect(aura.recoveryCalls, 1);
    expect(find.textContaining('entry value was returned'), findsOneWidget);
  });
}
