-- =====================================================================
--  Finanzas Alejo — Esquema de base de datos (Supabase / PostgreSQL)
--  Pegar completo en:  Supabase → SQL Editor → New query → Run
--  Un solo usuario (tú). RLS activo: solo tú ves tus filas.
-- =====================================================================

-- ---------- CUENTAS (bancos y tarjetas) ----------
create table if not exists cuentas (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre     text not null,
  tipo       text not null default 'banco',   -- 'banco' | 'tarjeta_credito' | 'tarjeta_debito' | 'efectivo'
  moneda     text not null default 'CLP',
  creado_en  timestamptz default now()
);

-- ---------- CATEGORIAS ----------
create table if not exists categorias (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre     text not null,
  color      text default '#d9a8a0',
  tipo       text not null default 'gasto',    -- 'gasto' | 'ingreso'
  creado_en  timestamptz default now()
);

-- ---------- REGLAS DE CATEGORIZACION (comercio -> categoria) ----------
create table if not exists reglas_categoria (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  patron       text not null,                  -- substring del comercio a buscar (case-insensitive)
  categoria_id uuid references categorias(id) on delete set null,
  creado_en    timestamptz default now()
);

-- ---------- MOVIMIENTOS (transacciones: cartola + manual) ----------
create table if not exists movimientos (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users(id) on delete cascade,
  fecha            date not null,
  comercio         text not null,              -- nombre limpio del comercio
  descripcion_cruda text,                      -- texto original del banco (para hover)
  monto            numeric(14,2) not null,      -- negativo = gasto, positivo = ingreso
  tipo             text not null default 'gasto', -- 'gasto' | 'ingreso' | 'transferencia' | 'reembolso'
  categoria_id     uuid references categorias(id) on delete set null,
  cuenta_id        uuid references cuentas(id) on delete set null,
  estado           text,                        -- null | 'cancelado' | 'podria_cancelar'
  origen           text not null default 'manual', -- 'manual' | 'cartola'
  hash_dedup       text,                        -- para evitar duplicados al importar cartola
  creado_en        timestamptz default now()
);
create index if not exists idx_movimientos_fecha on movimientos(user_id, fecha);
create unique index if not exists idx_movimientos_dedup on movimientos(user_id, hash_dedup) where hash_dedup is not null;

-- ---------- INGRESOS DIARIOS (modelo hospitalería: turno + propinas) ----------
create table if not exists ingresos_diarios (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  fecha      date not null,
  turno      numeric(14,2) default 0,           -- sueldo/turno del día
  propinas   numeric(14,2) default 0,
  creado_en  timestamptz default now()
);
create index if not exists idx_ingresos_fecha on ingresos_diarios(user_id, fecha);

-- ---------- EGRESOS FIJOS (recurrentes con día de pago) ----------
create table if not exists egresos_fijos (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre       text not null,
  monto        numeric(14,2) not null default 0,
  dia_pago     int not null default 1 check (dia_pago between 1 and 31),
  categoria_id uuid references categorias(id) on delete set null,
  activo       boolean default true,
  creado_en    timestamptz default now()
);

-- ---------- METAS (deuda universitaria, ahorros, etc.) ----------
create table if not exists metas (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre          text not null,
  tipo            text not null default 'deuda',  -- 'deuda' | 'ahorro'
  monto_objetivo  numeric(14,2) not null default 0,
  creado_en       timestamptz default now()
);

-- ---------- ABONOS (aportes a una meta) ----------
create table if not exists abonos (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  meta_id    uuid not null references metas(id) on delete cascade,
  nota       text,
  monto      numeric(14,2) not null default 0,
  fecha      date,
  creado_en  timestamptz default now()
);

-- ---------- PRESUPUESTOS (límite mensual por categoría) ----------
create table if not exists presupuestos (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  categoria_id    uuid not null references categorias(id) on delete cascade,
  limite_mensual  numeric(14,2) not null default 0,
  creado_en       timestamptz default now(),
  unique(user_id, categoria_id)
);

-- =====================================================================
--  ROW LEVEL SECURITY — cada quien solo ve/edita sus propias filas
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array[
    'cuentas','categorias','reglas_categoria','movimientos',
    'ingresos_diarios','egresos_fijos','metas','abonos','presupuestos'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('drop policy if exists %1$I on %1$I;', t);
    execute format($f$
      create policy %1$I on %1$I
        for all
        using (user_id = auth.uid())
        with check (user_id = auth.uid());
    $f$, t);
  end loop;
end $$;

-- =====================================================================
--  REALTIME — que los cambios se transmitan a todos tus dispositivos
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array[
    'cuentas','categorias','reglas_categoria','movimientos',
    'ingresos_diarios','egresos_fijos','metas','abonos','presupuestos'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I;', t);
    end if;
  end loop;
end $$;
