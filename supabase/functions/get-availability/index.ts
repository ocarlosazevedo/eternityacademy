import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

const MENTOR_EMAIL = 'academy@eternityholding.com';
const TZ_OFFSET    = -3; // America/Sao_Paulo (UTC-3)

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { year, month } = await req.json(); // month = 0-based (JS Date)

    // Busca slots ativos configurados pelo mentor
    const { data: slots } = await admin
      .from('mentor_slots')
      .select('day_of_week, slot_time')
      .eq('mentor_email', MENTOR_EMAIL)
      .eq('active', true);

    if (!slots || slots.length === 0) {
      return new Response(JSON.stringify({ availability: {} }), { headers: CORS });
    }

    // Datas bloqueadas do mês
    const firstDay = `${year}-${String(month + 1).padStart(2, '0')}-01`;
    const lastDay  = new Date(year, month + 1, 0);
    const lastDayStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(lastDay.getDate()).padStart(2, '0')}`;

    const { data: blocked } = await admin
      .from('blocked_dates')
      .select('blocked_date')
      .eq('mentor_email', MENTOR_EMAIL)
      .gte('blocked_date', firstDay)
      .lte('blocked_date', lastDayStr);

    const blockedSet = new Set((blocked || []).map((b: any) => b.blocked_date));

    // Agendamentos confirmados do mês (para remover horários já ocupados)
    const { data: bookings } = await admin
      .from('bookings')
      .select('scheduled_at')
      .eq('mentor_email', MENTOR_EMAIL)
      .eq('status', 'confirmed')
      .gte('scheduled_at', `${firstDay}T00:00:00-03:00`)
      .lte('scheduled_at', `${lastDayStr}T23:59:59-03:00`);

    // Monta set de horários já reservados: "2024-03-15|09:00"
    const bookedSet = new Set<string>();
    for (const b of (bookings || [])) {
      const d = new Date(b.scheduled_at);
      const dateKey = d.toLocaleDateString('sv-SE', { timeZone: 'America/Sao_Paulo' });
      const timeKey = d.toLocaleTimeString('pt-BR', { timeZone: 'America/Sao_Paulo', hour: '2-digit', minute: '2-digit', hour12: false });
      bookedSet.add(`${dateKey}|${timeKey}`);
    }

    // Agrupa slots por dia da semana
    const slotsByDow: Record<number, string[]> = {};
    for (const s of slots) {
      if (!slotsByDow[s.day_of_week]) slotsByDow[s.day_of_week] = [];
      slotsByDow[s.day_of_week].push(s.slot_time.slice(0, 5)); // "HH:MM"
    }

    // Monta disponibilidade para cada dia do mês
    const availability: Record<string, string[]> = {};
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    for (let day = 1; day <= lastDay.getDate(); day++) {
      const date    = new Date(year, month, day);
      const dateKey = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

      // Ignora dias passados e bloqueados
      if (date < today) continue;
      if (blockedSet.has(dateKey)) continue;

      const dow      = date.getDay(); // 0=Dom ... 6=Sab
      const daySlots = slotsByDow[dow];
      if (!daySlots || daySlots.length === 0) continue;

      // Remove horários já reservados
      const free = daySlots.filter(t => !bookedSet.has(`${dateKey}|${t}`));
      if (free.length > 0) availability[dateKey] = free.sort();
    }

    return new Response(JSON.stringify({ availability }), { headers: CORS });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS });
  }
});
