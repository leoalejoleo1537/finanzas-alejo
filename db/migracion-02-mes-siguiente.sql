-- =====================================================================
--  Migración 02 — Egresos que se pagan el mes siguiente
--  Pegar completo en: Supabase → SQL Editor → New query → Run
--  (re-ejecutable sin peligro)
-- =====================================================================

-- Marca si un egreso fijo se paga en los primeros días del mes siguiente
-- (ej: cuentas que vencen el 5 de agosto por el consumo de julio).
alter table egresos_fijos add column if not exists mes_siguiente boolean default false;
