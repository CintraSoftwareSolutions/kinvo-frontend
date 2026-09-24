import 'package:flutter/foundation.dart';

import '../../../core/network/api_envelope.dart';

/// A plan's level. What each one unlocks is decided on the server (spec
/// §5.11); the app only names them.
enum PlanTier {
  free('free', 'Free'),
  basic('basic', 'Basic'),

  /// The server calls it `advanced`; people are sold "Premium".
  premium('advanced', 'Premium');

  const PlanTier(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// Null for a tier added to the server after this version of the app. It is
  /// never guessed at: reading an unknown paid tier as Free would tell someone
  /// who pays that they don't.
  static PlanTier? tryFromWireValue(String? value) {
    for (final tier in values) {
      if (tier.wireValue == value) return tier;
    }
    return null;
  }
}

/// How often a plan is paid for.
enum BillingCycle {
  monthly('monthly', 1, 'Monthly'),
  quarterly('quarterly', 3, 'Quarterly'),
  yearly('yearly', 12, 'Yearly');

  const BillingCycle(this.wireValue, this.months, this.label);

  final String wireValue;
  final int months;
  final String label;

  static BillingCycle? tryFromWireValue(String? value) {
    for (final cycle in values) {
      if (cycle.wireValue == value) return cycle;
    }
    return null;
  }
}

/// An amount as the server sends it: integer minor units and a currency (spec
/// §4.6). Never a double, so no price is ever a rounding error away from the
/// one on the server.
@immutable
final class Money {
  const Money({required this.amountMinor, required this.currency});

  factory Money.fromJson(JsonMap json) {
    if (json case {
      'amount_minor': final int amountMinor,
      'currency': final String currency,
    }) {
      return Money(amountMinor: amountMinor, currency: currency.toUpperCase());
    }
    throw const FormatException('Expected amount_minor and currency.');
  }

  final int amountMinor;

  /// ISO 4217, such as `USD`.
  final String currency;

  static const _symbols = {'USD': r'$', 'GBP': '£', 'EUR': '€'};

  /// Currencies with no minor unit: their amounts are already whole.
  static const _wholeCurrencies = {'JPY', 'KRW'};

  /// "$19.99", "£7.50", or "2,500.00 PKR" for a currency without a symbol
  /// here. Formatted by hand rather than with a locale library, because the
  /// only thing that varies is the symbol and a price must never be rounded.
  String format() {
    final whole = _wholeCurrencies.contains(currency);
    final divisor = whole ? 1 : 100;
    final negative = amountMinor < 0;
    final absolute = amountMinor.abs();

    final major = _group(absolute ~/ divisor);
    final minor = whole
        ? ''
        : '.${(absolute % divisor).toString().padLeft(2, '0')}';
    final amount = '${negative ? '-' : ''}$major$minor';

    return switch (_symbols[currency]) {
      final symbol? => '$symbol$amount',
      null => '$amount $currency',
    };
  }

  /// This amount spread evenly over [months], to the nearest minor unit —
  /// what a yearly plan costs a month.
  Money perMonth(int months) {
    return Money(
      amountMinor: (amountMinor / months).round(),
      currency: currency,
    );
  }

  static String _group(int value) {
    final digits = value.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return grouped.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.amountMinor == amountMinor &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(amountMinor, currency);

  @override
  String toString() => format();
}

/// One thing on sale: a tier, paid monthly or yearly.
@immutable
final class Plan {
  const Plan({
    required this.slug,
    required this.name,
    required this.tier,
    required this.cycle,
    required this.features,
    this.price,
  });

  /// The plan in [json], or null for one this version can't sell properly — a
  /// tier or a billing cycle added to the server since. Leaving it out is
  /// safe; offering it with the wrong description is not.
  static Plan? tryFromJson(JsonMap json) {
    if (json case {
      'slug': final String slug,
      'name': final String name,
      'tier': final String tier,
      'billing_cycle': final String cycle,
      'price': final JsonMap? price,
    }) {
      final planTier = PlanTier.tryFromWireValue(tier);
      final billingCycle = BillingCycle.tryFromWireValue(cycle);
      if (planTier == null || planTier == PlanTier.free) return null;
      if (billingCycle == null) return null;

      return Plan(
        slug: slug,
        name: name,
        tier: planTier,
        cycle: billingCycle,
        price: price == null ? null : Money.fromJson(price),
        features: switch (json['features']) {
          final List<Object?> features => [
            for (final feature in features)
              if (feature is String && feature.trim().isNotEmpty) feature,
          ],
          _ => const [],
        },
      );
    }
    throw const FormatException(
      'Expected a product with slug, name, tier, billing_cycle and price.',
    );
  }

  /// The server's id for it, such as `advanced_monthly`.
  final String slug;

  final String name;
  final PlanTier tier;
  final BillingCycle cycle;

  /// Null when the server has no current price, which it can between a price
  /// ending and the next starting. Such a plan is shown but can't be bought.
  final Money? price;

  /// What the plan adds over the free tier, in the server's words — written
  /// from the same rules that decide what it unlocks.
  final List<String> features;

  @override
  bool operator ==(Object other) => other is Plan && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}

/// How a plan can be bought on this server.
enum PurchaseMode {
  /// Staging's stand-in for payments: the plan starts at once and no money is
  /// taken.
  test('test'),

  /// Not yet — until RevenueCat arrives.
  none('none');

  const PurchaseMode(this.wireValue);

