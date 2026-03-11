-- Tabela de links importantes por aluno (gerenciados pelos admins no perfil de cada aluno)
-- Se a tabela já existir da versão anterior, execute o ALTER antes:
-- ALTER TABLE important_links ADD COLUMN IF NOT EXISTS student_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE TABLE IF NOT EXISTS important_links (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name       text NOT NULL,
  url        text NOT NULL,
  "order"    integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE important_links ENABLE ROW LEVEL SECURITY;

-- Alunos leem apenas os próprios links
CREATE POLICY "student_read_own_links" ON important_links
  FOR SELECT TO authenticated USING (student_id = auth.uid());

-- Admins gerenciam todos os links (insert, update, delete)
CREATE POLICY "admin_manage_links" ON important_links
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
