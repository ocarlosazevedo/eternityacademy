-- ─── NOVAS TABELAS ────────────────────────────────────────────────────────────

create table if not exists student_profiles (
  id            uuid primary key references auth.users on delete cascade,
  full_name     text,
  email         text,
  plan          text default 'MDG INSIDER',
  support_phone text,
  created_at    timestamptz default now()
);

-- Adicionar coluna se a tabela já existir
alter table student_profiles add column if not exists support_phone text;

create table if not exists feedbacks (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid references auth.users on delete cascade,
  student_name text,
  call_title   text,
  rating       int  check (rating between 1 and 5),
  body         text,
  created_at   timestamptz default now()
);

create table if not exists tasks (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid references auth.users on delete cascade,
  call_number int,
  title       text not null,
  mentor_note text,
  done        boolean default false,
  created_at  timestamptz default now()
);

-- ─── RLS ──────────────────────────────────────────────────────────────────────

alter table student_profiles enable row level security;
alter table feedbacks        enable row level security;
alter table tasks            enable row level security;

-- ─── POLÍTICAS (drop antes de criar para evitar conflito) ─────────────────────

-- student_profiles
drop policy if exists "aluno ve proprio perfil"       on student_profiles;
drop policy if exists "aluno insere proprio perfil"   on student_profiles;
drop policy if exists "aluno atualiza proprio perfil" on student_profiles;
drop policy if exists "admin gerencia perfis"         on student_profiles;

create policy "aluno ve proprio perfil"       on student_profiles for select using (auth.uid() = id);
create policy "aluno insere proprio perfil"   on student_profiles for insert with check (auth.uid() = id);
create policy "aluno atualiza proprio perfil" on student_profiles for update using (auth.uid() = id);
create policy "admin gerencia perfis"         on student_profiles for all   using ((auth.jwt() ->> 'email') = 'academy@eternityholding.com');

-- feedbacks
drop policy if exists "aluno envia feedback" on feedbacks;
drop policy if exists "admin le feedbacks"   on feedbacks;

create policy "aluno envia feedback" on feedbacks for insert with check (auth.uid() = student_id);
create policy "admin le feedbacks"   on feedbacks for all   using ((auth.jwt() ->> 'email') = 'academy@eternityholding.com');

-- tasks
drop policy if exists "aluno ve tarefas"       on tasks;
drop policy if exists "aluno atualiza tarefa"  on tasks;
drop policy if exists "admin gerencia tarefas" on tasks;

create policy "aluno ve tarefas"       on tasks for select using (auth.uid() = student_id);
create policy "aluno atualiza tarefa"  on tasks for update using (auth.uid() = student_id) with check (auth.uid() = student_id);
create policy "admin gerencia tarefas" on tasks for all   using ((auth.jwt() ->> 'email') = 'academy@eternityholding.com');

-- ─── POLÍTICAS ADMIN NAS TABELAS EXISTENTES ───────────────────────────────────

drop policy if exists "admin gerencia bookings" on bookings;
drop policy if exists "admin gerencia slots"    on mentor_slots;
drop policy if exists "admin gerencia blocked"  on blocked_dates;

create policy "admin gerencia bookings" on bookings      for all using ((auth.jwt() ->> 'email') = 'academy@eternityholding.com');
create policy "admin gerencia slots"    on mentor_slots  for all using ((auth.jwt() ->> 'email') = 'academy@eternityholding.com');
create policy "admin gerencia blocked"  on blocked_dates for all using ((auth.jwt() ->> 'email') = 'academy@eternityholding.com');
