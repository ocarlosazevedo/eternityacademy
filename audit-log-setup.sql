-- Tabela de histórico de alterações (audit log)
CREATE TABLE IF NOT EXISTS audit_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id uuid NOT NULL,
  admin_name text,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id uuid,
  target_name text,
  details text,
  created_at timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins read audit log" ON audit_log;
CREATE POLICY "Admins read audit log" ON audit_log
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM collaborators WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "Admins insert audit log" ON audit_log;
CREATE POLICY "Admins insert audit log" ON audit_log
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM collaborators WHERE id = auth.uid())
  );

-- Index para buscas rápidas
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_target ON audit_log(target_id);
