import { requireEnv } from "./env.ts";

export type TaploeCheckoutPlan = "premium" | "business";
export type TaploeBillingPeriod = "monthly" | "annual";
export type TaploeMarket = "mx" | "us";

export const stripeCatalog = {
  premium: {
    productEnv: "STRIPE_PREMIUM_PRODUCT_ID",
    prices: {
      us: {
        monthly: "STRIPE_PREMIUM_MONTHLY_PRICE_ID",
        annual: "STRIPE_PREMIUM_ANNUAL_PRICE_ID",
      },
      mx: {
        monthly: "STRIPE_PREMIUM_MONTHLY_PRICE_ID_MXN",
        annual: "STRIPE_PREMIUM_ANNUAL_PRICE_ID_MXN",
      },
    },
  },
  business: {
    productEnv: "STRIPE_BUSINESS_PRODUCT_ID",
    prices: {
      us: {
        monthly: "STRIPE_BUSINESS_MONTHLY_PRICE_ID",
        annual: "STRIPE_BUSINESS_ANNUAL_PRICE_ID",
      },
      mx: {
        monthly: "STRIPE_BUSINESS_MONTHLY_PRICE_ID_MXN",
        annual: "STRIPE_BUSINESS_ANNUAL_PRICE_ID_MXN",
      },
    },
  },
} as const;

export function stripeProductId(plan: TaploeCheckoutPlan): string {
  return requireEnv(stripeCatalog[plan].productEnv);
}

export function stripePriceId(
  plan: TaploeCheckoutPlan,
  market: TaploeMarket,
  billingPeriod: TaploeBillingPeriod,
): string {
  return requireEnv(stripeCatalog[plan].prices[market][billingPeriod]);
}

export function planFromPriceId(priceId: string | null | undefined): {
  plan: TaploeCheckoutPlan | null;
  billingPeriod: TaploeBillingPeriod | null;
  productId: string | null;
} {
  for (const plan of ["premium", "business"] as const) {
    for (const market of ["mx", "us"] as const) {
      for (const billingPeriod of ["monthly", "annual"] as const) {
        const configuredPriceId = Deno.env.get(
          stripeCatalog[plan].prices[market][billingPeriod],
        );
        if (configuredPriceId && configuredPriceId === priceId) {
          return {
            plan,
            billingPeriod,
            productId: Deno.env.get(stripeCatalog[plan].productEnv) ?? null,
          };
        }
      }
    }
  }
  return { plan: null, billingPeriod: null, productId: null };
}
