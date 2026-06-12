abstract class AdsService {
  bool get rewardedAdsSupported;
  String get rewardedAdUnavailableMessage;

  Future<void> init();
  Future<void> preloadMatchEndInterstitial();
  Future<void> preloadRewardedAd();
  Future<void> showMatchEndInterstitial();
  Future<bool> showRewardedAd();
}
