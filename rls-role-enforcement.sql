-- ═══════════════════════════════════════════════════════════════════════
-- RLS: Controle de acesso por role (super_admin, admin, professor)
-- Rodar no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════

-- Helper: retorna a role do usuário logado (ou 'super_admin' para o mentor principal)
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    CASE
      WHEN (auth.jwt() ->> 'email') = 'academy@eternityholding.com' THEN 'super_admin'
      ELSE COALESCE(
        (SELECT role FROM collaborators WHERE email = (auth.jwt() ->> 'email') LIMIT 1),
        'none'
      )
    END;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- COLLABORATORS — só super_admin gerencia (já existe, reforçando)
-- ═══════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "admin gerencia colaboradores" ON collaborators;
CREATE POLICY "admin gerencia colaboradores" ON collaborators
  FOR ALL USING (get_my_role() = 'super_admin');

-- Colaborador lê seu próprio registro (para login/role check)
DROP POLICY IF EXISTS "colaborador ve proprio registro" ON collaborators;
CREATE POLICY "colaborador ve proprio registro" ON collaborators
  FOR SELECT USING ((auth.jwt() ->> 'email') = email);

-- ═══════════════════════════════════════════════════════════════════════
-- STUDENT_PROFILES — professor: só leitura | admin+super_admin: tudo
-- ═══════════════════════════════════════════════════════════════════════
-- Aluno lê/edita seu próprio perfil (manter existente)
-- Colaborador leitura
DROP POLICY IF EXISTS "colaborador le alunos" ON student_profiles;
CREATE POLICY "colaborador le alunos" ON student_profiles
  FOR SELECT USING (
    auth.uid() = id
    OR EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );

-- Só admin/super_admin podem modificar alunos
DROP POLICY IF EXISTS "admin modifica alunos" ON student_profiles;
CREATE POLICY "admin modifica alunos" ON student_profiles
  FOR UPDATE USING (
    auth.uid() = id
    OR get_my_role() IN ('super_admin', 'admin')
  );

DROP POLICY IF EXISTS "admin deleta alunos" ON student_profiles;
CREATE POLICY "admin deleta alunos" ON student_profiles
  FOR DELETE USING (
    get_my_role() IN ('super_admin', 'admin')
  );

-- ═══════════════════════════════════════════════════════════════════════
-- BOOKINGS — professor: só leitura | super_admin: tudo
-- ═══════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "colaborador le agendamentos" ON bookings;
CREATE POLICY "colaborador le agendamentos" ON bookings
  FOR SELECT USING (
    auth.uid() = student_id
    OR EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );

DROP POLICY IF EXISTS "admin gerencia agendamentos" ON bookings;
CREATE POLICY "admin gerencia agendamentos" ON bookings
  FOR ALL USING (
    auth.uid() = student_id
    OR get_my_role() IN ('super_admin', 'admin')
  );

-- ═══════════════════════════════════════════════════════════════════════
-- TASKS — professor pode ler e criar, mas não deletar | admin+super: tudo
-- ═══════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "colaborador le tarefas" ON tasks;
CREATE POLICY "colaborador le tarefas" ON tasks
  FOR SELECT USING (
    auth.uid() = student_id
    OR EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );

DROP POLICY IF EXISTS "colaborador cria tarefas" ON tasks;
CREATE POLICY "colaborador cria tarefas" ON tasks
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );

DROP POLICY IF EXISTS "colaborador atualiza tarefas" ON tasks;
CREATE POLICY "colaborador atualiza tarefas" ON tasks
  FOR UPDATE USING (
    auth.uid() = student_id
    OR EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );

DROP POLICY IF EXISTS "admin deleta tarefas" ON tasks;
CREATE POLICY "admin deleta tarefas" ON tasks
  FOR DELETE USING (
    get_my_role() IN ('super_admin', 'admin')
  );

-- ═══════════════════════════════════════════════════════════════════════
-- MENTOR_SLOTS + BLOCKED_DATES — só super_admin modifica
-- ═══════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "super_admin gerencia slots" ON mentor_slots;
CREATE POLICY "super_admin gerencia slots" ON mentor_slots
  FOR ALL USING (get_my_role() = 'super_admin');

-- Manter leitura pública para agendamento
DROP POLICY IF EXISTS "le slots disponíveis" ON mentor_slots;
CREATE POLICY "le slots disponíveis" ON mentor_slots
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "super_admin gerencia blocked" ON blocked_dates;
CREATE POLICY "super_admin gerencia blocked" ON blocked_dates
  FOR ALL USING (get_my_role() = 'super_admin');

DROP POLICY IF EXISTS "le datas bloqueadas" ON blocked_dates;
CREATE POLICY "le datas bloqueadas" ON blocked_dates
  FOR SELECT USING (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════════════════════════════════
-- FEEDBACKS — professor: só leitura | admin+super: tudo
-- ═══════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "colaborador le feedbacks" ON feedbacks;
CREATE POLICY "colaborador le feedbacks" ON feedbacks
  FOR SELECT USING (
    auth.uid() = student_id
    OR get_my_role() IN ('super_admin', 'admin')
  );

-- ═══════════════════════════════════════════════════════════════════════
-- AUDIT_LOG — só admin+ lê, só o sistema insere
-- ═══════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "Admins read audit log" ON audit_log;
CREATE POLICY "Admins read audit log" ON audit_log
  FOR SELECT USING (get_my_role() IN ('super_admin', 'admin'));

DROP POLICY IF EXISTS "Admins insert audit log" ON audit_log;
CREATE POLICY "Admins insert audit log" ON audit_log
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM collaborators WHERE email = (auth.jwt() ->> 'email'))
  );
