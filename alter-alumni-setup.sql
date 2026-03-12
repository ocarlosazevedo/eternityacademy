-- Adiciona coluna is_alumni na tabela student_profiles
ALTER TABLE student_profiles
  ADD COLUMN IF NOT EXISTS is_alumni boolean DEFAULT false;
