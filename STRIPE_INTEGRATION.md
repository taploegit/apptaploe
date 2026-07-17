# Stripe Billing en Taploe

## Arquitectura

Flutter nunca usa claves privadas de Stripe ni decide permisos por regresar de Checkout. El flujo es:

1. Flutter muestra planes y llama una Supabase Edge Function autenticada.
2. `create-checkout-session` valida el JWT, obtiene el usuario real, elige Price IDs desde secretos y crea Stripe Hosted Checkout.
3. Stripe cobra, administra trial, facturas, reintentos, cancelaciones y Customer Portal.
4. `stripe-webhook` valida `Stripe-Signature` con raw body y sincroniza Supabase.
5. Flutter lee `billing_subscriptions` y `billing_invoices`; esa es la fuente de verdad para Premium o Business.

## Edge Functions

- `create-checkout-session`: autenticada, crea Checkout Session.
- `create-portal-session`: autenticada, crea Stripe Customer Portal Session.
- `stripe-webhook`: publica, sin JWT, protegida por firma de Stripe.

Configuración en `supabase/config.toml`:

```toml
[functions.create-checkout-session]
verify_jwt = true

[functions.create-portal-session]
verify_jwt = true

[functions.stripe-webhook]
verify_jwt = false
```

## Supabase Secrets Requeridos

Configurar en Supabase Dashboard -> Edge Functions -> Secrets:

```text
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
STRIPE_PREMIUM_PRODUCT_ID
STRIPE_PREMIUM_MONTHLY_PRICE_ID
STRIPE_PREMIUM_ANNUAL_PRICE_ID
STRIPE_BUSINESS_PRODUCT_ID
STRIPE_BUSINESS_MONTHLY_PRICE_ID
STRIPE_BUSINESS_ANNUAL_PRICE_ID
APP_URL
STRIPE_ENV
TAPLOE_USD_MXN_RATE
```

Supabase también provee `SUPABASE_URL`, `SUPABASE_SECRET_KEYS`, `SUPABASE_PUBLISHABLE_KEYS`, y en proyectos legacy `SUPABASE_SERVICE_ROLE_KEY` y `SUPABASE_ANON_KEY`.

