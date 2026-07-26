-- =============================================================================
--  Budget — schéma Supabase
--  À exécuter une seule fois dans l'éditeur SQL de ton projet Supabase.
--  (Tableau de bord Supabase → SQL Editor → coller → Run)
--
--  Chaque table appartient à un utilisateur (user_id) et est protégée par
--  Row Level Security : personne ne peut lire ou écrire les données d'un autre
--  compte, même avec la clé publique de l'application.
-- =============================================================================

-- Comptes -------------------------------------------------------------------
create table if not exists public.accounts (
  id            uuid primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  name          text not null,
  balance       double precision not null default 0,
  is_investment boolean not null default false,
  updated_at    timestamptz not null default now(),
  deleted       boolean not null default false,
  created_at    timestamptz not null default now()
);

-- Catégories ----------------------------------------------------------------
create table if not exists public.categories (
  id         uuid primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  name       text not null,
  type       text not null check (type in ('expense', 'income')),
  color      bigint not null,
  is_system  boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false,
  created_at timestamptz not null default now()
);

-- Transactions --------------------------------------------------------------
create table if not exists public.transactions (
  id           uuid primary key,
  user_id      uuid not null references auth.users (id) on delete cascade,
  type         text not null check (type in ('expense', 'income')),
  amount       double precision not null,
  category_id  uuid,
  account_id   uuid,
  date         date not null,
  description  text default '',
  source       text not null default 'manual',
  external_key text,
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,
  created_at   timestamptz not null default now()
);

create index if not exists transactions_user_date_idx
  on public.transactions (user_id, date desc);
create index if not exists transactions_external_key_idx
  on public.transactions (user_id, external_key);

-- Budgets -------------------------------------------------------------------
create table if not exists public.budgets (
  id              uuid primary key,
  user_id         uuid not null references auth.users (id) on delete cascade,
  name            text not null,
  category_id     uuid,
  amount_limit    double precision not null,
  alert_threshold integer not null default 80,
  updated_at      timestamptz not null default now(),
  deleted         boolean not null default false,
  created_at      timestamptz not null default now()
);

-- Factures ------------------------------------------------------------------
create table if not exists public.bills (
  id            uuid primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  name          text not null,
  amount        double precision not null,
  due_date      date not null,
  category_id   uuid,
  account_id    uuid,
  frequency     text not null default 'monthly',
  paid          boolean not null default false,
  reminder_days integer not null default 3,
  updated_at    timestamptz not null default now(),
  deleted       boolean not null default false,
  created_at    timestamptz not null default now()
);

-- Transferts d'investissement ------------------------------------------------
create table if not exists public.investment_transfers (
  id         uuid primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  month      text not null,
  income     double precision not null default 0,
  expenses   double precision not null default 0,
  invested   double precision not null default 0,
  kept       double precision not null default 0,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false,
  created_at timestamptz not null default now()
);

-- Agenda : catégories --------------------------------------------------------
create table if not exists public.agenda_categories (
  id         uuid primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  name       text not null,
  icon       text not null default '📅',
  color      bigint not null,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false,
  created_at timestamptz not null default now()
);

-- Agenda : événements --------------------------------------------------------
create table if not exists public.events (
  id                 uuid primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  title              text not null,
  description        text default '',
  date               date not null,
  start_minutes      integer,
  end_minutes        integer,
  location           text default '',
  agenda_category_id uuid,
  recurrence         text not null default 'none',
  reminder_minutes   integer not null default 60,
  updated_at         timestamptz not null default now(),
  deleted            boolean not null default false,
  created_at         timestamptz not null default now()
);

-- Agenda : tâches ------------------------------------------------------------
create table if not exists public.tasks (
  id         uuid primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  title      text not null,
  priority   text not null default 'medium',
  due_date   date not null,
  done       boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false,
  created_at timestamptz not null default now()
);

-- Objectifs d'épargne --------------------------------------------------------
create table if not exists public.goals (
  id             uuid primary key,
  user_id        uuid not null references auth.users (id) on delete cascade,
  name           text not null,
  target_amount  double precision not null,
  current_amount double precision not null default 0,
  deadline       date,
  updated_at     timestamptz not null default now(),
  deleted        boolean not null default false,
  created_at     timestamptz not null default now()
);

-- Réglages (une ligne par utilisateur) ---------------------------------------
create table if not exists public.user_settings (
  user_id                  uuid primary key references auth.users (id) on delete cascade,
  dark_mode                boolean not null default false,
  investment_enabled       boolean not null default false,
  investment_percent       integer not null default 50,
  notifications_enabled    boolean not null default true,
  low_balance_threshold    double precision not null default 100,
  pin_enabled              boolean not null default false,
  last_auto_transfer_month text,
  updated_at               timestamptz not null default now()
);

-- =============================================================================
--  Row Level Security : chaque utilisateur ne voit que ses propres lignes.
-- =============================================================================
do $$
declare
  t text;
begin
  foreach t in array array[
    'accounts', 'categories', 'transactions', 'budgets', 'bills',
    'investment_transfers', 'agenda_categories', 'events', 'tasks', 'goals'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);

    execute format(
      'drop policy if exists "%1$s_select" on public.%1$I', t
    );
    execute format(
      'create policy "%1$s_select" on public.%1$I for select using (auth.uid() = user_id)', t
    );

    execute format(
      'drop policy if exists "%1$s_insert" on public.%1$I', t
    );
    execute format(
      'create policy "%1$s_insert" on public.%1$I for insert with check (auth.uid() = user_id)', t
    );

    execute format(
      'drop policy if exists "%1$s_update" on public.%1$I', t
    );
    execute format(
      'create policy "%1$s_update" on public.%1$I for update using (auth.uid() = user_id) with check (auth.uid() = user_id)', t
    );

    execute format(
      'drop policy if exists "%1$s_delete" on public.%1$I', t
    );
    execute format(
      'create policy "%1$s_delete" on public.%1$I for delete using (auth.uid() = user_id)', t
    );
  end loop;
end
$$;

alter table public.user_settings enable row level security;

drop policy if exists "user_settings_select" on public.user_settings;
create policy "user_settings_select" on public.user_settings
  for select using (auth.uid() = user_id);

drop policy if exists "user_settings_insert" on public.user_settings;
create policy "user_settings_insert" on public.user_settings
  for insert with check (auth.uid() = user_id);

drop policy if exists "user_settings_update" on public.user_settings;
create policy "user_settings_update" on public.user_settings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "user_settings_delete" on public.user_settings;
create policy "user_settings_delete" on public.user_settings
  for delete using (auth.uid() = user_id);
