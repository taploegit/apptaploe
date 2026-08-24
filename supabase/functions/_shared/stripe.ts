import Stripe from "https://esm.sh/stripe@16.12.0?target=deno";
import { requireEnv } from "./env.ts";

function stripeSecretKey(): string {
  return Deno.env.get("STRIPE_US_SECRET_KEY")?.trim() ||
    requireEnv("STRIPE_SECRET_KEY");
}

export function stripeClient(): Stripe {
  return new Stripe(stripeSecretKey(), {
    apiVersion: "2026-06-24.dahlia" as never,
    httpClient: Stripe.createFetchHttpClient(),
  });
}

export { Stripe };
