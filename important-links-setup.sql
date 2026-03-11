-- Tabela de links importantes (gerenciados pelos admins, visíveis aos alunos)
CREATE TABLE IF NOT EXISTS important_links (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name       text NOT NULL,
  url        text NOT NULL,
  "order"    integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE important_links ENABLE ROW LEVEL SECURITY;

-- Qualquer usuário autenticado pode ler
CREATE POLICY "read_links" ON important_links
  FOR SELECT TO authenticated USING (true);

-- Qualquer usuário autenticado pode criar/atualizar/deletar
-- (segurança adicional é feita no nível do app — só admins chegam ao painel)
CREATE POLICY "manage_links" ON important_links
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
