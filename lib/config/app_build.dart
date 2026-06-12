enum AppBuildChannel {
  closedTesting,
  publicRelease,
}

class AppBuild {
  final AppBuildChannel channel;
  final String name;
  final bool enableBotTraining;

  const AppBuild._({
    required this.channel,
    required this.name,
    required this.enableBotTraining,
  });

  static const AppBuild closedTesting = AppBuild._(
    channel: AppBuildChannel.closedTesting,
    name: 'closed-testing',
    enableBotTraining: true,
  );

  static const AppBuild publicRelease = AppBuild._(
    channel: AppBuildChannel.publicRelease,
    name: 'public-release',
    enableBotTraining: false,
  );

  static AppBuild current = publicRelease;

  static void use(AppBuild build) {
    current = build;
  }
}
