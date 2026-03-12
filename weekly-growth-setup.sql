-- Tabela de controle de crescimento semanal
CREATE TABLE IF NOT EXISTS weekly_growth (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id uuid REFERENCES student_profiles(id) ON DELETE CASCADE NOT NULL,
  week_number int NOT NULL,
  gross_revenue numeric(12,2) DEFAULT 0,
  net_revenue numeric(12,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(student_id, week_number)
);

-- RLS
ALTER TABLE weekly_growth ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students read own growth" ON weekly_growth;
CREATE POLICY "Students read own growth" ON weekly_growth
  FOR SELECT USING (auth.uid() = student_id);

DROP POLICY IF EXISTS "Students insert own growth" ON weekly_growth;
CREATE POLICY "Students insert own growth" ON weekly_growth
  FOR INSERT WITH CHECK (auth.uid() = student_id);

DROP POLICY IF EXISTS "Students update own growth" ON weekly_growth;
CREATE POLICY "Students update own growth" ON weekly_growth
  FOR UPDATE USING (auth.uid() = student_id);

DROP POLICY IF EXISTS "Admins full access growth" ON weekly_growth;
CREATE POLICY "Admins full access growth" ON weekly_growth
  FOR ALL USING (
    EXISTS (SELECT 1 FROM collaborators WHERE id = auth.uid())
  );
