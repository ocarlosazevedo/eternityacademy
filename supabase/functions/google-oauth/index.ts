import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const { code, redirectUri } = await req.json();
    if (!code) throw new Error('Código OAuth não fornecido.');

    const clientId     = Deno.env.get('GOOGLE_CLIENT_ID')!;
    const clientSecret = Deno.env.get('GOOGLE_CLIENT_SECRET')!;
    const redirect     = redirectUri || 'https://eternityacademy.com.br/google-callback';

    // 1. Troca o code por tokens
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id:     clientId,
        client_secret: clientSecret,
        redirect_uri:  redirect,
        grant_type:    'authorization_code',
      }),
    });
    const tokens = await tokenRes.json();
    if (tokens.error) throw new Error(`Google: ${tokens.error_description || tokens.error}`);

    // 2. Descobre o email da conta Google conectada
    const profileRes = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    });
    const profile = await profileRes.json();

    // 3. Persiste tokens no Supabase
    const authHeader = req.headers.get('Authorization') ?? '';
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const { data: { user } } = await admin.auth.getUser(authHeader.replace('Bearer ', ''));
    if (!user) throw new Error('Sessão inválida.');

    const expiresAt = new Date(Date.now() + tokens.expires_in * 1000).toISOString();

    const { error: upsertErr } = await admin.from('google_tokens').upsert({
      user_id:       user.id,
      google_email:  profile.email,
      access_token:  tokens.access_token,
      refresh_token: tokens.refresh_token || null,
      expires_at:    expiresAt,
    }, { onConflict: 'user_id' });

    if (upsertErr) throw new Error(`Erro ao salvar token: ${upsertErr.message}`);

    return new Response(JSON.stringify({ ok: true, email: profile.email }), { headers: CORS });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 400, headers: CORS });
  }
});
