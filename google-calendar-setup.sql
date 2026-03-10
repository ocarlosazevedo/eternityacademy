-- ─── TABELA DE TOKENS GOOGLE ─────────────────────────────────────────────────

create table if not exists google_tokens (
  user_id       uuid primary key references auth.users on delete cascade,
  google_email  text,
  access_token  text not null,
  refresh_token text,
  expires_at    timestamptz,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table google_tokens enable row level security;

-- Cada usuário vê/edita apenas seus próprios tokens
drop policy if exists "usuario gerencia proprio token" on google_tokens;
create policy "usuario gerencia proprio token"
  on google_tokens for all
  using (auth.uid() = user_id);

-- Admin vê todos (para buscar o token do mentor)
drop policy if exists "admin le tokens" on google_tokens;
create policy "admin le tokens"
  on google_tokens for select
  using ((auth.jwt() ->> 'email') = 'academy@eternityholding.com');

-- ─── COLUNA calendar_event_id EM BOOKINGS ────────────────────────────────────

alter table bookings add column if not exists calendar_event_id text;
