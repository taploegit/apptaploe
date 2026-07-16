import Stripe from "https://esm.sh/stripe@16.12.0?target=deno";
import { requireEnv } from "./env.ts";

export function stripeClient(): Stripe {
  return new Stripe(requireEnv("STRIPE_SECRET_KEY"), {
    apiVersion: "2026-06-24.dahlia" as never,
    httpClient: Stripe.createFetchHttpClient(),
  });
}

export { Stripe };