No versionar valores reales de `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `SUPABASE_SECRET_KEYS` ni `SUPABASE_SERVICE_ROLE_KEY`.

## Catálogo

Los IDs de producto y precio viven en `supabase/functions/_shared/stripe_catalog.ts` y se leen desde `Deno.env.get()`.

- Taploe Premium mensual/anual: cantidad Stripe siempre `1`.
- Taploe Business mensual/anual: cantidad Stripe es perfiles/asientos, mínimo `5`, máximo `500`.

Flutter solo manda:

```json
{
  "plan": "premium",
  "billingPeriod": "monthly",
  "quantity": 1,
  "language": "es",
  "market": "mx",
  "locale": "es-MX"
}
```

Nunca manda Price ID, Product ID, importe, currency, user_id, customer ID, URLs ni días de trial.

La app muestra precios desde el catálogo local `lib/src/pricing.dart` con los precios base USD de Stripe:

- Premium: `9.99 USD` mensual y `87.99 USD` anual.
- Business: `4.99 USD` mensual por perfil y `43.99 USD` anual por perfil.

Para México, Flutter convierte esos importes con `TAPLOE_USD_MXN_RATE` y default `17.4412366447`. Stripe Checkout usa los mismos Price IDs base; la conversión a MXN depende de la configuración regional/multimoneda de Stripe aplicada a esos precios.

## Trial

La prueba dura 7 días y se configura en Checkout con `trial_period_days: 7` y `payment_method_collection: "always"`. La elegibilidad se calcula por usuario/customer e historial `trial_used_at`. Si el usuario ya usó trial, Checkout se crea sin trial.

## Idioma, Mercado y Moneda

La plataforma acepta estos puntos de entrada:

```text
https://app.taploe.com/login?locale=es-MX
https://app.taploe.com/login?locale=en-US
```

`es-MX` significa textos en español y precios/cobros en MXN. `en-US` significa textos en inglés y precios/cobros en USD. La preferencia se guarda en `app_users.preferred_language`, `app_users.preferred_market` y se propaga a `digital_profiles.public_locale` para que el perfil público use el idioma configurado por el dueño.

Para México, Flutter debe mandar `market: "mx"` y `locale: "es-MX"` al crear Checkout. Stripe muestra/cobra en MXN con la configuración regional/multimoneda de los Price IDs existentes, igual que en Taploe Business.

## Webhooks

Eventos implementados:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `customer.subscription.trial_will_end`
- `invoice.paid`
- `invoice.payment_failed`
- `invoice.payment_action_required`

La función lee `await req.text()` antes de parsear, valida `Stripe-Signature` con `STRIPE_WEBHOOK_SECRET` y usa `stripe_webhook_events` más RPCs de claim/complete/fail para idempotencia.

## Proxy Vercel

Stripe puede seguir usando:

```text
https://app.taploe.com/api/stripe/webhook
```

`api/stripe/webhook.js` conserva raw body y `stripe-signature`, y reenvía a:

```text
https://<project-ref>.supabase.co/functions/v1/stripe-webhook
```

No contiene claves de Stripe. Si el despliegue no usa Vercel serverless, cambia el endpoint de Stripe directamente a la URL de la Edge Function.

## Base de Datos

La migración `202607160002_stripe_billing_integration.sql` agrega:

- `stripe_customers`
- `stripe_webhook_events`
- columnas Stripe completas en `billing_subscriptions`
- columnas de Stripe en `billing_invoices`
- RPCs de idempotencia
- RLS para lectura propia y bloqueo de escritura cliente

La organización no se borra ni se desvinculan miembros si vence Business. La suscripción queda vencida/cancelada y deja de otorgar beneficios hasta renovación.

## Acceso

`trialing` y `active` otorgan acceso hasta sus fechas. `past_due` otorga acceso solo hasta `grace_until`. `incomplete`, `incomplete_expired`, `unpaid`, `paused` y vencidas no otorgan beneficios. Business requiere una suscripción de organización vigente; pertenecer a una organización no basta.

## Customer Portal

Flutter llama `create-portal-session` y abre Stripe Customer Portal para:

- método de pago
- facturas
- cancelar
- reanudar si Stripe lo permite
- revisar plan

Configura Customer Portal en Stripe Dashboard antes de producción.

## Pruebas Recomendadas

Usar proyecto/secretos de prueba o Stripe Sandbox antes de Live:

1. Premium mensual y anual.
2. Business mensual/anual con 5 perfiles.
3. Rechazo de Business con menos de 5 y cantidades decimales.
4. Checkout en español e inglés.
5. Trial inicial y segundo checkout sin trial.
6. `invoice.paid` con monto cero y con monto mayor a cero.
7. `invoice.payment_failed` y `invoice.payment_action_required`.
8. Cancelación al final del periodo e inmediata.
9. Webhook duplicado, firma inválida y evento fuera de orden.
10. Proxy `/api/stripe/webhook` y URL directa de Edge Function.

## Despliegue

1. Ejecutar migraciones SQL en Supabase.
2. Configurar secrets en Supabase.
3. Desplegar Edge Functions:

```bash
supabase functions deploy create-checkout-session
supabase functions deploy create-portal-session
supabase functions deploy stripe-webhook
```

4. Confirmar que Vercel despliega `api/stripe/webhook.js`.
5. Configurar Stripe Customer Portal.
6. Probar con Stripe CLI/Test Clocks antes de Live.

## Rotación

Si una clave se expone, rotarla en Stripe/Supabase Secrets y redeployar funciones. No hace falta cambiar Flutter porque no almacena secretos.
