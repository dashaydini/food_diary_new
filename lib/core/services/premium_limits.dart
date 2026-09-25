import 'premium_service.dart';

class PremiumLimits {
  PremiumLimits._();

  static const int freeSavedPlacesPerList = 5;
  static const int freeCollections = 5;
  static const int freeVisitsPerCollection = 3;
  static const int freeImagesPerExperience = 3;
  static const int premiumImagesPerExperience = 10;

  static int get imagesPerExperience => PremiumService.isPremium
      ? premiumImagesPerExperience
      : freeImagesPerExperience;
}
