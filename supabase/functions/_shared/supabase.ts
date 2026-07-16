import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {
  supabasePublishableKey,
  supabaseSecretKey,
  supabaseUrl,
} from "./env.ts";

export type AppUserRow = {
  id: string;
  auth_user_id: string;
  email: string;
  username: string;
  full_name: string | null;
  plan_type: string;
};

export type OrganizationRow = {
  id: string;
  name: string;
  slug: string | null;
  plan_type: string;
  created_by_user_id: string | null;
};

export function userClient(authorization: string) {
  return createClient(supabaseUrl(), supabasePublishableKey(), {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function adminClient() {
  return createClient(supabaseUrl(), supabaseSecretKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function requireAuthenticatedAppUser(req: Request): Promise<{
  authorization: string;
  authUserId: string;
  email: string;
  appUser: AppUserRow;
}> {
  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) {
    throw Object.assign(new Error("Unauthorized"), { status: 401 });
  }

  const authClient = userClient(authorization);
  const { data, error } = await authClient.auth.getUser();
  if (error || !data.user) {
    throw Object.assign(new Error("Unauthorized"), { status: 401 });
  }

  const admin = adminClient();
  const { data: appUser, error: userError } = await admin
    .from("app_users")
    .select("id,auth_user_id,email,username,full_name,plan_type")
    .eq("auth_user_id", data.user.id)
    .single();

  if (userError || !appUser) {
    throw Object.assign(new Error("App user not found"), { status: 404 });
  }

  return {
    authorization,
    authUserId: data.user.id,
    email: data.user.email ?? appUser.email,
    appUser: appUser as AppUserRow,
  };
}

export async function findOwnedOrganization(
  ownerUserId: string,
): Promise<OrganizationRow | null> {
  const admin = adminClient();
  const { data: member } = await admin
    .from("organization_members")
    .select("org_id")
    .eq("user_id", ownerUserId)
    .eq("status", "active")
    .in("role", ["owner", "admin"])
    .limit(1)
    .maybeSingle();

  if (!member?.org_id) return null;
  const { data: org } = await admin
    .from("organizations")
    .select("id,name,slug,plan_type,created_by_user_id")
    .eq("id", member.org_id)
    .maybeSingle();

  return (org as OrganizationRow | null) ?? null;
}
