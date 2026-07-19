import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { appUrl } from "../_shared/env.ts";
import { corsHeaders, jsonResponse, optionsResponse, safeMessage } from "../_shared/http.ts";
import {
  adminClient,
  AppUserRow,
  findOwnedOrganization,
  OrganizationRow,
  requireAuthenticatedAppUser,
} from "../_shared/supabase.ts";
import {
  convertedMxnUnitAmount,
  stripePriceId,
  stripeProductIdOrNull,
  stripeProductName,
  TaploeBillingPeriod,
  TaploeCheckoutPlan,
} from "../_shared/stripe_catalog.ts";
import { stripeClient } from "../_shared/stripe.ts";

type CheckoutBody = {
  plan?: unknown;
  billingPeriod?: unknown;
  quantity?: unknown;
  language?: unknown;
  market?: unknown;
  locale?: unknown;
};

const activeStatuses = ["trialing", "active", "past_due", "grace_period", "incomplete"];

function errorResponse(req: Request, code: string, message: string, status = 400) {
  return jsonResponse(req, { code, message }, status);
}

function cleanSlug(value: string): string {
  const slug = value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 54);
  return slug.length >= 3 ? slug : `taploe-${Date.now().toString(36)}`;
}

async function uniqueOrgSlug(base: string): Promise<string> {
  const admin = adminClient();
  const root = cleanSlug(base);
  for (let i = 0; i < 40; i++) {
    const slug = i === 0 ? root : `${root}-${i}`;
    const { data } = await admin.from("organizations").select("id").eq("slug", slug).maybeSingle();
    if (!data) return slug;
  }
  return `${root}-${crypto.randomUUID().slice(0, 8)}`;
}

function validateBody(body: CheckoutBody): {
  plan: TaploeCheckoutPlan;
  billingPeriod: TaploeBillingPeriod;
  quantity: number;
  language: "es" | "en";
  market: "mx" | "us";
} {
  if (body.plan !== "premium" && body.plan !== "business") {
    throw Object.assign(new Error("INVALID_PLAN"), { status: 400 });
  }
  if (body.billingPeriod !== "monthly" && body.billingPeriod !== "annual") {
    throw Object.assign(new Error("INVALID_BILLING_PERIOD"), { status: 400 });
  }
  const quantity = Number(body.quantity);
  if (!Number.isInteger(quantity)) {
    throw Object.assign(new Error("INVALID_QUANTITY"), { status: 400 });
  }
  if (body.plan === "premium" && quantity !== 1) {
    throw Object.assign(new Error("PREMIUM_QUANTITY_MUST_BE_ONE"), { status: 400 });
  }
  if (body.plan === "business" && (quantity < 5 || quantity > 500)) {
    throw Object.assign(new Error("BUSINESS_QUANTITY_OUT_OF_RANGE"), { status: 400 });
  }
  const rawLocale = typeof body.locale === "string"
    ? body.locale.trim().toLowerCase()
    : "";
  const rawLanguage = typeof body.language === "string"
    ? body.language.trim().toLowerCase()
    : "";
  const market =
    body.market === "mx" ||
      rawLocale === "es-mx" ||
      rawLocale === "es_mx" ||
      rawLocale === "mx" ||
      rawLanguage === "es"
      ? "mx"
      : body.market === "us" || rawLocale === "en-us" ||
          rawLocale === "en_us" || rawLocale === "us"
      ? "us"
      : "mx";
  const language = body.language === "en" || market === "us" ? "en" : "es";
  return {
    plan: body.plan,
    billingPeriod: body.billingPeriod,
    quantity: body.plan === "premium" ? 1 : quantity,
    language,
    market,
  };
}

async function ensureBusinessOrganization(appUser: AppUserRow): Promise<OrganizationRow> {
  const existing = await findOwnedOrganization(appUser.id);
  if (existing) return existing;

  const admin = adminClient();
  const name = `${appUser.username} Team`;
  const slug = await uniqueOrgSlug(name);
  const { data: org, error: orgError } = await admin
    .from("organizations")
    .insert({
      name,
      slug,
      plan_type: "business",
      created_by_user_id: appUser.id,
      updated_at: new Date().toISOString(),
    })
    .select("id,name,slug,plan_type,created_by_user_id")
    .single();
  if (orgError || !org) throw new Error("Could not create organization");

  await admin.from("organization_members").insert({
    org_id: org.id,
    user_id: appUser.id,
    role: "owner",
    status: "active",
    joined_at: new Date().toISOString(),
  });

  await admin
    .from("digital_profiles")
    .update({ org_id: org.id, updated_at: new Date().toISOString() })
    .eq("owner_user_id", appUser.id)
    .is("org_id", null);

  return org as OrganizationRow;
}

