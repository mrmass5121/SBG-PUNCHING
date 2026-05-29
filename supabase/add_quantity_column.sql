-- Run this in Supabase SQL Editor if the admin shows:
-- Could not find the 'quantity' column of 'productions' in the schema cache

alter table public.productions
  add column if not exists quantity integer not null default 1;

alter table public.productions
  drop constraint if exists productions_quantity_check;

alter table public.productions
  add constraint productions_quantity_check check (quantity > 0);

-- Move temporary frontend fallback tags like qty:5 into the real column.
update public.productions as p
set quantity = q.quantity
from (
  select p2.id, max(substring(t.tag from '^qty:([0-9]+)$')::integer) as quantity
  from public.productions as p2
  cross join unnest(p2.tags) as t(tag)
  where t.tag ~* '^qty:[0-9]+$'
  group by p2.id
) as q
where p.id = q.id
  and q.quantity > 0;

-- Remove temporary fallback tags after migration.
update public.productions as p
set tags = coalesce((
  select array_agg(t.tag)
  from unnest(p.tags) as t(tag)
  where t.tag !~* '^qty:[0-9]+$'
), '{}'::text[])
where exists (
  select 1
  from unnest(p.tags) as t(tag)
  where t.tag ~* '^qty:[0-9]+$'
);

-- Refresh Supabase/PostgREST schema cache immediately.
notify pgrst, 'reload schema';