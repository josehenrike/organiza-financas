-- Dados financeiros de cada usuário: um documento JSON por conta.
create table if not exists public.finance_data (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

-- Cada pessoa só enxerga e altera os próprios dados.
alter table public.finance_data enable row level security;

create policy "Ler os próprios dados"
  on public.finance_data for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Criar os próprios dados"
  on public.finance_data for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Atualizar os próprios dados"
  on public.finance_data for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Excluir os próprios dados"
  on public.finance_data for delete
  to authenticated
  using ((select auth.uid()) = user_id);
