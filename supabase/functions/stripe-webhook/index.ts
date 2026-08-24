import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { requireEnv } from "../_shared/env.ts";
import { publicJsonResponse } from "../_shared/http.ts";
import { adminClient } from "../_shared/supabase.ts";
import { planFromPriceId } from "../_shared/stripe_catalog.ts";
import { Stripe, stripeClient } from "../_shared/stripe.ts";

type BillingScope = "user" | "organization";

function ts(value: number | null | undefined): string | null {
  return value ? new Date(value * 1000).toISOString() : null;
}

function addDays(value: string | null, days: number): string | null {
  if (!value) return null;
  const date = new Date(value);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString();
}

function statusFromStripe(status: string): string {
  if (
    [
      "trialing",
      "active",
      "past_due",
      "incomplete",
      "incomplete_expired",
      "unpaid",
      "canceled",
      "paused",
    ].includes(status)
  ) {
    return status;
  }
  return "expired";
}

function stripeWebhookSecret(): string {
  return Deno.env.get("STRIPE_US_WEBHOOK_SECRET")?.trim() ||
    requireEnv("STRIPE_WEBHOOK_SECRET");
}

async function claimEvent(event: Stripe.Event): Promise<"claimed" | "duplicate" | "busy"> {
  const { data, error } = await adminClient().rpc("claim_stripe_webhook_event", {
    p_event_id: event.id,
    p_event_type: event.type,
    p_stripe_created_at: ts(event.created),
  });
  if (error) throw error;
  return data as "claimed" | "duplicate" | "busy";
}

async function completeEvent(eventId: string) {
  await adminClient().rpc("complete_stripe_webhook_event", { p_event_id: eventId });
}

async function failEvent(eventId: string, error: unknown) {
  const message = error instanceof Error ? error.message : "unknown";
  await adminClient().rpc("fail_stripe_webhook_event", {
    p_event_id: eventId,
    p_last_error: message,
  });
}

function subscriptionPrice(subscription: Stripe.Subscription): {
  priceId: string | null;
  productId: string | null;
  quantity: number;
} {
  const item = subscription.items.data[0];
  const priceId = item?.price?.id ?? null;
  const rawProduct = item?.price?.product;
  return {
    priceId,
    productId: typeof rawProduct === "string" ? rawProduct : rawProduct?.id ?? null,
    quantity: item?.quantity ?? 1,
  };
}

async function findExistingSubscription(stripeSubscriptionId: string) {
  const { data } = await adminClient()
    .from("billing_subscriptions")
    .select("id,user_id,org_id,owner_user_id,scope")
    .eq("stripe_subscription_id", stripeSubscriptionId)
    .maybeSingle();
  return data as { id: string; user_id: string | null; org_id: string | null; owner_user_id: string; scope: BillingScope } | null;
}

