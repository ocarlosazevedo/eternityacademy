-- ═══════════════════════════════════════════════════════════════════════
-- Monitoramento: error_logs + usage_analytics
-- Rodar no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════

-- Tabela de erros do frontend
CREATE TABLE IF NOT EXISTS error_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  user_email text,
  source text NOT NULL DEFAULT 'unknown',  -- 'admin' | 'dashboard'
  error_message text NOT NULL,
  error_stack text,
  url text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

-- Qualquer autenticado pode inserir erros (próprios)
DROP POLICY IF EXISTS "Users insert own errors" ON error_logs;
CREATE POLICY "Users insert own errors" ON error_logs
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Só admins leem
DROP POLICY IF EXISTS "Admins read errors" ON error_logs;
CREATE POLICY "Admins read errors" ON error_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );

CREATE INDEX IF NOT EXISTS idx_error_logs_created ON error_logs(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════

-- Tabela de analytics de uso
CREATE TABLE IF NOT EXISTS usage_analytics (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  source text NOT NULL DEFAULT 'dashboard',  -- 'admin' | 'dashboard'
  event text NOT NULL,                        -- 'page_view' | 'action'
  page text,
  action text,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE usage_analytics ENABLE ROW LEVEL SECURITY;

-- Qualquer autenticado pode inserir
DROP POLICY IF EXISTS "Users insert analytics" ON usage_analytics;
CREATE POLICY "Users insert analytics" ON usage_analytics
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Só admins leem
DROP POLICY IF EXISTS "Admins read analytics" ON usage_analytics;
CREATE POLICY "Admins read analytics" ON usage_analytics
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );

CREATE INDEX IF NOT EXISTS idx_analytics_created ON usage_analytics(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_event ON usage_analytics(event, page);
