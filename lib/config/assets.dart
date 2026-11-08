class AppAssets {
  // 🔹 Logos and Branding
  static const String logo = 'assets/images/x_poker_logo.png';
  static const String renoirDealer = 'assets/images/renoir_tux.png';

  // 🔹 Cards
  static const String cardBack = 'assets/images/cards/back_custom_07.webp';
  static const String cardBasePath = 'assets/images/cards/';
  static String card(String rank, String suit) =>
      '$cardBasePath${rank}_of_$suit.png';

  // 🔹 Avatars
  static const String defaultAvatar = 'assets/images/default_profile.png';

  // 🔹 Sounds
  static const String shuffleSound = 'assets/sounds/shuffle.wav';
  static const String dealCardSound = shuffleSound; // reuse shuffle for deals
  static const String foldSound = 'assets/sounds/fold.wav';
  static const String checkSound = 'assets/sounds/check.wav';
  static const String coinSound = 'assets/sounds/coin.wav';
  static const String betSound = 'assets/sounds/bet.wav';
  // Every chip that goes into the pot clinks (coinSound); a bet or raise adds
  // the heavier stack push (betSound) on top.
  static const String raiseSound = betSound;
  // Chips swept to the winner of a hand: eight clinks from coin.wav and
  // bet.wav, pitched and staggered (built with ffmpeg, Oct 2026).
  static const String chipsRakeSound = 'assets/sounds/chips_rake.wav';
  static const String actionTapSound = 'assets/sounds/action.wav';
  static const String heroTurnNotificationSound =
      'assets/sounds/notification.mp3';
  static const String playerAllInSound = 'assets/sounds/all_in_warning.wav';
  static const String welcomeSound = 'assets/sounds/welcome.wav';
  static const String gameWinSound = 'assets/sounds/game_win_epic.wav';
  // Fanfare kept for big pots the player wins.
  static const String heroLeaderSound = 'assets/sounds/hand winner hero.wav';
  static const String heroDangerSound = playerAllInSound;
  static const String playerBustedSound = 'assets/sounds/shatter.wav';
  static const String heroBustSound = 'assets/sounds/hero bust.wav';
  static const String potIncreaseSound = coinSound;
  static const String cameraSound = 'assets/sounds/camera.wav';
  static const String applauseSound = 'assets/sounds/applause.wav';
  // Win fireworks, built by tools/sounds/build_fireworks.py: two near booms
  // and two distant ones, picked at random, plus a launch and a crackle.
  static const String fireworkLaunchSound = 'assets/sounds/firework_launch.wav';
  static const List<String> fireworkBoomSounds = <String>[
    'assets/sounds/firework_boom_1.wav',
    'assets/sounds/firework_boom_2.wav',
  ];
  static const List<String> fireworkFarSounds = <String>[
    'assets/sounds/firework_far_1.wav',
    'assets/sounds/firework_far_2.wav',
  ];
  static const String fireworkCrackleSound =
      'assets/sounds/firework_crackle.wav';
  static const String doorKnockSound = 'assets/sounds/door_knock.mp3';
  static const String knock1Sound = 'assets/sounds/knock1.wav';
  static const String renoirFemaleCheckAnnouncer =
      'assets/sounds/announcer/female/renoir_female_check.mp3';
  static const String renoirFemaleCallAnnouncer =
      'assets/sounds/announcer/female/renoir_female_call.mp3';
  static const String renoirFemaleRaiseAnnouncer =
      'assets/sounds/announcer/female/renoir_female_raise.mp3';
  static const String renoirFemaleAllInAnnouncer =
      'assets/sounds/announcer/female/renoir_female_all_in.mp3';
  static const String renoirFemaleFoldAnnouncer =
      'assets/sounds/announcer/female/renoir_female_fold.mp3';

  // 🔹 Backgrounds
  static const String tableBackground = logo;
}