async function syncSubscription(subscription: Stripe.Subscription) {
  const admin = adminClient();
  const { priceId, productId, quantity } = subscriptionPrice(subscription);
  const fromPrice = planFromPriceId(priceId);
  const metadata = subscription.metadata ?? {};
  const existing = await findExistingSubscription(subscription.id);
  const plan = (metadata.taploe_plan as string | undefined) ?? fromPrice.plan ?? "premium";
  const billingPeriod = (metadata.billing_period as string | undefined) ?? fromPrice.billingPeriod ?? "monthly";
  const scope = ((metadata.taploe_scope as string | undefined) ??
    existing?.scope ??
    (plan === "business" ? "organization" : "user")) as BillingScope;
  const ownerUserId = (metadata.taploe_user_id as string | undefined) ?? existing?.owner_user_id;
  const userId = scope === "user" ? ownerUserId ?? existing?.user_id : null;
  const orgId = scope === "organization"
    ? ((metadata.taploe_org_id as string | undefined) || existing?.org_id)
    : null;

  if (!ownerUserId || (scope === "user" && !userId) || (scope === "organization" && !orgId)) {
    throw new Error("Subscription target metadata missing");
  }

  const status = statusFromStripe(subscription.status);
  const currentPeriodEnd = ts(subscription.current_period_end);
  const payload = {
    scope,
    user_id: userId,
    org_id: orgId,
    owner_user_id: ownerUserId,
    plan_type: plan === "business" ? "business" : "premium",
    billing_interval: billingPeriod,
    status,
    quantity,
    currency: subscription.currency ?? null,
    cancel_at_period_end: subscription.cancel_at_period_end,
    trial_start: ts(subscription.trial_start),
    trial_end: ts(subscription.trial_end),
    trial_used_at: subscription.trial_start ? ts(subscription.trial_start) : existing ? undefined : null,
    current_period_start: ts(subscription.current_period_start),
    current_period_end: currentPeriodEnd,
    grace_until: status === "past_due" ? addDays(currentPeriodEnd, 2) : null,
    canceled_at: ts(subscription.canceled_at),
    ended_at: ts(subscription.ended_at),
    stripe_customer_id: typeof subscription.customer === "string"
      ? subscription.customer
      : subscription.customer.id,
    stripe_subscription_id: subscription.id,
    stripe_price_id: priceId,
    stripe_product_id: productId ?? fromPrice.productId,
    next_payment_at: subscription.cancel_at_period_end ? null : currentPeriodEnd,
    payment_issue: ["past_due", "unpaid", "incomplete"].includes(status),
    payment_action_required: false,
    last_synced_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    metadata,
  };

  const { data: saved, error } = await admin
    .from("billing_subscriptions")
    .upsert(payload, { onConflict: "stripe_subscription_id" })
    .select("id")
    .single();
  if (error) throw error;

  await admin
    .from("app_users")
    .update({
      plan_type: status === "trialing" || status === "active" ? (plan === "premium" ? "premium" : "free") : "free",
      updated_at: new Date().toISOString(),
    })
    .eq("id", ownerUserId)
    .neq("plan_type", status === "trialing" || status === "active" ? (plan === "premium" ? "premium" : "free") : "free");

  return saved as { id: string };
}

async function getSubscription(subscriptionRef: string | Stripe.Subscription | null | undefined) {
  if (!subscriptionRef) return null;
  if (typeof subscriptionRef !== "string") return subscriptionRef;
  return await stripeClient().subscriptions.retrieve(subscriptionRef);
}

async function handleCheckoutSession(session: Stripe.Checkout.Session) {
  const subscription = await getSubscription(session.subscription as string | Stripe.Subscription | null);
  if (subscription) await syncSubscription(subscription);

  const customerId = typeof session.customer === "string" ? session.customer : session.customer?.id;
  const appUserId = session.metadata?.taploe_user_id ?? session.client_reference_id;
  const authUserId = session.metadata?.taploe_auth_user_id;
  if (customerId && appUserId) {
    await adminClient().from("stripe_customers").upsert({
      user_id: appUserId,
      auth_user_id: authUserId || null,
      stripe_customer_id: customerId,
      email: session.customer_details?.email ?? null,
      updated_at: new Date().toISOString(),
    });
  }
}

async function upsertInvoice(invoice: Stripe.Invoice, actionRequired = false) {
  const admin = adminClient();
  const subscription = await getSubscription(invoice.subscription as string | Stripe.Subscription | null);
  const savedSubscription = subscription ? await syncSubscription(subscription) : null;
  const subId = subscription?.id ?? (typeof invoice.subscription === "string" ? invoice.subscription : null);

  const { data: billingSub } = subId
    ? await admin
      .from("billing_subscriptions")
      .select("id,user_id,org_id")
      .eq("stripe_subscription_id", subId)
      .maybeSingle()
    : { data: null };

  const amountPaid = (invoice.amount_paid ?? 0) / 100;
  const amountDue = (invoice.amount_due ?? 0) / 100;
  const amountRemaining = (invoice.amount_remaining ?? 0) / 100;
  const invoiceStatus = invoice.status === "uncollectible" ? "uncollectible" : invoice.status ?? "open";

  await admin.from("billing_invoices").upsert({
    subscription_id: savedSubscription?.id ?? billingSub?.id ?? null,
    user_id: billingSub?.user_id ?? null,
    org_id: billingSub?.org_id ?? null,
    stripe_invoice_id: invoice.id,
    stripe_subscription_id: subId,
    stripe_payment_intent_id: typeof invoice.payment_intent === "string"
      ? invoice.payment_intent
      : invoice.payment_intent?.id ?? null,
    status: invoiceStatus === "paid" ? "paid" : invoiceStatus,
    currency: (invoice.currency ?? "usd").toUpperCase(),
    amount_due: amountDue,
    amount_paid: amountPaid,
    amount_remaining: amountRemaining,
    hosted_invoice_url: invoice.hosted_invoice_url,
    invoice_pdf: invoice.invoice_pdf,
    period_start: ts(invoice.period_start),
    period_end: ts(invoice.period_end),
    paid_at: invoiceStatus === "paid" ? new Date().toISOString() : null,
    payment_action_required: actionRequired,
  }, { onConflict: "stripe_invoice_id" });

  if (subId) {
    await admin
      .from("billing_subscriptions")
      .update({
        latest_invoice_id: invoice.id,
        latest_invoice_status: invoice.status,
        hosted_invoice_url: invoice.hosted_invoice_url,
        last_payment_at: invoiceStatus === "paid" && amountPaid > 0 ? new Date().toISOString() : undefined,
        payment_issue: invoiceStatus !== "paid",
        payment_action_required: actionRequired,
        updated_at: new Date().toISOString(),
      })
      .eq("stripe_subscription_id", subId);
  }
}

