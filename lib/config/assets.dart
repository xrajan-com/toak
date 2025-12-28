class AppAssets {
  // 🔹 Logos and Branding
  static const String logo = 'assets/images/app_icon.png';
  static const String renoirDealer = 'assets/images/renoir.png';

  // 🔹 Cards
  static const String cardBack = 'assets/images/cards/back.png';
  static const String cardBasePath = 'assets/images/cards/';
  static String card(String rank, String suit) =>
      '$cardBasePath${rank}_of_$suit.png';

  // 🔹 Avatars
  static const String defaultAvatar = 'assets/images/avatars/default.png';

  // 🔹 Sounds (limited to the 8 clips currently available)
  static const String shuffleSound = 'assets/sounds/shuffle.wav';
  static const String dealCardSound = shuffleSound; // reuse shuffle for deals
  static const String foldSound = 'assets/sounds/fold.wav';
  static const String checkSound = 'assets/sounds/check.wav';
  static const String coinSound = 'assets/sounds/coin.wav';
  static const String betSound = 'assets/sounds/bet.wav';
  // Swapped per request:
  // - calls use bet.wav
  // - bet/raise uses coin.wav
  static const String callCoinSound = betSound;
  static const String raiseSound = coinSound;
  static const String playerAllInSound = 'assets/sounds/all_in_warning.wav';
  static const String welcomeSound = 'assets/sounds/welcome.wav';
  static const String handWinSound = 'assets/sounds/hand winner.wav';
  static const String gameWinSound = 'assets/sounds/game_win_epic.wav';
  static const String gameLostSound = foldSound; // temporary placeholder
  static const String heroLeaderSound = 'assets/sounds/hand winner hero.wav';
  static const String heroDangerSound = playerAllInSound;
  static const String playerBustedSound = 'assets/sounds/shatter.wav';
  static const String heroBustSound = 'assets/sounds/hero bust.wav';
  static const String potIncreaseSound = coinSound;
  static const String heroTurnSound = 'assets/sounds/notification.mp3';
  static const String cameraSound = 'assets/sounds/camera.wav';
  static const String applauseSound = 'assets/sounds/applause.wav';
  static const String doorKnockSound = 'assets/sounds/door_knock.mp3';
  static const String knock1Sound = 'assets/sounds/knock1.wav';

  // 🔹 Backgrounds
  static const String tableBackground = 'assets/images/table_bg.png';
}
