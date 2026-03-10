-- ─── TABELAS ────────────────────────────────────────────────────────────────

create table mentor_slots (
  id           uuid primary key default gen_random_uuid(),
  mentor_email text not null,
  day_of_week  int  not null, -- 1=seg 2=ter 3=qua 4=qui 5=sex
  slot_time    time not null,
  active       boolean default true
);

create table blocked_dates (
  id           uuid primary key default gen_random_uuid(),
  mentor_email text not null,
  blocked_date date not null
);

create table bookings (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid references auth.users on delete cascade,
  mentor_email  text not null,
  call_number   int,
  call_title    text,
  scheduled_at  timestamptz not null,
  status        text default 'confirmed',
  meet_link     text,
  gcal_event_id text,
  created_at    timestamptz default now()
);

-- ─── RLS ─────────────────────────────────────────────────────────────────────

alter table bookings      enable row level security;
alter table mentor_slots  enable row level security;
alter table blocked_dates enable row level security;

create policy "aluno ve seus bookings"   on bookings      for select using (auth.uid() = student_id);
create policy "aluno insere booking"     on bookings      for insert with check (auth.uid() = student_id);
create policy "le slots disponíveis"     on mentor_slots  for select using (auth.role() = 'authenticated');
create policy "le datas bloqueadas"      on blocked_dates for select using (auth.role() = 'authenticated');

-- ─── SEED: slots do mentor (seg-sex, 09h–17h) ────────────────────────────────
-- Substitua 'academy@eternityacademy.com.br' pelo e-mail real do mentor se necessário

do $$
declare
  mentor text := 'academy@eternityacademy.com.br';
  dow    int;
  t      text;
begin
  foreach dow in array array[1,2,3,4,5] loop
    foreach t in array array['09:00','10:00','11:00','14:00','15:00','16:00','17:00'] loop
      insert into mentor_slots (mentor_email, day_of_week, slot_time)
      values (mentor, dow, t::time);
    end loop;
  end loop;
end $$;
