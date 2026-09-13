import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const banDurations = new Set(["24h", "168h", "720h", "876000h"]);
const adminRoles = new Set(["full_admin", "content_admin", "support_admin"]);
const premiumDurations = new Map([
  ["7d", 7], ["30d", 30], ["90d", 90], ["180d", 180], ["365d", 365],
]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) throw new Error("Missing authorization");
    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    const token = authorization.replace("Bearer ", "");
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) throw new Error("Unauthorized");

    const callerId = authData.user.id;
    const { data: caller, error: callerError } = await admin
      .from("profiles")
      .select("is_admin, admin_role")
      .eq("id", callerId)
      .maybeSingle();
    if (callerError || caller?.is_admin !== true || !adminRoles.has(caller?.admin_role)) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403, headers,
      });
    }

    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const action = body.action ?? "list";
    const isFullAdmin = caller.admin_role === "full_admin";
    const canManageUsers = isFullAdmin || caller.admin_role === "support_admin";

    if (action === "list") {
      if (!canManageUsers) {
        return new Response(JSON.stringify({ error: "Insufficient permissions" }), {
          status: 403, headers,
        });
      }
      const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
      if (error) throw error;
      const registered = data.users.filter((user) => !user.is_anonymous);
      const ids = registered.map((user) => user.id);
      const [{ data: profiles, error: profilesError }, { data: subscriptions, error: subscriptionsError }] =
        ids.length === 0
          ? [{ data: [], error: null }, { data: [], error: null }]
          : await Promise.all([
              admin.from("profiles")
                .select("id, display_name, email, avatar_url, is_admin, admin_role, is_premium")
                .in("id", ids),
              admin.from("user_subscriptions")
                .select("user_id, plan, status, expires_at")
                .in("user_id", ids)
                .eq("plan", "premium"),
            ]);
      if (profilesError) throw profilesError;
      if (subscriptionsError) throw subscriptionsError;

      const profileById = new Map((profiles ?? []).map((item) => [item.id, item]));
      const subscriptionById = new Map((subscriptions ?? []).map((item) => [item.user_id, item]));
      const now = Date.now();
      const users = registered.map((user) => {
        const profile = profileById.get(user.id);
        const subscription = subscriptionById.get(user.id);
        const expiresAt = subscription?.expires_at ?? null;
        const subscriptionActive = subscription?.status === "active" &&
          (!expiresAt || new Date(expiresAt).getTime() > now);
        const effectivePremium = subscriptionActive || profile?.is_admin === true;
        return {
          id: user.id,
          email: user.email ?? profile?.email ?? null,
          display_name: profile?.display_name ?? null,
          avatar_url: profile?.avatar_url ?? null,
          is_admin: profile?.is_admin === true,
          admin_role: profile?.admin_role ?? null,
          is_premium: effectivePremium,
          premium_expires_at: subscriptionActive ? expiresAt : null,
          created_at: user.created_at,
          last_sign_in_at: user.last_sign_in_at,
          banned_until: user.banned_until,
          providers: (user.identities ?? []).map((identity) => identity.provider),
        };
      });
      return new Response(JSON.stringify({
        users,
        caller_role: caller.admin_role,
        summary: {
          registered: users.length,
          premium: users.filter((user) => user.is_premium).length,
          admins: users.filter((user) => user.is_admin).length,
          active_30d: users.filter((user) =>
            user.last_sign_in_at &&
            new Date(user.last_sign_in_at).getTime() >= now - 30 * 86400000
          ).length,
        },
      }), { headers });
    }

    if (!canManageUsers) {
      return new Response(JSON.stringify({ error: "Insufficient permissions" }), {
        status: 403, headers,
      });
    }

    const targetId = body.user_id;
    if (!targetId || typeof targetId !== "string") throw new Error("Missing user_id");
    if (targetId === callerId) throw new Error("Cannot manage your own account");

    if (action === "block") {
      if (!banDurations.has(body.ban_duration)) throw new Error("Invalid ban duration");
      const { error } = await admin.auth.admin.updateUserById(targetId, {
        ban_duration: body.ban_duration,
      });
      if (error) throw error;
    } else if (action === "unblock") {
      const { error } = await admin.auth.admin.updateUserById(targetId, {
        ban_duration: "none",
      });
      if (error) throw error;
    } else if (action === "delete") {
      if (!isFullAdmin) throw new Error("Full admin required");
      const { error } = await admin.auth.admin.deleteUser(targetId);
      if (error) throw error;
    } else if (action === "set_premium") {
      if (!isFullAdmin) throw new Error("Full admin required");
      const duration = body.duration;
      if (duration === "remove") {
        const { error } = await admin.from("user_subscriptions").upsert({
          user_id: targetId, plan: "premium", status: "inactive", expires_at: new Date().toISOString(),
          provider: "manual", updated_at: new Date().toISOString(),
        });
        if (error) throw error;
        await admin.from("profiles").update({ is_premium: false }).eq("id", targetId);
      } else {
        const days = premiumDurations.get(duration);
        if (!days && duration !== "unlimited") throw new Error("Invalid premium duration");
        const expiresAt = days
          ? new Date(Date.now() + days * 86400000).toISOString()
          : null;
        const { error } = await admin.from("user_subscriptions").upsert({
          user_id: targetId, plan: "premium", status: "active", expires_at: expiresAt,
          provider: "manual", started_at: new Date().toISOString(), updated_at: new Date().toISOString(),
        });
        if (error) throw error;
        await admin.from("profiles").update({ is_premium: true }).eq("id", targetId);
      }
    } else if (action === "set_role") {
      if (!isFullAdmin) throw new Error("Full admin required");
      const role = body.role;
      if (role !== "user" && !adminRoles.has(role)) throw new Error("Invalid role");
      const { error } = await admin.from("profiles").update({
        is_admin: role !== "user",
        admin_role: role === "user" ? null : role,
        role: role === "user" ? "user" : "admin",
      }).eq("id", targetId);
      if (error) throw error;
    } else {
      throw new Error("Unsupported action");
    }

    return new Response(JSON.stringify({ ok: true }), { headers });
  } catch (error) {
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : "Unknown error",
    }), { status: 400, headers });
  }
});

