-- =====================================================================
--  Migración 01 — Metas de compra + arrastre de saldo entre meses
--  Pegar completo en: Supabase → SQL Editor → New query → Run
--  (re-ejecutable sin peligro)
-- =====================================================================

-- Metas de compra: fecha en que se cumplió (null = activa)
alter table metas add column if not exists cumplida_en date;

-- Saldo inicial por mes (arrastre automático, ajustable a mano)
create table if not exists saldos_mes (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  mes            text not null,                    -- 'YYYY-MM'
  saldo_inicial  numeric(14,2) not null default 0,
  manual         boolean default false,            -- true = lo fijaste tú
  creado_en      timestamptz default now(),
  unique(user_id, mes)
);

alter table saldos_mes enable row level security;
drop policy if exists saldos_mes on saldos_mes;
create policy saldos_mes on saldos_mes
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'saldos_mes'
  ) then
    alter publication supabase_realtime add table saldos_mes;
  end if;
end $$;
