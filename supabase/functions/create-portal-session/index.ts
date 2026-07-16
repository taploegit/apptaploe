import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { appUrl } from "../_shared/env.ts";
import { corsHeaders, jsonResponse, optionsResponse, safeMessage } from "../_shared/http.ts";
import { adminClient, requireAuthenticatedAppUser } from "../_shared/supabase.ts";
import { stripeClient } from "../_shared/stripe.ts";

type PortalBody = {
  scope?: unknown;
};

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse(req);
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders(req) });
  }

  try {
    const { appUser } = await requireAuthenticatedAppUser(req);
    const body = await req.json().catch(() => ({})) as PortalBody;
    const requestedScope = body.scope === "organization" ? "organization" : "user";
    const admin = adminClient();

    let query = admin
      .from("billing_subscriptions")
      .select("stripe_customer_id,owner_user_id,scope,org_id")
      .eq("owner_user_id", appUser.id)
      .not("stripe_customer_id", "is", null)
      .order("created_at", { ascending: false })
      .limit(1);
    query = requestedScope === "organization"
      ? query.eq("scope", "organization")
      : query.eq("scope", "user");

    const { data: subscription } = await query.maybeSingle();

    let customerId = subscription?.stripe_customer_id as string | undefined;
    if (!customerId) {
      const { data: customer } = await admin
        .from("stripe_customers")
        .select("stripe_customer_id")
        .eq("user_id", appUser.id)
        .maybeSingle();
      customerId = customer?.stripe_customer_id;
    }

    if (!customerId) {
      return jsonResponse(
        req,
        {
          code: "STRIPE_CUSTOMER_NOT_FOUND",
          message: "Aun no existe un customer de Stripe para esta cuenta.",
        },
        404,
      );
    }

    const portal = await stripeClient().billingPortal.sessions.create({
      customer: customerId,
      return_url: `${appUrl()}/settings/billing`,
    });

    return jsonResponse(req, { portalUrl: portal.url });
  } catch (error) {
    const status = (error as { status?: number }).status ?? 500;
    if (status < 500) {
      return jsonResponse(req, { code: "PORTAL_ERROR", message: "No se pudo abrir el portal." }, status);
    }
    console.error("[create-portal-session]", error instanceof Error ? error.message : "unknown");
    return jsonResponse(req, { code: "PORTAL_ERROR", message: safeMessage(error) }, status);
  }
});
