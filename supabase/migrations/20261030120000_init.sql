-- Home Checklist: everything the app stores.
--
-- Maids see their own day; admins see everything. Photos live in the private
-- "proof" bucket under <person id>/<day>/.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- ------------------------------------------------------------------ people

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  role text not null default 'maid' check (role in ('maid', 'admin')),
  duties text not null default '',
  hours text not null default '',
  phone text not null default '',
  email text not null default '',
  day_off int check (day_off between 1 and 7),
  since date not null default current_date,
  removed_from date,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and removed_from is null
  );
$$;

-- A new sign-in gets a profile. The very first one becomes admin; after
-- that, admins create accounts through the manage-user function.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, name, role, duties, hours, phone, email)
  values (
    new.id,
    coalesce(nullif(meta->>'name', ''), split_part(coalesce(new.email, ''), '@', 1)),
    case
      when not exists (select 1 from public.profiles where role = 'admin') then 'admin'
      else coalesce(nullif(meta->>'role', ''), 'maid')
    end,
    coalesce(meta->>'duties', ''),
    coalesce(meta->>'hours', ''),
    coalesce(meta->>'phone', new.phone, ''),
    coalesce(new.email, '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- --------------------------------------------------------------- schedules

-- One version of a task. Editing ends the old version the day before and
-- adds a new one with the same series_id, so history never changes.
create table public.tasks (
  id text primary key,
  series_id text not null,
  owner_id uuid not null references public.profiles on delete cascade,
  valid_from date,
  valid_until date,
  start_min int not null check (start_min between 0 and 1440),
  end_min int not null check (end_min between 0 and 1440),
  title text not null,
  details text not null default '',
  kind text not null default 'tick' check (kind in ('tick', 'medicine', 'vitals', 'photo', 'rest')),
  dose text check (dose in ('morning', 'afternoon', 'evening')),
  days int[] not null default '{1,2,3,4,5,6,7}',
  extra_note text not null default '',
  extra_days int[] not null default '{}',
  shopping boolean not null default false,
  -- Share of the day's score; a missed task loses this much.
  weight int not null default 1 check (weight between 0 and 10)
);
create index tasks_owner on public.tasks (owner_id);

create table public.dose_owner (
  dose text primary key check (dose in ('morning', 'afternoon', 'evening')),
  person_id uuid references public.profiles on delete set null
);
insert into public.dose_owner (dose) values ('morning'), ('afternoon'), ('evening');

create table public.day_off_work (
  day date not null,
  person_id uuid not null references public.profiles on delete cascade,
  compensation text not null check (compensation in ('dayOff', 'extraPay')),
  note text not null default '',
  primary key (day, person_id)
);

-- After a night emergency the other maid covers the morning so the one who
-- was up can rest. Tasks starting before until_min move to covering_id.
create table public.night_cover (
  day date not null,
  resting_id uuid not null references public.profiles on delete cascade,
  covering_id uuid not null references public.profiles on delete cascade,
  until_min int not null default 720,
  note text not null default '',
  logged_by uuid references public.profiles on delete set null,
  logged_at timestamptz not null default now(),
  primary key (day, resting_id)
);

-- --------------------------------------------------------------- the day

create table public.ticks (
  day date not null,
  series_id text not null,
  person_id uuid not null references public.profiles on delete cascade,
  by_id uuid not null references public.profiles on delete cascade,
  at timestamptz not null default now(),
  status text not null default 'done' check (status in ('done', 'not_done')),
  reason text not null default '',
  vitals jsonb not null default '{}',
  photos jsonb not null default '[]',
  primary key (day, series_id)
);

create table public.dose_records (
  id uuid primary key default gen_random_uuid(),
  day date not null,
  dose text not null check (dose in ('morning', 'afternoon', 'evening')),
  parent text not null check (parent in ('mama', 'papa')),
  by_id uuid not null references public.profiles on delete cascade,
  at timestamptz not null default now(),
  photo jsonb
);
create index dose_records_day on public.dose_records (day);

create table public.notes (
  day date not null,
  series_id text not null,
  by_id uuid not null references public.profiles on delete cascade,
  text text not null,
  at timestamptz not null default now(),
  primary key (day, series_id)
);

create table public.reviews (
  day date not null,
  person_id uuid not null references public.profiles on delete cascade,
  status text not null check (status in ('confirmed', 'sentBack')),
  by_id uuid not null references public.profiles on delete cascade,
  at timestamptz not null default now(),
  note text not null default '',
  primary key (day, person_id)
);

create table public.shopping_items (
  id text primary key,
  day date not null,
  name text not null,
  qty text not null default '',
  bought boolean not null default false,
  created_by uuid references public.profiles on delete set null
);
create index shopping_items_day on public.shopping_items (day);

create table public.shopping_lists (
  day date primary key,
  handed_over timestamptz
);

-- Breaks and free time, logged by the maid with a start and end.
create table public.time_logs (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.profiles on delete cascade,
  day date not null,
  kind text not null check (kind in ('break', 'free')),
  started_at timestamptz not null,
  ended_at timestamptz
);
create index time_logs_day on public.time_logs (day);

-- ------------------------------------------------------------- emergencies

create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  phone text not null,
  sort int not null default 0
);
insert into public.emergency_contacts (label, phone, sort) values
  ('Ambulance', '998', 1),
  ('Police', '999', 2),
  ('Fire', '997', 3);

create table public.settings (
  key text primary key,
  value text not null default ''
);

-- -------------------------------------------------------------- reminders

create table public.push_subscriptions (
  endpoint text primary key,
  person_id uuid not null references public.profiles on delete cascade,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

-- Each reminder is sent once; the key says which.
create table public.reminders_sent (
  key text primary key,
  sent_at timestamptz not null default now()
);

-- ------------------------------------------------------------------- rules

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.dose_owner enable row level security;
alter table public.day_off_work enable row level security;
alter table public.night_cover enable row level security;
alter table public.ticks enable row level security;
alter table public.dose_records enable row level security;
alter table public.notes enable row level security;
alter table public.reviews enable row level security;
alter table public.shopping_items enable row level security;
alter table public.shopping_lists enable row level security;
alter table public.time_logs enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.settings enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.reminders_sent enable row level security;

-- Shared by everyone signed in: names, schedules, who gives which dose.
create policy "read" on public.profiles for select to authenticated using (true);
create policy "admin writes" on public.profiles for update to authenticated using (public.is_admin());

create policy "read" on public.tasks for select to authenticated using (true);
create policy "admin writes" on public.tasks for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "read" on public.dose_owner for select to authenticated using (true);
create policy "admin writes" on public.dose_owner for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "read" on public.day_off_work for select to authenticated using (true);
create policy "admin writes" on public.day_off_work for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "read" on public.night_cover for select to authenticated using (true);
create policy "anyone logs" on public.night_cover for insert to authenticated
  with check (logged_by = auth.uid());
create policy "logger changes" on public.night_cover for update to authenticated
  using (public.is_admin() or logged_by = auth.uid()) with check (logged_by = auth.uid());
create policy "admin or logger removes" on public.night_cover for delete to authenticated
  using (public.is_admin() or logged_by = auth.uid());

-- A maid works with her own ticks, and ones she covers after a night emergency.
create or replace function public.covers(person uuid, d date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.night_cover
    where day = d and resting_id = person and covering_id = auth.uid()
  );
$$;

create policy "own or admin" on public.ticks for select to authenticated
  using (public.is_admin() or person_id = auth.uid() or by_id = auth.uid() or public.covers(person_id, day));
create policy "tick own" on public.ticks for insert to authenticated
  with check (by_id = auth.uid() and (person_id = auth.uid() or public.covers(person_id, day) or public.is_admin()));
create policy "change own" on public.ticks for update to authenticated
  using (by_id = auth.uid() or public.is_admin()) with check (by_id = auth.uid());
create policy "undo own" on public.ticks for delete to authenticated
  using (by_id = auth.uid() or public.is_admin());

-- Everyone sees every dose, so no one gives it twice.
create policy "read" on public.dose_records for select to authenticated using (true);
create policy "give" on public.dose_records for insert to authenticated with check (by_id = auth.uid());
create policy "resend own" on public.dose_records for update to authenticated
  using (by_id = auth.uid()) with check (by_id = auth.uid());
create policy "undo own" on public.dose_records for delete to authenticated
  using (by_id = auth.uid() or public.is_admin());

create policy "own or admin" on public.notes for select to authenticated
  using (public.is_admin() or by_id = auth.uid());
create policy "write own" on public.notes for all to authenticated
  using (by_id = auth.uid()) with check (by_id = auth.uid());

create policy "own or admin" on public.reviews for select to authenticated
  using (public.is_admin() or person_id = auth.uid());
create policy "admin writes" on public.reviews for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "read" on public.shopping_items for select to authenticated using (true);
create policy "write" on public.shopping_items for all to authenticated using (true) with check (true);
create policy "read" on public.shopping_lists for select to authenticated using (true);
create policy "write" on public.shopping_lists for all to authenticated using (true) with check (true);

create policy "own or admin" on public.time_logs for select to authenticated
  using (public.is_admin() or person_id = auth.uid());
create policy "write own" on public.time_logs for all to authenticated
  using (person_id = auth.uid()) with check (person_id = auth.uid());

create policy "read" on public.emergency_contacts for select to authenticated using (true);
create policy "admin writes" on public.emergency_contacts for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "read" on public.settings for select to authenticated using (true);
create policy "admin writes" on public.settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "own" on public.push_subscriptions for all to authenticated
  using (person_id = auth.uid()) with check (person_id = auth.uid());

-- reminders_sent has no policies: only the reminder function touches it.

-- ------------------------------------------------------------------ photos

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('proof', 'proof', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'proof' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "see own or admin" on storage.objects for select to authenticated
  using (bucket_id = 'proof' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
create policy "remove own" on storage.objects for delete to authenticated
  using (bucket_id = 'proof' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------- realtime

alter publication supabase_realtime add table
  public.profiles, public.tasks, public.dose_owner, public.day_off_work, public.night_cover,
  public.ticks, public.dose_records, public.notes, public.reviews, public.shopping_items,
  public.shopping_lists, public.time_logs, public.emergency_contacts, public.settings;

-- ------------------------------------------------------- reminder timer

-- A random secret the timer sends, so only it can trigger reminders.
select vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'reminder_cron_secret')
where not exists (select 1 from vault.secrets where name = 'reminder_cron_secret');

create or replace function public.check_cron_secret(secret text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from vault.decrypted_secrets
    where name = 'reminder_cron_secret' and decrypted_secret = secret
  );
$$;
revoke execute on function public.check_cron_secret(text) from public, anon, authenticated;

select cron.schedule(
  'send-reminders',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://vntfodgrexvrivtmvumx.supabase.co/functions/v1/send-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'reminder_cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
