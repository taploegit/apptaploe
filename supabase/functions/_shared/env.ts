export function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function firstSecretValue(raw: string | undefined): string | null {
  if (!raw?.trim()) return null;
  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed === "string") return parsed;
    if (Array.isArray(parsed)) {
      return parsed.find((item) => typeof item === "string" && item.length > 0) ??
        null;
    }
    if (parsed && typeof parsed === "object") {
      const values = Object.values(parsed);
      return values.find((item) => typeof item === "string" && item.length > 0) as
        | string
        | null;
    }
  } catch (_) {
    return raw;
  }
  return null;
}

export function supabaseUrl(): string {
  return requireEnv("SUPABASE_URL");
}

export function supabasePublishableKey(): string {
  return firstSecretValue(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS")) ??
    requireEnv("SUPABASE_ANON_KEY");
}

export function supabaseSecretKey(): string {
  return firstSecretValue(Deno.env.get("SUPABASE_SECRET_KEYS")) ??
    requireEnv("SUPABASE_SERVICE_ROLE_KEY");
}

export function appUrl(): string {
  return (Deno.env.get("APP_URL")?.trim() || "https://app.taploe.com")
    .replace(/\/+$/, "");
}

export function stripeEnvironment(): "live" | "test" {
  return Deno.env.get("STRIPE_ENV")?.trim() === "test" ? "test" : "live";
}
