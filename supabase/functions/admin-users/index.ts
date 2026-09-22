import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type User } from "npm:@supabase/supabase-js@2";

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

async function listAllAuthUsers(admin: ReturnType<typeof createClient>) {
  const users: User[] = [];
  const perPage = 200;
  for (let page = 1; ; page += 1) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) throw error;
    users.push(...data.users);
    if (data.users.length < perPage) break;
  }
  return users;
}

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

    if (action === "statistics") {
      const now = Date.now();
      const since7d = new Date(now - 7 * 86400000).toISOString();
      const since30d = new Date(now - 30 * 86400000).toISOString();
      const authUsersPromise = listAllAuthUsers(admin);
      const results = await Promise.all([
        admin.from("places").select("id", { count: "exact", head: true }),
        admin.from("places").select("id", { count: "exact", head: true }).gte("created_at", since30d),
        admin.from("visits").select("id", { count: "exact", head: true }),
        admin.from("visits").select("id", { count: "exact", head: true }).gte("created_at", since30d),
        admin.from("visits").select("id", { count: "exact", head: true }).gte("created_at", since7d),
        admin.from("user_follows").select("follower_id", { count: "exact", head: true }),
        admin.from("user_place_preferences").select("place_id", { count: "exact", head: true }).eq("is_favorite", true),
        admin.from("user_place_preferences").select("place_id", { count: "exact", head: true }).eq("is_wishlist", true),
        admin.from("coupons").select("id", { count: "exact", head: true }),
        admin.from("coupons").select("id", { count: "exact", head: true })
          .eq("is_published", true)
          .gte("valid_until", new Date().toISOString().slice(0, 10)),
        admin.from("support_requests").select("id", { count: "exact", head: true }).in("status", ["new", "in_progress"]),
        admin.from("visit_reports").select("id", { count: "exact", head: true }).eq("status", "new"),
        admin.from("visit_image_reports").select("id", { count: "exact", head: true }).eq("status", "new"),
        admin.from("push_subscriptions").select("user_id").limit(5000),
        admin.from("place_managers").select("user_id,place_id", { count: "exact" }).eq("status", "active").limit(5000),
        admin.from("visits").select("user_id,rating").limit(5000),
        admin.from("categories").select("id,title"),
        admin.from("places").select("category_id,latitude,longitude").limit(5000),
        admin.from("user_subscriptions").select("user_id,status,expires_at").eq("plan", "premium"),
        admin.from("profiles").select("id,is_admin"),
      ]);
      for (const result of results) {
        if (result.error) throw result.error;
      }
      const authUsers = (await authUsersPromise).filter((user) => !user.is_anonymous);
      const active30d = authUsers.filter((user) =>
        user.last_sign_in_at && new Date(user.last_sign_in_at).getTime() >= now - 30 * 86400000
      ).length;
      const subscriptions = results[18].data ?? [];
      const premium = subscriptions.filter((item) =>
        item.status === "active" &&
        (!item.expires_at || new Date(item.expires_at).getTime() > now)
      ).length;
      const profiles = results[19].data ?? [];
      const admins = profiles.filter((item) => item.is_admin === true).length;
      const pushUsers = new Set((results[13].data ?? []).map((item) => item.user_id));
      const managerUsers = new Set((results[14].data ?? []).map((item) => item.user_id));
      const visitRows = results[15].data ?? [];
      const contributors = new Set(visitRows.map((item) => item.user_id));
      const ratings = visitRows
        .map((item) => Number(item.rating))
        .filter((value) => Number.isFinite(value) && value > 0);
      const categories = new Map((results[16].data ?? []).map((item) => [item.id, item.title]));
      const categoryCounts = new Map<string, number>();
      let geocodedPlaces = 0;
      for (const place of results[17].data ?? []) {
        const id = place.category_id;
        if (id) categoryCounts.set(id, (categoryCounts.get(id) ?? 0) + 1);
        if (place.latitude != null && place.longitude != null) geocodedPlaces += 1;
      }
      const topCategory = [...categoryCounts.entries()].sort((a, b) => b[1] - a[1])[0];

      return new Response(JSON.stringify({
        users: {
          registered: authUsers.length,
          active_30d: active30d,
          premium,
          admins,
        },
        content: {
          places: results[0].count ?? 0,
          new_places_30d: results[1].count ?? 0,
          experiences: results[2].count ?? 0,
          experiences_30d: results[3].count ?? 0,
          experiences_7d: results[4].count ?? 0,
          contributors: contributors.size,
          average_rating: ratings.length
            ? ratings.reduce((sum, value) => sum + value, 0) / ratings.length
            : null,
          geocoded_places: geocodedPlaces,
          top_category: topCategory
            ? { title: categories.get(topCategory[0]) ?? "קטגוריה", count: topCategory[1] }
            : null,
        },
        engagement: {
          follows: results[5].count ?? 0,
          favorites: results[6].count ?? 0,
          wishlist: results[7].count ?? 0,
          push_users: pushUsers.size,
        },
        business: {
          coupons: results[8].count ?? 0,
          active_coupons: results[9].count ?? 0,
          managers: managerUsers.size,
          managed_places: results[14].count ?? 0,
        },
        moderation: {
          pending_support: results[10].count ?? 0,
          pending_visit_reports: results[11].count ?? 0,
          pending_image_reports: results[12].count ?? 0,
        },
      }), { headers });
    }

    if (action === "list") {
      if (!canManageUsers) {
        return new Response(JSON.stringify({ error: "Insufficient permissions" }), {
          status: 403, headers,
        });
      }
      const registered = (await listAllAuthUsers(admin))
        .filter((user) => !user.is_anonymous);
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