async function ensureStripeCustomer(
  appUser: AppUserRow,
  authUserId: string,
  email: string,
): Promise<string> {
  const admin = adminClient();
  const { data: existingCustomer } = await admin
    .from("stripe_customers")
    .select("stripe_customer_id")
    .eq("user_id", appUser.id)
    .maybeSingle();
  if (existingCustomer?.stripe_customer_id) return existingCustomer.stripe_customer_id;

  const { data: existingSubscription } = await admin
    .from("billing_subscriptions")
    .select("stripe_customer_id")
    .eq("owner_user_id", appUser.id)
    .not("stripe_customer_id", "is", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (existingSubscription?.stripe_customer_id) {
    await admin.from("stripe_customers").upsert({
      user_id: appUser.id,
      auth_user_id: authUserId,
      stripe_customer_id: existingSubscription.stripe_customer_id,
      email,
      updated_at: new Date().toISOString(),
    });
    return existingSubscription.stripe_customer_id;
  }

  const stripe = stripeClient();
  const customer = await stripe.customers.create({
    email,
    name: appUser.full_name ?? appUser.username,
    metadata: {
      taploe_user_id: appUser.id,
      taploe_auth_user_id: authUserId,
      source: "taploe",
    },
  });

  await admin.from("stripe_customers").upsert({
    user_id: appUser.id,
    auth_user_id: authUserId,
    stripe_customer_id: customer.id,
    email,
    updated_at: new Date().toISOString(),
  });

  return customer.id;
}

function subscriptionStillBlocksCheckout(row: {
  status: string;
  current_period_end: string | null;
  grace_until: string | null;
  trial_end: string | null;
}): boolean {
  if (!activeStatuses.includes(row.status)) return false;
  const boundary = row.grace_until ?? row.current_period_end ?? row.trial_end;
  if (!boundary) return true;
  const expiresAt = Date.parse(boundary);
  return Number.isFinite(expiresAt) && expiresAt >= Date.now();
}

async function hasActiveSubscription(scope: "user" | "organization", userId: string, orgId: string | null) {
  const query = adminClient()
    .from("billing_subscriptions")
    .select("id,status,current_period_end,grace_until,trial_end")
    .eq("scope", scope)
    .in("status", activeStatuses)
    .order("created_at", { ascending: false })
    .limit(10);
  const { data } = scope === "organization"
    ? await query.eq("org_id", orgId)
    : await query.eq("user_id", userId);
  return (data ?? []).some(subscriptionStillBlocksCheckout);
}

async function trialAvailable(ownerUserId: string, stripeCustomerId: string): Promise<boolean> {
  const { data } = await adminClient()
    .from("billing_subscriptions")
    .select("id")
    .or(`owner_user_id.eq.${ownerUserId},stripe_customer_id.eq.${stripeCustomerId}`)
    .not("trial_used_at", "is", null)
    .limit(1);
  return (data ?? []).length === 0;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse(req);
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders(req) });
  }

  try {
    const { authUserId, email, appUser } = await requireAuthenticatedAppUser(req);
    const parsed = validateBody(await req.json());
    const scope = parsed.plan === "business" ? "organization" : "user";
    const organization = parsed.plan === "business"
      ? await ensureBusinessOrganization(appUser)
      : null;

    if (await hasActiveSubscription(scope, appUser.id, organization?.id ?? null)) {
      return errorResponse(
        req,
        "SUBSCRIPTION_ALREADY_EXISTS",
        "Ya existe una suscripcion activa. Administrala desde Facturacion.",
        409,
      );
    }

    const customerId = await ensureStripeCustomer(appUser, authUserId, email);
    const canUseTrial = await trialAvailable(appUser.id, customerId);
    const metadata = {
      taploe_user_id: appUser.id,
      taploe_auth_user_id: authUserId,
      taploe_org_id: organization?.id ?? "",
      taploe_scope: scope,
      taploe_plan: parsed.plan,
      billing_period: parsed.billingPeriod,
      taploe_market: parsed.market,
      currency: parsed.market === "us" ? "USD" : "MXN",
      quantity: parsed.quantity.toString(),
      source: "taploe_app",
    };
    const recurringInterval = parsed.billingPeriod === "annual" ? "year" : "month";
    const productId = stripeProductIdOrNull(parsed.plan);
    const lineItem = parsed.market === "mx"
      ? {
        price_data: {
          currency: "mxn",
          ...(productId
            ? { product: productId }
            : { product_data: { name: stripeProductName(parsed.plan) } }),
          unit_amount: convertedMxnUnitAmount(parsed.plan, parsed.billingPeriod),
          recurring: { interval: recurringInterval },
        },
        quantity: parsed.quantity,
      }
      : {
        price: stripePriceId(parsed.plan, parsed.market, parsed.billingPeriod),
        quantity: parsed.quantity,
      };
    const trialText = parsed.language === "en"
      ? "Free for 7 days. Cancel before your first charge."
      : "Prueba gratis durante 7 dias. Puedes cancelar antes del primer cobro.";
    const renewText = parsed.language === "en"
      ? "Your subscription will renew automatically until canceled."
      : "Tu suscripcion se renovara automaticamente hasta que la canceles.";

    const stripe = stripeClient();
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      client_reference_id: appUser.id,
      line_items: [lineItem],
      adaptive_pricing: { enabled: false },
      payment_method_collection: "always",
      locale: parsed.language === "es" ? "es-419" : "en",
      success_url: `${appUrl()}/subscription/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${appUrl()}/plans?checkout=canceled`,
      metadata,
      custom_text: { submit: { message: canUseTrial ? trialText : renewText } },
      subscription_data: {
        ...(canUseTrial
          ? {
            trial_period_days: 7,
            trial_settings: { end_behavior: { missing_payment_method: "cancel" } },
          }
          : {}),
        metadata,
      },
      allow_promotion_codes: true,
    } as never);

    if (!session.url) {
      return errorResponse(req, "CHECKOUT_URL_MISSING", "Stripe no devolvio URL de Checkout.", 502);
    }

    return jsonResponse(req, { checkoutUrl: session.url, sessionId: session.id });
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    const code = error instanceof Error ? error.message : "CHECKOUT_ERROR";
    if (status < 500) {
      return errorResponse(req, code, "No se pudo iniciar Checkout.", status);
    }
    console.error("[create-checkout-session]", code);
    return jsonResponse(req, { code: "CHECKOUT_ERROR", message: safeMessage(error) }, status);
  }
});
