-- Verifica se há dados na tabela
SELECT count(*) as total FROM weekly_growth;

-- Policy mais ampla para admins: usa auth.role() ou verifica collaborators
DROP POLICY IF EXISTS "Admins full access growth" ON weekly_growth;
CREATE POLICY "Admins full access growth" ON weekly_growth
  FOR ALL USING (
    EXISTS (SELECT 1 FROM collaborators WHERE id = auth.uid())
  );

-- Policy alternativa: qualquer usuário autenticado pode ler tudo (para admins)
DROP POLICY IF EXISTS "Authenticated read all growth" ON weekly_growth;
CREATE POLICY "Authenticated read all growth" ON weekly_growth
  FOR SELECT USING (auth.role() = 'authenticated');
