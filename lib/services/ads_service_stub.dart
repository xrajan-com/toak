import 'ads_service_api.dart';

class _NoOpAdsService implements AdsService {
  @override
  bool get rewardedAdsSupported => false;

  @override
  String get rewardedAdUnavailableMessage => 'Ads are disabled in this build.';

  @override
  Future<void> init() async {}

  @override
  Future<void> preloadMatchEndInterstitial() async {}

  @override
  Future<void> preloadRewardedAd() async {}

  @override
  Future<void> showMatchEndInterstitial() async {}

  @override
  Future<bool> showRewardedAd() async => false;
}

AdsService createAdsService() => _NoOpAdsService();
