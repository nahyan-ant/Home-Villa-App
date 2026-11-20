-- Removal is one transaction; the caller is an authenticated edge function
-- using the service role. No browser user may invoke this RPC directly.
create or replace function public.remove_team_member(target_id uuid, actor_id uuid)
returns date
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.profiles%rowtype;
  removal_day date := (now() at time zone 'Asia/Dubai')::date;
begin
  perform pg_catalog.pg_advisory_xact_lock(61280411);
  if target_id = actor_id then raise exception 'You cannot remove yourself'; end if;
  if not exists(select 1 from public.profiles where id = actor_id and role = 'admin' and removed_from is null) then
    raise exception 'Admins only';
  end if;
  select * into target from public.profiles where id = target_id for update;
  if not found then raise exception 'Team member not found'; end if;
  if target.role = 'admin' and target.removed_from is null
    and (select count(*) from public.profiles where role = 'admin' and removed_from is null) <= 1 then
    raise exception 'There must always be at least one admin';
  end if;
  if target.role not in ('maid', 'admin') then raise exception 'Only approved members can be removed'; end if;
  removal_day := coalesce(target.removed_from, removal_day);
  update public.profiles set removed_from = removal_day where id = target_id;
  delete from public.tasks where owner_id = target_id and valid_from >= removal_day;
  update public.tasks set valid_until = removal_day - 1
    where owner_id = target_id and (valid_until is null or valid_until >= removal_day);
  update public.dose_owner set person_id = null where person_id = target_id;
  delete from public.push_subscriptions where person_id = target_id;
  delete from public.night_cover where day >= removal_day
    and (resting_id = target_id or covering_id = target_id);
  return removal_day;
end;
$$;
revoke all on function public.remove_team_member(uuid, uuid) from public, anon, authenticated;
grant execute on function public.remove_team_member(uuid, uuid) to service_role;

-- Removed members cannot read cached photo links from the server.
drop policy "see own or admin" on storage.objects;
create policy "see own or admin" on storage.objects for select to authenticated
  using (bucket_id = 'proof' and public.is_member()
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
drop policy "remove own" on storage.objects;
create policy "remove own" on storage.objects for delete to authenticated
  using (bucket_id = 'proof' and (storage.foldername(name))[1] = auth.uid()::text and public.is_member());

-- Old JWTs must lose read/write access immediately after removal too.
alter policy "own or admin" on public.ticks
  using (public.is_member() and (public.is_admin() or person_id = auth.uid() or by_id = auth.uid() or public.covers(person_id, day)));
alter policy "change own" on public.ticks
  using (public.is_member() and (by_id = auth.uid() or public.is_admin()))
  with check (public.is_member() and by_id = auth.uid());
alter policy "undo own" on public.ticks
  using (public.is_member() and (by_id = auth.uid() or public.is_admin()));
alter policy "resend own" on public.dose_records
  using (public.is_member() and by_id = auth.uid())
  with check (public.is_member() and by_id = auth.uid());
alter policy "undo own" on public.dose_records
  using (public.is_member() and (by_id = auth.uid() or public.is_admin()));
alter policy "own or admin" on public.notes
  using (public.is_member() and (public.is_admin() or by_id = auth.uid()));
alter policy "write own" on public.notes
  using (public.is_member() and by_id = auth.uid())
  with check (public.is_member() and by_id = auth.uid());
alter policy "own or admin" on public.reviews
  using (public.is_member() and (public.is_admin() or person_id = auth.uid()));
alter policy "own or admin" on public.time_logs
  using (public.is_member() and (public.is_admin() or person_id = auth.uid()));
alter policy "write own" on public.time_logs
  using (public.is_member() and person_id = auth.uid())
  with check (public.is_member() and person_id = auth.uid());
alter policy "own" on public.push_subscriptions
  using (public.is_member() and person_id = auth.uid())
  with check (public.is_member() and person_id = auth.uid());
alter policy "logger changes" on public.night_cover
  using (public.is_member() and (public.is_admin() or logged_by = auth.uid()))
  with check (public.is_member() and (public.is_admin() or logged_by = auth.uid()));
alter policy "admin or logger removes" on public.night_cover
  using (public.is_member() and (public.is_admin() or logged_by = auth.uid()));
alter policy "admin writes" on public.profiles
  using (public.is_admin()) with check (public.is_admin());

-- The trigger is internal. RLS helpers remain available to signed-in users.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.is_member() from public, anon;
revoke execute on function public.covers(uuid, date) from public, anon;
grant execute on function public.is_admin(), public.is_member(), public.covers(uuid,date) to authenticated;
;
