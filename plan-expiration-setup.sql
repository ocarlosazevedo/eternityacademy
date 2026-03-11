-- Adiciona coluna de data de expiração do plano na tabela student_profiles
ALTER TABLE student_profiles
  ADD COLUMN IF NOT EXISTS plan_expires_at date;
