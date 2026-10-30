// Admins create, reset and remove accounts. Needs the service key, so it
// runs here rather than in the app.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Only a signed-in admin may call this.
  const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  const { data: caller } = await admin.auth.getUser(token);
  if (!caller?.user) return reply({ error: "Not signed in." }, 401);
  const { data: me } = await admin
    .from("profiles")
    .select("role, removed_from")
    .eq("id", caller.user.id)
    .single();
  if (me?.role !== "admin" || me.removed_from) return reply({ error: "Admins only." }, 403);

  const body = await req.json();
  switch (body.action) {
    case "create": {
      const { data, error } = await admin.auth.admin.createUser({
        email: body.email,
        password: body.password,
        email_confirm: true,
        // Approved at once; people who sign up themselves wait for approval.
        app_metadata: { invited: true },
        user_metadata: {
          name: body.name,
          role: body.role,
          phone: body.phone ?? "",
          duties: body.duties ?? "",
          hours: body.hours ?? "",
        },
      });
      if (error) return reply({ error: error.message }, 400);
      return reply({ id: data.user.id });
    }
    case "reset_password": {
      const { error } = await admin.auth.admin.updateUserById(body.id, { password: body.password });
      if (error) return reply({ error: error.message }, 400);
      return reply({ ok: true });
    }
    case "remove": {
      if (body.id === caller.user.id) return reply({ error: "You cannot remove yourself." }, 400);
      // Their history stays; they just can no longer sign in.
      const { error } = await admin.auth.admin.updateUserById(body.id, { ban_duration: "876000h" });
      if (error) return reply({ error: error.message }, 400);
      await admin.from("profiles").update({ removed_from: body.from }).eq("id", body.id);
      await admin.from("push_subscriptions").delete().eq("person_id", body.id);
      return reply({ ok: true });
    }
    case "reject": {
      // Only someone still waiting for approval; members are removed instead.
      const { data: p } = await admin.from("profiles").select("role").eq("id", body.id).single();
      if (p?.role !== "pending") return reply({ error: "Only people waiting to join can be rejected." }, 400);
      const { error } = await admin.auth.admin.deleteUser(body.id);
      if (error) return reply({ error: error.message }, 400);
      return reply({ ok: true });
    }
    default:
      return reply({ error: "Unknown action." }, 400);
  }
});
