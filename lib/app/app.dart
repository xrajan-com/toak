import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/app/providers.dart';
import 'package:ten_of_a_kind_poker/app/scroll_behavior.dart';
import 'package:ten_of_a_kind_poker/app/startup/disclaimer_splash.dart';
import 'package:ten_of_a_kind_poker/services/app_settings_service.dart';
import 'package:ten_of_a_kind_poker/themes/app_theme.dart';

class TenOfAKindApp extends StatelessWidget {
  const TenOfAKindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: MaterialApp(
        title: 'Ten of a Kind - Poker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        scrollBehavior: const AppScrollBehavior(),
        home: const DisclaimerSplash(),
        builder: (BuildContext context, Widget? child) {
          final AppSettingsService settings =
              context.watch<AppSettingsService>();
          final MediaQueryData media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations || settings.reducedMotion,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
