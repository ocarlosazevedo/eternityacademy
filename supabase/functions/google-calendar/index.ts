import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

const TZ = 'America/Sao_Paulo';
const MENTOR_EMAIL = 'academy@eternityholding.com';

/* ─── Obtém access token usando o refresh token fixo ───────────────────── */
async function getAccessToken(): Promise<string> {
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id:     Deno.env.get('GOOGLE_CLIENT_ID')!,
      client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!,
      refresh_token: Deno.env.get('GOOGLE_REFRESH_TOKEN')!,
      grant_type:    'refresh_token',
    }),
  });
  const data = await res.json();
  if (data.error) throw new Error(`Token refresh falhou: ${data.error_description || data.error}`);
  return data.access_token;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const body   = await req.json();
    const action = body.action;

    /* ── STATUS ──────────────────────────────────────────────────────────── */
    if (action === 'status') {
      // Testa se consegue obter um access token com o refresh token configurado
      try {
        await getAccessToken();
        return new Response(JSON.stringify({ connected: true, email: MENTOR_EMAIL }), { headers: CORS });
      } catch {
        return new Response(JSON.stringify({ connected: false }), { headers: CORS });
      }
    }

    /* ── CREATE: cria evento no Google Agenda ────────────────────────────── */
    if (action === 'create') {
      const { bookingId, startAt, endAt, title, studentEmail, studentName } = body;
      const token = await getAccessToken();

      const event = {
        summary:     title || 'Call de Mentoria — Eternity Academy',
        description: `Mentoria com ${studentName}\nEternity Academy`,
        start: { dateTime: startAt, timeZone: TZ },
        end:   { dateTime: endAt,   timeZone: TZ },
        attendees: [
          { email: MENTOR_EMAIL },
          { email: studentEmail, displayName: studentName },
        ],
        conferenceData: { createRequest: { requestId: bookingId || crypto.randomUUID() } },
        reminders: { useDefault: false, overrides: [
          { method: 'email', minutes: 60 },
          { method: 'popup', minutes: 15 },
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

      return new Response(JSON.stringify({
        eventId:   data.id,
        eventLink: data.htmlLink,
        meetLink:  data.hangoutLink || data.conferenceData?.entryPoints?.[0]?.uri || null,
      }), { headers: CORS });
    }

    /* ── DELETE: remove evento ───────────────────────────────────────────── */
    if (action === 'delete') {
      const { eventId } = body;
      const token = await getAccessToken();
      await fetch(
        `https://www.googleapis.com/calendar/v3/calendars/primary/events/${eventId}?sendUpdates=all`,
        { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } },
      );
      return new Response(JSON.stringify({ ok: true }), { headers: CORS });
    }

    /* ── BUSY: períodos ocupados ─────────────────────────────────────────── */
    if (action === 'busy') {
      const { timeMin, timeMax } = body;
      const token = await getAccessToken();
      const res = await fetch('https://www.googleapis.com/calendar/v3/freeBusy', {
        method:  'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ timeMin, timeMax, timeZone: TZ, items: [{ id: 'primary' }] }),
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error.message);
      return new Response(JSON.stringify({ busy: data.calendars?.primary?.busy || [] }), { headers: CORS });
    }

    return new Response(JSON.stringify({ error: 'Ação desconhecida.' }), { status: 400, headers: CORS });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS });
  }
});
