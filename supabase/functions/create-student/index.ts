import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const { email, password, fullName, plan } = await req.json();
    if (!email || !password || !fullName) throw new Error('Campos obrigatórios: email, password, fullName.');

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // 1. Cria o usuário (já confirmado, sem precisar verificar email)
    const { data: { user }, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (createErr) throw new Error(createErr.message);
    if (!user) throw new Error('Usuário não criado.');

    // 2. Salva o perfil do aluno
    await admin.from('student_profiles').upsert({
      id:        user.id,
      email,
      full_name: fullName,
      plan:      plan || 'MDG INSIDER',
    }, { onConflict: 'id' });

    // 3. Envia email para o aluno definir/confirmar sua senha
    const anon = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
    );
    await anon.auth.resetPasswordForEmail(email, {
      redirectTo: 'https://eternityacademy.com.br/login',
    });

    return new Response(JSON.stringify({ ok: true, userId: user.id }), { headers: CORS });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 400, headers: CORS });
  }
});
