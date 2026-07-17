import 'localization.dart';

enum TaploeCatalogPlan { premium, business }

enum TaploeCatalogPeriod { monthly, annual }

class TaploePrice {
  final double amount;
  final String currency;

  const TaploePrice({required this.amount, required this.currency});

  String format() => '${_money(amount)} $currency';
}

class TaploePricing {
  static final double usdToMxnRate =
      double.tryParse(
        const String.fromEnvironment('TAPLOE_USD_MXN_RATE', defaultValue: '18'),
      ) ??
      18;
  static const int businessMinProfiles = 5;
  static const int businessMaxProfiles = 500;

  static const double _premiumMonthlyUsd = 9.99;
  static const double _premiumAnnualUsd = 87.99;
  static const double _businessMonthlyUsd = 4.99;
  static const double _businessAnnualUsd = 43.99;

  static TaploePrice unitPrice({
    required TaploeCatalogPlan plan,
    required TaploeCatalogPeriod period,
    required TaploeLocaleConfig locale,
  }) {
    final usd = switch ((plan, period)) {
      (TaploeCatalogPlan.premium, TaploeCatalogPeriod.monthly) =>
        _premiumMonthlyUsd,
      (TaploeCatalogPlan.premium, TaploeCatalogPeriod.annual) =>
        _premiumAnnualUsd,
      (TaploeCatalogPlan.business, TaploeCatalogPeriod.monthly) =>
        _businessMonthlyUsd,
      (TaploeCatalogPlan.business, TaploeCatalogPeriod.annual) =>
        _businessAnnualUsd,
    };
    final currency = locale.currencyCode;
    return TaploePrice(
      amount: currency == 'MXN' ? usd * usdToMxnRate : usd,
      currency: currency,
    );
  }

  static TaploePrice monthlyEquivalent({
    required TaploeCatalogPlan plan,
    required TaploeCatalogPeriod period,
    required TaploeLocaleConfig locale,
  }) {
    final unit = unitPrice(plan: plan, period: period, locale: locale);
    return TaploePrice(
      amount: period == TaploeCatalogPeriod.annual
          ? unit.amount / 12
          : unit.amount,
      currency: unit.currency,
    );
  }

  static TaploePrice total({
    required TaploeCatalogPlan plan,
    required TaploeCatalogPeriod period,
    required TaploeLocaleConfig locale,
    int quantity = 1,
  }) {
    final unit = unitPrice(plan: plan, period: period, locale: locale);
    return TaploePrice(
      amount: unit.amount * (plan == TaploeCatalogPlan.business ? quantity : 1),
      currency: unit.currency,
    );
  }

  static int annualSavingsPercent(TaploeCatalogPlan plan) {
    final monthly = switch (plan) {
      TaploeCatalogPlan.premium => _premiumMonthlyUsd,
      TaploeCatalogPlan.business => _businessMonthlyUsd,
    };
    final annual = switch (plan) {
      TaploeCatalogPlan.premium => _premiumAnnualUsd,
      TaploeCatalogPlan.business => _businessAnnualUsd,
    };
    return ((1 - (annual / (monthly * 12))) * 100).round();
  }
}

String _money(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return '\$${buffer.toString()}.${parts.last}';
}
