import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY     = Deno.env.get('SUPABASE_ANON_KEY')!;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: CORS });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const auth = req.headers.get('Authorization') || '';
    if (!auth.startsWith('Bearer ')) return json({ error: 'unauthorized' }, 401);
    const token = auth.slice(7);

    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userRes, error: ue } = await callerClient.auth.getUser(token);
    if (ue || !userRes?.user) return json({ error: 'invalid token' }, 401);
    const callerId = userRes.user.id;

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE);
    const { data: prof, error: pe } = await admin
      .from('jt_profiles').select('role').eq('id', callerId).single();
    if (pe || prof?.role !== 'admin') return json({ error: 'forbidden — admin only' }, 403);

    const body = await req.json().catch(() => ({}));
    const action = body.action as string;

    if (action === 'list_users') {
      const { data, error } = await admin
        .from('jt_profiles')
        .select('id, username, role, created_at')
        .order('created_at', { ascending: true });
      if (error) return json({ error: error.message }, 400);

      const { data: authList } = await admin.auth.admin.listUsers({ perPage: 200 });
      const map = new Map((authList?.users || []).map(u => [u.id, u]));
      const users = (data || []).map(p => {
        const u = map.get(p.id);
        return { ...p, email: u?.email ?? '', last_sign_in_at: u?.last_sign_in_at ?? null };
      });
      return json({ users });
    }

    if (action === 'create_user') {
      const { email, password, username, role } = body;
      if (!email || !password) return json({ error: 'email + password required' }, 400);
      if (String(password).length < 6) return json({ error: 'password must be at least 6 characters' }, 400);

      const { data, error } = await admin.auth.admin.createUser({
        email, password, email_confirm: true,
        user_metadata: { username: username || (email as string).split('@')[0] },
      });
      if (error) return json({ error: error.message }, 400);

      const newId = data.user!.id;
      const finalRole = role === 'admin' ? 'admin' : 'user';
      const finalUsername = username || (email as string).split('@')[0];
      await admin.from('jt_profiles').upsert(
        { id: newId, username: finalUsername, role: finalRole },
        { onConflict: 'id' }
      );
      return json({ ok: true, user: { id: newId, email, username: finalUsername, role: finalRole } });
    }

    if (action === 'delete_user') {
      const { user_id } = body;
      if (!user_id) return json({ error: 'user_id required' }, 400);
      if (user_id === callerId) return json({ error: 'cannot delete yourself' }, 400);
      const { error } = await admin.auth.admin.deleteUser(user_id);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    if (action === 'set_role') {
      const { user_id, role } = body;
      if (!user_id || !['user','admin'].includes(role)) return json({ error: 'bad params' }, 400);
      if (user_id === callerId && role !== 'admin') {
        return json({ error: 'cannot demote yourself' }, 400);
      }
      const { error } = await admin.from('jt_profiles').update({ role }).eq('id', user_id);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    if (action === 'reset_password') {
      const { user_id, password } = body;
      if (!user_id || !password || String(password).length < 6) return json({ error: 'bad params' }, 400);
      const { error } = await admin.auth.admin.updateUserById(user_id, { password });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: 'unknown action' }, 400);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
