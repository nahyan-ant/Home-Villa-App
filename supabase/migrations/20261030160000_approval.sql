-- People may sign up themselves, but stay "pending" with no access until an
-- admin approves them. Accounts an admin creates are approved at once.

alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('maid', 'admin', 'pending'));

create or replace function public.is_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('maid', 'admin') and removed_from is null
  );
$$;

-- app_metadata can only be set with the service key, so "invited" proves an
-- admin made the account through manage-user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  invited boolean := coalesce(new.raw_app_meta_data->>'invited', '') = 'true';
begin
  insert into public.profiles (id, name, role, duties, hours, phone, email)
  values (
    new.id,
    coalesce(nullif(meta->>'name', ''), split_part(coalesce(new.email, ''), '@', 1)),
    case
      when not exists (select 1 from public.profiles where role = 'admin') then 'admin'
      when invited then case when meta->>'role' = 'admin' then 'admin' else 'maid' end
      else 'pending'
    end,
    coalesce(meta->>'duties', ''),
    coalesce(meta->>'hours', ''),
    coalesce(meta->>'phone', new.phone, ''),
    coalesce(new.email, '')
  );
  return new;
end;
$$;

-- Everything shared is for members only; a pending person sees just herself.
drop policy "read" on public.profiles;
create policy "read" on public.profiles for select to authenticated
  using (public.is_member() or id = auth.uid());

drop policy "read" on public.tasks;
create policy "read" on public.tasks for select to authenticated using (public.is_member());
drop policy "read" on public.dose_owner;
create policy "read" on public.dose_owner for select to authenticated using (public.is_member());
drop policy "read" on public.day_off_work;
create policy "read" on public.day_off_work for select to authenticated using (public.is_member());
drop policy "read" on public.night_cover;
create policy "read" on public.night_cover for select to authenticated using (public.is_member());
drop policy "anyone logs" on public.night_cover;
create policy "anyone logs" on public.night_cover for insert to authenticated
  with check (logged_by = auth.uid() and public.is_member());

drop policy "tick own" on public.ticks;
create policy "tick own" on public.ticks for insert to authenticated
  with check (
    by_id = auth.uid() and public.is_member()
    and (person_id = auth.uid() or public.covers(person_id, day) or public.is_admin())
  );

drop policy "read" on public.dose_records;
create policy "read" on public.dose_records for select to authenticated using (public.is_member());
drop policy "give" on public.dose_records;
create policy "give" on public.dose_records for insert to authenticated
  with check (by_id = auth.uid() and public.is_member());

drop policy "write own" on public.notes;
create policy "write own" on public.notes for all to authenticated
  using (by_id = auth.uid()) with check (by_id = auth.uid() and public.is_member());

drop policy "read" on public.shopping_items;
drop policy "write" on public.shopping_items;
create policy "read" on public.shopping_items for select to authenticated using (public.is_member());
create policy "write" on public.shopping_items for all to authenticated
  using (public.is_member()) with check (public.is_member());
drop policy "read" on public.shopping_lists;
drop policy "write" on public.shopping_lists;
create policy "read" on public.shopping_lists for select to authenticated using (public.is_member());
create policy "write" on public.shopping_lists for all to authenticated
  using (public.is_member()) with check (public.is_member());

drop policy "write own" on public.time_logs;
create policy "write own" on public.time_logs for all to authenticated
  using (person_id = auth.uid()) with check (person_id = auth.uid() and public.is_member());

drop policy "read" on public.emergency_contacts;
create policy "read" on public.emergency_contacts for select to authenticated using (public.is_member());
drop policy "read" on public.settings;
create policy "read" on public.settings for select to authenticated using (public.is_member());

drop policy "own" on public.push_subscriptions;
create policy "own" on public.push_subscriptions for all to authenticated
  using (person_id = auth.uid()) with check (person_id = auth.uid() and public.is_member());

drop policy "upload own" on storage.objects;
create policy "upload own" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'proof' and (storage.foldername(name))[1] = auth.uid()::text and public.is_member()
  );
