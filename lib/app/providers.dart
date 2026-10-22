import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/app_settings_service.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/game_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    ChangeNotifierProvider(
      create: (_) {
        final settings = AppSettingsService();
        settings.load();
        return settings;
      },
    ),
    ChangeNotifierProvider(create: (_) => AuthService()),
    ChangeNotifierProxyProvider<AuthService, AuraPointsService>(
      create: (_) => AuraPointsService(),
      update: (_, auth, aura) {
        // Guest (anonymous) accounts play Career on a server wallet of their
        // own; only local guests, with no account at all, stay on-device.
        final user = auth.currentUser;
        return aura!
          ..bindUserId(
            user?.uid,
            registeredUser: user != null && !user.isAnonymous,
          );
      },
    ),
    ChangeNotifierProxyProvider<AuthService, ProfileService>(
      create: (_) => ProfileService(),
      update: (_, auth, profile) => profile!..bindUserId(auth.currentUser?.uid),
    ),
    ChangeNotifierProvider(create: (_) => GameService()),
    ChangeNotifierProxyProvider<AuthService, CampaignProgressService>(
      create: (_) => CampaignProgressService(),
      update: (_, auth, progress) =>
          progress!..bindUserId(auth.currentUser?.uid),
    ),
  ];
}
