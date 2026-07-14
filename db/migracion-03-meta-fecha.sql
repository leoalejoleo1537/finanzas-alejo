-- =====================================================================
--  Migración 03 — Fecha objetivo para las metas de compra
--  Pegar completo en: Supabase → SQL Editor → New query → Run
--  (re-ejecutable sin peligro)
-- =====================================================================

-- Fecha en la que quieres alcanzar la meta (opcional, para el gráfico).
alter table metas add column if not exists fecha_objetivo date;