async function markTrialWillEnd(subscriptionRef: string | Stripe.Subscription) {
  const subscription = await getSubscription(subscriptionRef);
  if (!subscription) return;
  await syncSubscription(subscription);
  const admin = adminClient();
  const { data: row } = await admin
    .from("billing_subscriptions")
    .select("id,owner_user_id,plan_type,trial_end")
    .eq("stripe_subscription_id", subscription.id)
    .maybeSingle();
  if (!row) return;

  await admin
    .from("billing_subscriptions")
    .update({ trial_ending_notified_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("id", row.id);

  await admin.from("app_notifications").insert({
    user_id: row.owner_user_id,
    notification_type: "billing",
    title: "Tu prueba gratuita esta por terminar",
    body: `La prueba de Taploe ${row.plan_type} termina pronto. Stripe intentara cobrar el metodo de pago guardado.`,
    action_url: "/settings/billing",
    metadata: { billing_subscription_id: row.id },
  });
}

async function handleEvent(event: Stripe.Event) {
  switch (event.type) {
    case "checkout.session.completed":
      await handleCheckoutSession(event.data.object as Stripe.Checkout.Session);
      break;
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted":
      await syncSubscription(event.data.object as Stripe.Subscription);
      break;
    case "customer.subscription.trial_will_end":
      await markTrialWillEnd(event.data.object as Stripe.Subscription);
      break;
    case "invoice.paid":
      await upsertInvoice(event.data.object as Stripe.Invoice, false);
      break;
    case "invoice.payment_failed":
      await upsertInvoice(event.data.object as Stripe.Invoice, false);
      break;
    case "invoice.payment_action_required":
      await upsertInvoice(event.data.object as Stripe.Invoice, true);
      break;
    default:
      break;
  }
}

serve(async (req) => {
  if (req.method !== "POST") {
    return publicJsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }

  const signature = req.headers.get("stripe-signature") ?? req.headers.get("Stripe-Signature");
  if (!signature) return publicJsonResponse({ code: "SIGNATURE_MISSING" }, 400);

  const rawBody = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripeClient().webhooks.constructEventAsync(
      rawBody,
      signature,
      stripeWebhookSecret(),
      undefined,
      Stripe.createSubtleCryptoProvider(),
    );
  } catch (_) {
    return publicJsonResponse({ code: "INVALID_SIGNATURE" }, 400);
  }

  const claim = await claimEvent(event);
  if (claim === "duplicate" || claim === "busy") {
    return publicJsonResponse({ received: true, status: claim }, 200);
  }

  try {
    await handleEvent(event);
    await completeEvent(event.id);
    return publicJsonResponse({ received: true }, 200);
  } catch (error) {
    await failEvent(event.id, error);
    console.error("[stripe-webhook]", event.id, event.type, error instanceof Error ? error.message : "unknown");
    return publicJsonResponse({ code: "WEBHOOK_PROCESSING_FAILED" }, 500);
  }
});
