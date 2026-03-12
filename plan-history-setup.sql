-- Histórico de mudanças de plano
CREATE TABLE IF NOT EXISTS plan_history (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id uuid NOT NULL,
  previous_plan text NOT NULL,
  new_plan text NOT NULL,
  changed_by uuid,
  changed_by_name text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE plan_history ENABLE ROW LEVEL SECURITY;

-- Admins leem e inserem
DROP POLICY IF EXISTS "Admins manage plan history" ON plan_history;
CREATE POLICY "Admins manage plan history" ON plan_history
  FOR ALL USING (
    EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );

-- Aluno vê seu próprio histórico
DROP POLICY IF EXISTS "Student reads own plan history" ON plan_history;
CREATE POLICY "Student reads own plan history" ON plan_history
  FOR SELECT USING (auth.uid() = student_id);

CREATE INDEX IF NOT EXISTS idx_plan_history_student ON plan_history(student_id, created_at DESC);
