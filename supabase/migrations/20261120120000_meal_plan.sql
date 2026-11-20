-- Meal plan: admin (HR) sets what to cook on each weekday, with pictures;
-- the maid ticks each meal with a photo.

create table public.meal_items (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.profiles on delete cascade,
  weekday int not null check (weekday between 1 and 7),
  section text not null check (section in ('morning', 'tea', 'salad', 'main', 'fruit')),
  name text not null,
  note text not null default '',
  photo text,
  sort int not null default 0,
  created_by uuid references public.profiles on delete set null,
  created_at timestamptz not null default now()
);

create index meal_items_person on public.meal_items (person_id, weekday);

create table public.meal_ticks (
  day date not null,
  item_id uuid not null references public.meal_items on delete cascade,
  person_id uuid not null references public.profiles on delete cascade,
  by_id uuid not null references public.profiles on delete cascade,
  at timestamptz not null default now(),
  photos jsonb not null default '[]',
  primary key (day, item_id)
);

alter table public.meal_items enable row level security;
alter table public.meal_ticks enable row level security;

create policy "read" on public.meal_items for select to authenticated using (public.is_member());
create policy "admin writes" on public.meal_items for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "own or admin" on public.meal_ticks for select to authenticated
  using (public.is_member() and (public.is_admin() or person_id = auth.uid() or by_id = auth.uid()));
create policy "tick own" on public.meal_ticks for insert to authenticated
  with check (by_id = auth.uid() and public.is_member() and (person_id = auth.uid() or public.is_admin()));
create policy "change own" on public.meal_ticks for update to authenticated
  using (public.is_member() and by_id = auth.uid()) with check (public.is_member() and by_id = auth.uid());
create policy "undo own" on public.meal_ticks for delete to authenticated
  using (public.is_member() and (by_id = auth.uid() or public.is_admin()));

-- Meal pictures live under meal/ in the proof bucket: admin adds them,
-- everyone on the team can see them.
create policy "meal pictures read" on storage.objects for select to authenticated
  using (bucket_id = 'proof' and (storage.foldername(name))[1] = 'meal' and public.is_member());
create policy "meal pictures add" on storage.objects for insert to authenticated
  with check (bucket_id = 'proof' and (storage.foldername(name))[1] = 'meal' and public.is_admin());
create policy "meal pictures change" on storage.objects for update to authenticated
  using (bucket_id = 'proof' and (storage.foldername(name))[1] = 'meal' and public.is_admin());
create policy "meal pictures remove" on storage.objects for delete to authenticated
  using (bucket_id = 'proof' and (storage.foldername(name))[1] = 'meal' and public.is_admin());

alter publication supabase_realtime add table public.meal_items, public.meal_ticks;
