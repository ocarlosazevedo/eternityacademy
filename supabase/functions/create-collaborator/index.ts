import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const authHeader = req.headers.get('Authorization') ?? '';
  const callerToken = authHeader.replace('Bearer ', '');

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // Verifica se quem chama é o super admin
  const { data: { user: caller } } = await admin.auth.getUser(callerToken);
  if (caller?.email !== 'academy@eternityholding.com') {
    return new Response(JSON.stringify({ error: 'Não autorizado.' }), { status: 403, headers: CORS });
  }

  const { email, password, name, role, notes } = await req.json();

  if (!email || !password || !name || !role) {
    return new Response(JSON.stringify({ error: 'Campos obrigatórios: email, password, name, role.' }), { status: 400, headers: CORS });
  }

  // Cria conta Supabase Auth
  const { data: created, error: authErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (authErr) {
    return new Response(JSON.stringify({ error: authErr.message }), { status: 400, headers: CORS });
  }

  // Insere na tabela collaborators
  const { error: dbErr } = await admin.from('collaborators').insert({
    name: name.trim(),
    email: email.trim().toLowerCase(),
    role,
    notes: notes?.trim() || null,
  });

  if (dbErr) {
    // Desfaz criação do usuário se o insert falhar
    await admin.auth.admin.deleteUser(created.user!.id);
    return new Response(JSON.stringify({ error: dbErr.message }), { status: 400, headers: CORS });
  }

  return new Response(JSON.stringify({ ok: true }), { headers: CORS });
});
