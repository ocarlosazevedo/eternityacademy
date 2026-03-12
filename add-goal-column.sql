-- Adiciona coluna de meta de faturamento ao perfil do aluno
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS goal_amount numeric(12,2) DEFAULT NULL;
