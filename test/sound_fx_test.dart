import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/assets.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';

void main() {
  final SoundFx fx = SoundFx.instance;
  final List<String> played = <String>[];

  setUp(() async {
    played.clear();
    fx.debugOnPlay = (String asset, double volume) {
      expect(volume, inInclusiveRange(0.0, 1.0), reason: asset);
      played.add(asset);
    };
    fx.setSoundEffectsMuted(false);
    fx.setVoiceMuted(false);
    fx.setVoiceEveryAction(false);
    await fx.stopAll();
  });

  tearDown(() {
    fx.debugOnPlay = null;
    fx.setVoiceEveryAction(false);
  });

  bool spoke() => played.any((String a) => a.contains('/announcer/'));

  test('community cards are a card sound, never the spoken "Fold"', () async {
    // The flop's three cards arrive together and share one sound.
    await fx.playBoardCard();
    await fx.playBoardCard();
    await fx.playBoardCard();

    expect(played, <String>[AppAssets.foldSound]);
    expect(spoke(), isFalse);
  });

  test('by default the dealer calls all-ins only', () async {
    await fx.playFold();
    await fx.playCheck();
    await fx.playCallCoin();
    await fx.playRaiseAtm();
    expect(spoke(), isFalse);
    expect(played, <String>[
      AppAssets.foldSound,
      AppAssets.checkSound,
      AppAssets.raiseSound,
    ]);

    played.clear();
    await fx.playPlayerAllIn();
    expect(played, contains(AppAssets.renoirFemaleAllInAnnouncer));
  });

  test('"Call every action" brings back the spoken calls', () async {
    fx.setVoiceEveryAction(true);
    await fx.playFold();
    await fx.playCallCoin();

    expect(played, contains(AppAssets.renoirFemaleFoldAnnouncer));
    expect(played, contains(AppAssets.renoirFemaleCallAnnouncer));
  });

  test('a pot a bot wins is chips only; a big pot for the player gets the '
      'fanfare', () async {
    await fx.playChipsToWinner(heroWon: false);
    expect(played, <String>[AppAssets.chipsRakeSound]);

    played.clear();
    await fx.playChipsToWinner(heroWon: true);
    expect(played, <String>[AppAssets.chipsRakeSound]);

    played.clear();
    await fx.playChipsToWinner(heroWon: true, bigPot: true);
    expect(played, <String>[AppAssets.heroLeaderSound, AppAssets.chipsRakeSound]);
  });

  test('blinds landing together clink once', () async {
    await fx.playPotIncrease();
    await fx.playPotIncrease();
    expect(played, <String>[AppAssets.potIncreaseSound]);
  });

  test('muted sound effects stay silent', () async {
    fx.setSoundEffectsMuted(true);
    await fx.playBoardCard();
    await fx.playChipsToWinner(heroWon: true, bigPot: true);
    expect(played, isEmpty);
  });

  test('fireworks play their own files, and nothing when muted', () async {
    for (final FireworkSound sound in FireworkSound.values) {
      await fx.playFirework(sound);
    }
    expect(played, hasLength(FireworkSound.values.length));
    expect(played[0], AppAssets.fireworkLaunchSound);
    expect(AppAssets.fireworkBoomSounds, contains(played[1]));
    expect(AppAssets.fireworkFarSounds, contains(played[2]));
    expect(played[3], AppAssets.fireworkCrackleSound);

    played.clear();
    fx.setSoundEffectsMuted(true);
    await fx.playFirework(FireworkSound.boom);
    expect(played, isEmpty);
  });

  test('every table sound file is in the app bundle', () {
    for (final String asset in <String>[
      AppAssets.fireworkLaunchSound,
      ...AppAssets.fireworkBoomSounds,
      ...AppAssets.fireworkFarSounds,
      AppAssets.fireworkCrackleSound,
      AppAssets.shuffleSound,
      AppAssets.foldSound,
      AppAssets.checkSound,
      AppAssets.coinSound,
      AppAssets.betSound,
      AppAssets.chipsRakeSound,
      AppAssets.heroLeaderSound,
      AppAssets.heroBustSound,
      AppAssets.playerBustedSound,
      AppAssets.gameWinSound,
      AppAssets.applauseSound,
      AppAssets.heroTurnNotificationSound,
      AppAssets.renoirFemaleAllInAnnouncer,
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });
}
