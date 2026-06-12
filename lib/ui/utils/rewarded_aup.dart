import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/services/ads_service.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';

String rewardedAupOfferLabel({String? circuitLabel}) {
  if (!adsService.rewardedAdsSupported) {
    return 'Rewarded ads disabled';
  }

  final String bonusLabel = aup.formatAup(aup.kRewardedAdAupBonus);
  final String suffix = (circuitLabel ?? '').trim();
  if (suffix.isEmpty) {
    return 'Watch ad for +$bonusLabel AUP';
  }
  return 'Watch ad for +$bonusLabel AUP ($suffix)';
}

String rewardedAupUnavailableMessage() =>
    adsService.rewardedAdUnavailableMessage;

Future<int> tryAwardRewardedAdAup(
  BuildContext context, {
  required VenueGroup group,
}) async {
  final bool earned = await adsService.showRewardedAd();
  if (!earned || !context.mounted) return 0;
  return context.read<AuraPointsService>().awardRewardedAdBonus(
        group: group,
        amount: aup.kRewardedAdAupBonus,
      );
}
