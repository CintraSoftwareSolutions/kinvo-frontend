import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/premium/domain/plans.dart';

/// Prices, what yearly saves, and a catalogue from a server newer than the app.
///
/// A price on the paywall is a promise: it is formatted from integer minor
/// units exactly as the server sent them, and a saving is worked out from the
/// two prices rather than written into the app.
Map<String, Object?> _product(
  String slug, {
  String tier = 'advanced',
  String cycle = 'monthly',
  int? amountMinor = 1999,
  String currency = 'USD',
}) {
  return {
    'slug': slug,
    'name': 'Kinvo $slug',
    'tier': tier,
    'billing_cycle': cycle,
    'price': amountMinor == null
        ? null
        : {'amount_minor': amountMinor, 'currency': currency},
    'features': ['Unlimited likes'],
  };
}

void main() {
  group('Money', () {
    test('formats minor units exactly, with the symbol where it knows one', () {
      expect(
        const Money(amountMinor: 1999, currency: 'USD').format(),
        r'$19.99',
      );
      expect(const Money(amountMinor: 99, currency: 'USD').format(), r'$0.99');
      expect(
        const Money(amountMinor: 159900, currency: 'USD').format(),
        r'$1,599.00',
      );
      expect(const Money(amountMinor: 750, currency: 'GBP').format(), '£7.50');
      expect(
        const Money(amountMinor: 250000, currency: 'PKR').format(),
        '2,500.00 PKR',
      );
    });

    test('keeps whole currencies whole', () {
      expect(
        const Money(amountMinor: 1500, currency: 'JPY').format(),
        '1,500 JPY',
      );
    });

    test('spreads a yearly price over the months, to the nearest cent', () {
      expect(
        const Money(amountMinor: 15999, currency: 'USD').perMonth(12).format(),
        r'$13.33',
      );
      expect(
        const Money(amountMinor: 7999, currency: 'USD').perMonth(12).format(),
        r'$6.67',
      );
    });
  });

  group('PlanCatalogue', () {
    PlanCatalogue catalogue(List<Map<String, Object?>> products) {
      return PlanCatalogue.fromJson({
        'products': products,
        'purchase_mode': 'test',
      });
    }

    test(
      'works out what yearly saves, rounding down so it never oversells',
      () {
        final plans = catalogue([
          _product('advanced_monthly'),
          _product('advanced_yearly', cycle: 'yearly', amountMinor: 15999),
          _product('basic_monthly', tier: 'basic', amountMinor: 999),
          _product(
            'basic_yearly',
            tier: 'basic',
            cycle: 'yearly',
            amountMinor: 7999,
          ),
        ]);

        // 159.99 against 12 × 19.99 = 239.88 saves 33.3%; 79.99 against 119.88
        // saves 33.27%. "A third off", both.
        expect(plans.savingOverMonthly(plans.bySlug('advanced_yearly')!), 33);
        expect(plans.savingOverMonthly(plans.bySlug('basic_yearly')!), 33);
        expect(
          plans.savingOverMonthly(plans.bySlug('advanced_monthly')!),
          isNull,
        );
      },
    );

    test('claims no saving it cannot show', () {
      // No monthly price to compare with.
      final alone = catalogue([
        _product('advanced_yearly', cycle: 'yearly', amountMinor: 15999),
      ]);
      expect(alone.savingOverMonthly(alone.plans.single), isNull);

      // Two currencies are not comparable.
      final mixed = catalogue([
        _product('advanced_monthly', currency: 'GBP'),
        _product('advanced_yearly', cycle: 'yearly', amountMinor: 15999),
      ]);
      expect(mixed.savingOverMonthly(mixed.bySlug('advanced_yearly')!), isNull);

      // Dearer than paying monthly is no saving at all.
      final dearer = catalogue([
        _product('advanced_monthly', amountMinor: 1000),
        _product('advanced_yearly', cycle: 'yearly', amountMinor: 13000),
      ]);
      expect(
        dearer.savingOverMonthly(dearer.bySlug('advanced_yearly')!),
        isNull,
      );
    });

    test('leaves out plans this version cannot describe', () {
      final plans = catalogue([
        _product('advanced_monthly'),
        _product('platinum_monthly', tier: 'platinum'),
        _product('advanced_weekly', cycle: 'weekly'),
        // The free tier is not a thing to buy.
        _product('free_monthly', tier: 'free', amountMinor: 0),
      ]);

      expect(plans.plans.map((plan) => plan.slug), ['advanced_monthly']);
    });

    test('buys nothing in a mode it does not know', () {
      PurchaseMode mode(Object? value) {
        return PlanCatalogue.fromJson({
          'products': const [],
          'purchase_mode': value,
        }).purchaseMode;
      }

      expect(mode('test'), PurchaseMode.test);
      expect(mode('none'), PurchaseMode.none);
      expect(mode('store'), PurchaseMode.none);
      expect(mode(null), PurchaseMode.none);
      expect(mode(1), PurchaseMode.none);
    });

    test('shows a plan with no current price, which cannot be bought', () {
      final plans = catalogue([
        _product('advanced_monthly', amountMinor: null),
      ]);

      expect(plans.plans.single.price, isNull);
    });
  });

  group('CurrentPlan', () {
    Map<String, Object?> subscription({
      bool isActive = true,
      String source = 'test',
    }) {
      return {
        'id': 'subscription-1',
        'tier': 'advanced',
        'billing_cycle': 'yearly',
        'product_slug': 'advanced_yearly',
        'status': isActive ? 'active' : 'expired',
        'source': source,
        'current_period_start': '2026-09-24T07:13:30.000Z',
        'current_period_end': '2027-09-24T07:13:30.000Z',
        'auto_renew': false,
        'is_active': isActive,
        'cancelled_at': null,
        'created_at': '2026-09-24T07:13:30.000Z',
      };
    }

    test('reads a live test plan', () {
      final plan = CurrentPlan.fromJson({
        'tier': 'advanced',
        'subscription': subscription(),
      });

      expect(plan.tier, PlanTier.premium);
      expect(plan.live?.isTest, isTrue);
      expect(plan.live?.periodEnd, DateTime.utc(2027, 9, 24, 7, 13, 30));
    });

    test('keeps a plan that has ended, without calling it live', () {
      final plan = CurrentPlan.fromJson({
        'tier': 'free',
        'subscription': subscription(isActive: false),
      });

      expect(plan.tier, PlanTier.free);
      expect(plan.subscription, isNotNull);
      expect(plan.live, isNull);
    });

    test('never reads a paid tier it does not know as free', () {
      final plan = CurrentPlan.fromJson({
        'tier': 'platinum',
        'subscription': null,
      });

      expect(plan.tier, isNull);
      expect(plan.isPaid, isTrue);
    });
  });
}
