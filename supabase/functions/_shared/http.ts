const productionOrigins = new Set(["https://app.taploe.com"]);

function isLocalOrigin(origin: string): boolean {
  try {
    const uri = new URL(origin);
    return uri.hostname === "localhost" || uri.hostname === "127.0.0.1";
  } catch (_) {
    return false;
  }
}

export function corsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get("origin") ?? "";
  const allowed = productionOrigins.has(origin) || isLocalOrigin(origin)
    ? origin
    : "https://app.taploe.com";
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

export function jsonResponse(
  req: Request,
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

export function optionsResponse(req: Request): Response {
  return new Response("ok", { headers: corsHeaders(req) });
}

export function publicJsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

export function safeMessage(error: unknown): string {
  if (error instanceof Error && error.message.startsWith("Missing required")) {
    return "Configuracion incompleta del servidor.";
  }
  return "No se pudo completar la solicitud.";
}
