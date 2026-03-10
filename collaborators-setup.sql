-- ─── TABELA DE COLABORADORES ─────────────────────────────────────────────────

create table if not exists collaborators (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  email      text,
  role       text not null default 'professor',  -- 'super_admin' | 'admin' | 'professor'
  notes      text,
  created_at timestamptz default now()
);

-- ─── RLS ─────────────────────────────────────────────────────────────────────

alter table collaborators enable row level security;

-- Super admin gerencia tudo
drop policy if exists "admin gerencia colaboradores" on collaborators;
create policy "admin gerencia colaboradores"
  on collaborators for all
  using ((auth.jwt() ->> 'email') = 'academy@eternityholding.com');

-- Colaborador pode ler seu próprio registro (necessário para checar role no login)
drop policy if exists "colaborador ve proprio registro" on collaborators;
create policy "colaborador ve proprio registro"
  on collaborators for select
  using ((auth.jwt() ->> 'email') = email);

-- ─── ACESSO DOS COLABORADORES ÀS DEMAIS TABELAS ──────────────────────────────
-- Permissões de leitura para todos os colaboradores autenticados

drop policy if exists "colaborador le agendamentos" on bookings;
create policy "colaborador le agendamentos"
  on bookings for select
  using (
    exists (
      select 1 from collaborators
      where email = (auth.jwt() ->> 'email')
    )
  );

drop policy if exists "colaborador le slots" on mentor_slots;
create policy "colaborador le slots"
  on mentor_slots for select
  using (
    exists (select 1 from collaborators where email = (auth.jwt() ->> 'email'))
  );

drop policy if exists "colaborador le blocked" on blocked_dates;
create policy "colaborador le blocked"
  on blocked_dates for select
  using (
    exists (select 1 from collaborators where email = (auth.jwt() ->> 'email'))
  );

drop policy if exists "colaborador le tarefas" on tasks;
create policy "colaborador le tarefas"
  on tasks for all
  using (
    exists (select 1 from collaborators where email = (auth.jwt() ->> 'email'))
  );

drop policy if exists "colaborador le alunos" on student_profiles;
create policy "colaborador le alunos"
  on student_profiles for select
  using (
    exists (select 1 from collaborators where email = (auth.jwt() ->> 'email'))
  );
