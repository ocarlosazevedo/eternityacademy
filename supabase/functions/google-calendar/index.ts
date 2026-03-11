import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

const MENTOR_EMAIL = 'academy@eternityholding.com';
const TZ           = 'America/Sao_Paulo';

/* ─── Refresh access token se expirado ─────────────────────────────────── */
async function freshToken(admin: any, userId: string): Promise<string> {
  const { data: row } = await admin
    .from('google_tokens').select('*').eq('user_id', userId).single();
  if (!row) throw new Error('Google Agenda não conectado para este usuário.');

  const expired = new Date(row.expires_at) <= new Date(Date.now() + 60_000);
  if (!expired) return row.access_token;

  // Renova via refresh_token
  const clientId     = Deno.env.get('GOOGLE_CLIENT_ID')!;
  const clientSecret = Deno.env.get('GOOGLE_CLIENT_SECRET')!;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id:     clientId,
      client_secret: clientSecret,
      refresh_token: row.refresh_token,
      grant_type:    'refresh_token',
    }),
  });
  const data = await res.json();
  if (data.error) throw new Error(`Refresh falhou: ${data.error}`);

  const expiresAt = new Date(Date.now() + data.expires_in * 1000).toISOString();
  await admin.from('google_tokens').update({
    access_token: data.access_token,
    expires_at:   expiresAt,
  }).eq('user_id', userId);

  return data.access_token;
}

/* ─── Busca user_id do mentor pelo email ────────────────────────────────── */
async function getMentorUserId(admin: any): Promise<string> {
  const { data: users } = await admin.auth.admin.listUsers();
  const mentor = users?.users?.find((u: any) => u.email === MENTOR_EMAIL);
  if (!mentor) throw new Error('Mentor não encontrado.');
  return mentor.id;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const body   = await req.json();
    const action = body.action;

    /* ── CREATE: cria evento no Google Agenda do mentor ─────────────────── */
    if (action === 'create') {
      const { bookingId, startAt, endAt, title, studentEmail, studentName } = body;

      const mentorId = await getMentorUserId(admin);
      const token    = await freshToken(admin, mentorId);

      const event = {
        summary:     title || 'Call de Mentoria — Eternity Academy',
        description: `Mentoria com ${studentName}\nEternity Academy`,
        start: { dateTime: startAt, timeZone: TZ },
        end:   { dateTime: endAt,   timeZone: TZ },
        attendees: [
          { email: MENTOR_EMAIL },
          { email: studentEmail, displayName: studentName },
        ],
        reminders: { useDefault: false, overrides: [
          { method: 'email',  minutes: 60 },
          { method: 'popup',  minutes: 15 },
        ]},
      };

      const res = await fetch(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events?sendUpdates=all&conferenceDataVersion=1',
        {
          method:  'POST',
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body:    JSON.stringify(event),
        },
      );
      const data = await res.json();
      if (data.error) throw new Error(data.error.message);

      // Salva calendar_event_id no booking
      if (bookingId) {
        await admin.from('bookings').update({ calendar_event_id: data.id }).eq('id', bookingId);
      }

      return new Response(JSON.stringify({
        eventId:   data.id,
        eventLink: data.htmlLink,
        meetLink:  data.hangoutLink || null,
      }), { headers: CORS });
    }

    /* ── DELETE: remove evento do Google Agenda ──────────────────────────── */
    if (action === 'delete') {
      const { eventId } = body;
      const mentorId = await getMentorUserId(admin);
      const token    = await freshToken(admin, mentorId);

      await fetch(
        `https://www.googleapis.com/calendar/v3/calendars/primary/events/${eventId}?sendUpdates=all`,
        { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } },
      );
      return new Response(JSON.stringify({ ok: true }), { headers: CORS });
    }

    /* ── BUSY: retorna períodos ocupados no calendário do mentor ──────────── */
    if (action === 'busy') {
      const { timeMin, timeMax } = body;
      const mentorId = await getMentorUserId(admin);
      const token    = await freshToken(admin, mentorId);

      const res = await fetch('https://www.googleapis.com/calendar/v3/freeBusy', {
        method:  'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          timeMin, timeMax,
          timeZone: TZ,
          items: [{ id: 'primary' }],
        }),
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error.message);

      const busy = data.calendars?.primary?.busy || [];
      return new Response(JSON.stringify({ busy }), { headers: CORS });
    }

    /* ── STATUS: verifica se mentor tem Google Agenda conectado ───────────── */
    if (action === 'status') {
      const authHeader = req.headers.get('Authorization') ?? '';
      const { data: { user } } = await admin.auth.getUser(authHeader.replace('Bearer ', ''));
      if (!user) throw new Error('Sessão inválida.');
      const { data: row } = await admin
        .from('google_tokens').select('google_email').eq('user_id', user.id).maybeSingle();
      return new Response(JSON.stringify({ connected: !!row, email: row?.google_email }), { headers: CORS });
    }

    return new Response(JSON.stringify({ error: 'Ação desconhecida.' }), { status: 400, headers: CORS });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS });
  }
});
