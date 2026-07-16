import 'models.dart';

enum TaploePlan { free, pro, business, enterprise }

TaploePlan taploePlanFromString(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'premium':
    case 'pro':
      return TaploePlan.pro;
    case 'empresa':
    case 'business':
      return TaploePlan.business;
    case 'enterprise':
      return TaploePlan.enterprise;
    default:
      return TaploePlan.free;
  }
}

class TaploePlanCapabilities {
  final TaploePlan plan;

  const TaploePlanCapabilities(this.plan);

  bool get isPro => plan == TaploePlan.pro;
  bool get isBusiness =>
      plan == TaploePlan.business || plan == TaploePlan.enterprise;
  bool get hasPremiumFeatures => isPro || isBusiness;

  bool get canShowVerifiedBadge => hasPremiumFeatures;
  bool get canRemoveTaploeWatermark => hasPremiumFeatures;
  bool get canViewAnalytics => hasPremiumFeatures;
  bool get canViewLeads => hasPremiumFeatures;
  bool get canUseDesign => hasPremiumFeatures;
  bool get canUseForms => hasPremiumFeatures;
  bool get canUseIntegrations => hasPremiumFeatures;
  bool get canViewTeam => isBusiness;
  bool get canViewAdmin => isBusiness;

  int? get maxProfiles {
    if (isBusiness) return null;
    if (isPro) return 5;
    return 1;
  }

  String get label {
    switch (plan) {
      case TaploePlan.pro:
        return 'Premium';
      case TaploePlan.business:
        return 'Empresa';
      case TaploePlan.enterprise:
        return 'Enterprise';
      case TaploePlan.free:
        return 'Gratis';
    }
  }

  String get upgradeLabel => isBusiness ? 'Plan activo' : 'Actualizar plan';

  bool canCreateProfile(int currentProfileCount) {
    final limit = maxProfiles;
    return limit == null || currentProfileCount < limit;
  }
}

TaploePlanCapabilities taploeCapabilitiesFor({
  AppUserModel? user,
  OrganizationModel? organization,
  BillingSubscriptionModel? userSubscription,
  BillingSubscriptionModel? organizationSubscription,
}) {
  if (organizationSubscription?.grantsAccess == true) {
    final orgPlan = taploePlanFromString(
      organizationSubscription?.planType ?? organization?.planType,
    );
    if (orgPlan == TaploePlan.business || orgPlan == TaploePlan.enterprise) {
      return TaploePlanCapabilities(orgPlan);
    }
  }

  if (userSubscription?.grantsAccess == true) {
    final subscriptionPlan = taploePlanFromString(userSubscription?.planType);
    if (subscriptionPlan == TaploePlan.pro) {
      return TaploePlanCapabilities(subscriptionPlan);
    }
  }

  final userPlan = taploePlanFromString(user?.planType);
  return TaploePlanCapabilities(
    userPlan == TaploePlan.pro ? TaploePlan.pro : TaploePlan.free,
  );
}