  final String wireValue;

  /// Anything unrecognised is [none]: a mode this version doesn't know is not
  /// one it can buy with.
  static PurchaseMode fromWireValue(String? value) {
    return value == test.wireValue ? test : none;
  }
}

/// Everything on sale, from `GET /subscriptions/products`.
@immutable
final class PlanCatalogue {
  const PlanCatalogue({required this.plans, required this.purchaseMode});

  factory PlanCatalogue.fromJson(JsonMap json) {
    if (json case {'products': final List<Object?> products}) {
      return PlanCatalogue(
        plans: [
          for (final product in products)
            if (product is JsonMap) ?Plan.tryFromJson(product),
        ],
        purchaseMode: PurchaseMode.fromWireValue(
          switch (json['purchase_mode']) {
            final String mode => mode,
            _ => null,
          },
        ),
      );
    }
    throw const FormatException('Expected products.');
  }

  final List<Plan> plans;
  final PurchaseMode purchaseMode;

  /// The tiers on sale, cheapest first.
  List<PlanTier> get tiers => [
    for (final tier in PlanTier.values)
      if (plans.any((plan) => plan.tier == tier)) tier,
  ];

  /// [tier]'s plans, shortest billing cycle first.
  List<Plan> plansFor(PlanTier tier) {
    return [
      for (final cycle in BillingCycle.values)
        ...plans.where((plan) => plan.tier == tier && plan.cycle == cycle),
    ];
  }

  Plan? bySlug(String slug) {
    for (final plan in plans) {
      if (plan.slug == slug) return plan;
    }
    return null;
  }

  /// How much less [plan] costs than paying monthly for the same stretch, as
  /// a whole percentage rounded down, so it never overstates: "a third off"
  /// reads as 33. Null when there is nothing to compare with, or nothing is
  /// saved.
  int? savingOverMonthly(Plan plan) {
    if (plan.cycle == BillingCycle.monthly) return null;

    final monthly = plansFor(
      plan.tier,
    ).where((candidate) => candidate.cycle == BillingCycle.monthly).firstOrNull;
    final price = plan.price;
    final monthlyPrice = monthly?.price;
    if (price == null || monthlyPrice == null) return null;
    if (price.currency != monthlyPrice.currency) return null;

    final paidMonthly = monthlyPrice.amountMinor * plan.cycle.months;
    if (paidMonthly <= 0 || price.amountMinor >= paidMonthly) return null;

    return ((paidMonthly - price.amountMinor) * 100) ~/ paidMonthly;
  }
}

/// A subscription the account holds, from `GET /subscriptions/me`.
@immutable
final class PlanSubscription {
  const PlanSubscription({
    required this.productSlug,
    required this.tier,
    required this.cycle,
    required this.isTest,
    required this.isActive,
    required this.renews,
    required this.periodEnd,
  });

  factory PlanSubscription.fromJson(JsonMap json) {
    if (json case {
      'product_slug': final String productSlug,
      'tier': final String tier,
      'billing_cycle': final String cycle,
      'source': final String source,
      'current_period_end': final String periodEnd,
      'auto_renew': final bool autoRenew,
      'is_active': final bool isActive,
    }) {
      return PlanSubscription(
        productSlug: productSlug,
        tier: PlanTier.tryFromWireValue(tier),
        cycle: BillingCycle.tryFromWireValue(cycle),
        isTest: source == 'test',
        isActive: isActive,
        renews: autoRenew,
        periodEnd: DateTime.parse(periodEnd),
      );
    }
    throw const FormatException(
      'Expected a subscription with product_slug, tier, billing_cycle, '
      'source, current_period_end, auto_renew and is_active.',
    );
  }

  /// The plan it is for, such as `advanced_monthly`.
  final String productSlug;

  final PlanTier? tier;
  final BillingCycle? cycle;

  /// Granted by a test purchase on staging: no money was taken, and it can be
  /// ended from the app.
  final bool isTest;

  /// Whether it unlocks anything now. The server decides: a cancelled store
  /// plan stays live until its period ends, and a test plan counts only where
  /// test purchases are on.
  final bool isActive;

  final bool renews;

  /// When it ends, or renews.
  final DateTime periodEnd;
}

/// The account's plan, from `GET /subscriptions/me`.
@immutable
final class CurrentPlan {
  const CurrentPlan({required this.tier, this.subscription});

  factory CurrentPlan.fromJson(JsonMap json) {
    if (json case {
      'tier': final String tier,
      'subscription': final JsonMap? subscription,
    }) {
      return CurrentPlan(
        tier: PlanTier.tryFromWireValue(tier),
        subscription: subscription == null
            ? null
            : PlanSubscription.fromJson(subscription),
      );
    }
    throw const FormatException('Expected tier and subscription.');
  }

  /// No plan: what an account has before it buys one.
  static const free = CurrentPlan(tier: PlanTier.free);

  /// What the account is entitled to now. Null for a tier added to the server
  /// since this version: paid, but not one the app can name.
  final PlanTier? tier;

  /// The most recent subscription, live or not. Null when there has never
  /// been one.
  final PlanSubscription? subscription;

  /// The subscription giving the account its tier now, if any.
  PlanSubscription? get live =>
      subscription?.isActive == true ? subscription : null;

  bool get isPaid => tier != PlanTier.free;

  /// Whether [plan] is the one the account is on now.
  bool isOn(Plan plan) => live?.productSlug == plan.slug;
}
