import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/game_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/services/stat_service.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    ChangeNotifierProvider(create: (_) => AuthService()),
    ChangeNotifierProxyProvider<AuthService, AuraPointsService>(
      create: (_) => AuraPointsService(),
      update: (_, auth, aura) {
        final user = auth.currentUser;
        final registeredUid =
            user != null && !user.isAnonymous ? user.uid : null;
        return aura!
          ..bindUserId(
            registeredUid,
            registeredUser: registeredUid != null,
          );
      },
    ),
    ChangeNotifierProxyProvider<AuthService, ProfileService>(
      create: (_) => ProfileService(),
      update: (_, auth, profile) => profile!..bindUserId(auth.currentUser?.uid),
    ),
    ChangeNotifierProvider(create: (_) => StatService()),
    ChangeNotifierProvider(create: (_) => GameService()),
    ChangeNotifierProxyProvider<AuthService, CampaignProgressService>(
      create: (_) => CampaignProgressService(),
      update: (_, auth, progress) =>
          progress!..bindUserId(auth.currentUser?.uid),
    ),
  ];
}
