-- Phase 1: real accounts, private groups and explicit invitations.
-- Apply once to an existing Supabase project. No storage buckets or paid services.
begin;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
  created_at timestamptz not null default now()
);
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  request_id uuid not null,
  name text not null check (char_length(btrim(name)) between 3 and 60),
  description text not null default '' check (char_length(description) <= 250),
  goal jsonb not null,
  closed boolean not null default false,
  created_at timestamptz not null default now(),
  unique(owner_id, request_id)
);
create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key(group_id, user_id)
);
create index group_members_user on public.group_members(user_id, group_id);
create table private.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  token_hash text not null unique,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  revoked_at timestamptz
);
create index invites_group_created on private.group_invites(group_id, created_at);
create table private.invite_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  window_at timestamptz not null,
  attempts integer not null default 1,
  primary key(user_id, window_at)
);

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table private.group_invites enable row level security;
alter table private.invite_attempts enable row level security;
revoke all on public.profiles, public.groups, public.group_members from anon, authenticated;
revoke all on all tables in schema private from anon, authenticated;
grant select on public.profiles, public.groups, public.group_members to authenticated;

create function private.is_member(p_group uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.group_members m
    where m.group_id=p_group and m.user_id=auth.uid());
$$;
create function private.can_view_profile(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_user=auth.uid() or exists (
    select 1 from public.group_members mine join public.group_members theirs
      on mine.group_id=theirs.group_id
    where mine.user_id=auth.uid() and theirs.user_id=p_user);
$$;
revoke all on function private.is_member(uuid), private.can_view_profile(uuid) from public;
grant execute on function private.is_member(uuid), private.can_view_profile(uuid) to authenticated;
create policy profile_visibility on public.profiles for select to authenticated
  using(private.can_view_profile(id));
create policy group_visibility on public.groups for select to authenticated
  using(private.is_member(id));
create policy membership_visibility on public.group_members for select to authenticated
  using(private.is_member(group_id));

create function public.ensure_profile(p_display_name text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare result public.profiles; chosen text;
begin
  if auth.uid() is null then raise exception 'Sign in first.' using errcode='42501'; end if;
  chosen := left(btrim(coalesce(nullif(p_display_name,''),
    (select coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name')
      from auth.users where id=auth.uid()), 'Member')),60);
  if chosen='' then chosen:='Member'; end if;
  insert into public.profiles(id,display_name) values(auth.uid(),chosen)
    on conflict(id) do nothing;
  if p_display_name is not null then
    update public.profiles set display_name=chosen where id=auth.uid();
  end if;
  select * into result from public.profiles where id=auth.uid();
  return to_jsonb(result);
end $$;

create function private.validate_goal(p_goal jsonb) returns void
language plpgsql set search_path = '' as $$
declare deed text; metric text; amount numeric; start_day date; end_day date;
begin
  if jsonb_typeof(p_goal) is distinct from 'object' or jsonb_typeof(p_goal->'deed_ids') is distinct from 'array'
    or jsonb_array_length(p_goal->'deed_ids') not between 1 and 50
    or jsonb_typeof(p_goal->'targets') is distinct from 'object'
    or length(btrim(coalesce(p_goal->>'title',''))) not between 1 and 80
    or jsonb_typeof(p_goal->'per_member') is distinct from 'boolean'
    or octet_length(p_goal::text)>16384 then
    raise exception 'Invalid group goal.' using errcode='22023';
  end if;
  for deed in select jsonb_array_elements_text(p_goal->'deed_ids') loop
    if deed !~ '^quran-(0[1-9]|[1-4][0-9]|50)$' then
      raise exception 'Unknown catalog deed.' using errcode='22023';
    end if;
  end loop;
  if not exists(select 1 from jsonb_each(p_goal->'targets')) then
    raise exception 'Choose at least one goal metric.' using errcode='22023';
  end if;
  for metric, amount in select key, (value::text)::numeric from jsonb_each(p_goal->'targets') loop
    if metric not in ('completions','days','donation','minutes','meals','people')
      or amount<=0 or amount>1000000000 or amount::text in ('NaN','Infinity','-Infinity')
      or (metric in ('completions','days','meals','people') and amount<>trunc(amount)) then
      raise exception 'Invalid goal target.' using errcode='22023';
    end if;
  end loop;
  start_day := (p_goal->>'start')::date; end_day := (p_goal->>'end')::date;
  if start_day is null or end_day is null or end_day<start_day
    or end_day>start_day+366 then
    raise exception 'Invalid goal dates.' using errcode='22023';
  end if;
end $$;

create function public.create_group(p_request_id uuid, p_name text, p_description text, p_goal jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare group_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first.' using errcode='42501'; end if;
  perform public.ensure_profile();
  perform pg_advisory_xact_lock(hashtextextended('create-group:'||auth.uid()::text,0));
  select id into group_id from public.groups where owner_id=auth.uid() and request_id=p_request_id;
  if group_id is not null then return group_id; end if;
  if (select count(*) from public.groups where owner_id=auth.uid()
    and created_at>now()-interval '1 day')>=10 then
    raise exception 'Group creation limit reached. Try tomorrow.' using errcode='P0001';
  end if;
  perform private.validate_goal(p_goal);
  insert into public.groups(owner_id,request_id,name,description,goal)
    values(auth.uid(),p_request_id,btrim(p_name),btrim(coalesce(p_description,'')),p_goal)
    returning id into group_id;
  insert into public.group_members(group_id,user_id,role) values(group_id,auth.uid(),'owner');
  return group_id;
end $$;

create function public.create_group_invite(p_group_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare token text; invite_id uuid; expiry timestamptz;
begin
  if auth.uid() is null or not private.is_member(p_group_id) then
    raise exception 'Only group members can invite.' using errcode='42501';
  end if;
  perform 1 from public.groups where id=p_group_id and not closed for update;
  if not found then raise exception 'This group is closed.'; end if;
  if (select count(*) from private.group_invites where created_by=auth.uid()
    and created_at>now()-interval '1 hour')>=10 then
    raise exception 'Invitation limit reached. Try later.';
  end if;
  token:=replace(gen_random_uuid()::text,'-','');
  insert into private.group_invites(group_id,token_hash,created_by)
    values(p_group_id,encode(sha256(convert_to(token,'UTF8')),'hex'),auth.uid())
    returning id,expires_at into invite_id,expiry;
  return jsonb_build_object('id',invite_id,'token',token,'expires_at',expiry);
end $$;

create function private.consume_invite_attempt() returns boolean
language plpgsql security definer set search_path = '' as $$
declare total integer;
begin
  if auth.uid() is null then return false; end if;
  insert into private.invite_attempts(user_id,window_at)
    values(auth.uid(),date_trunc('minute',now()))
    on conflict(user_id,window_at) do update set attempts=private.invite_attempts.attempts+1
    returning attempts into total;
  -- Bound retained rate-limit rows, without logging tokens or narratives.
  delete from private.invite_attempts where user_id=auth.uid() and window_at<now()-interval '1 day';
  return total<=12;
end $$;

create function public.preview_group_invite(p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare invitation private.group_invites; circle public.groups; member_count integer;
begin
  if auth.uid() is null then return jsonb_build_object('error','Sign in to view an invitation.'); end if;
  if not private.consume_invite_attempt() then return jsonb_build_object('error','Too many attempts. Try again in a minute.'); end if;
  if p_token is null or p_token !~ '^[a-f0-9]{32}$' then return jsonb_build_object('error','Invalid invitation.'); end if;
  select * into invitation from private.group_invites
    where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
  if not found or invitation.revoked_at is not null or invitation.expires_at<=now() then
    return jsonb_build_object('error','This invitation is invalid or has expired.');
  end if;
  select * into circle from public.groups where id=invitation.group_id;
  if not found or circle.closed then return jsonb_build_object('error','This group is unavailable.'); end if;
  select count(*) into member_count from public.group_members where group_id=circle.id;
  return jsonb_build_object('group_id',circle.id,'name',circle.name,
    'description',circle.description,'member_count',member_count,'expires_at',invitation.expires_at,
    'already_member',private.is_member(circle.id),'full',member_count>=20);
end $$;

create function public.accept_group_invite(p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare invitation private.group_invites; circle public.groups;
begin
  if auth.uid() is null then return jsonb_build_object('error','Sign in first.'); end if;
  if not private.consume_invite_attempt() then return jsonb_build_object('error','Too many attempts. Try again in a minute.'); end if;
  if p_token is null or p_token !~ '^[a-f0-9]{32}$' then return jsonb_build_object('error','Invalid invitation.'); end if;
  select * into invitation from private.group_invites where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
  if not found then return jsonb_build_object('error','Invalid invitation.'); end if;
  -- All joins serialize on this row, so concurrent joins cannot exceed 20.
  select * into circle from public.groups where id=invitation.group_id for update;
  select * into invitation from private.group_invites where id=invitation.id for update;
  if circle.id is null or circle.closed or invitation.revoked_at is not null or invitation.expires_at<=now() then
    return jsonb_build_object('error','This invitation is invalid or has expired.');
  end if;
  if private.is_member(circle.id) then return jsonb_build_object('group_id',circle.id,'already_member',true); end if;
  if (select count(*) from public.group_members where group_id=circle.id)>=20 then
    return jsonb_build_object('error','This group is full.');
  end if;
  perform public.ensure_profile();
  insert into public.group_members(group_id,user_id,role) values(circle.id,auth.uid(),'member');
  return jsonb_build_object('group_id',circle.id,'already_member',false);
end $$;

create function public.list_group_invites(p_group_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_member(p_group_id) then raise exception 'Not a member.' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'expires_at',i.expires_at,
    'revoked',i.revoked_at is not null,'mine',i.created_by=auth.uid()) order by i.created_at desc)
    from (select * from private.group_invites where group_id=p_group_id
      and expires_at>now() order by created_at desc limit 20) i), '[]'::jsonb);
end $$;
create function public.revoke_group_invite(p_invite_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update private.group_invites i set revoked_at=now()
    where i.id=p_invite_id and (i.created_by=auth.uid() or exists (
      select 1 from public.groups g where g.id=i.group_id and g.owner_id=auth.uid()));
  if not found then raise exception 'Cannot revoke this invitation.' using errcode='42501'; end if;
end $$;
create function public.remove_group_member(p_group_id uuid, p_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare owner_user uuid;
begin
  select owner_id into owner_user from public.groups where id=p_group_id for update;
  if auth.uid() is null or (auth.uid()<>owner_user and auth.uid()<>p_user_id) then
    raise exception 'Cannot remove this member.' using errcode='42501';
  end if;
  if p_user_id=owner_user then raise exception 'The owner must remain in this group.'; end if;
  delete from public.group_members where group_id=p_group_id and user_id=p_user_id;
  -- A departed member must not keep inviting others with previously issued tokens.
  update private.group_invites set revoked_at=now() where group_id=p_group_id and created_by=p_user_id;
end $$;

-- Default function EXECUTE is PUBLIC in PostgreSQL; explicitly narrow it.
revoke all on function private.validate_goal(jsonb), private.consume_invite_attempt() from public;
revoke all on function public.ensure_profile(text), public.create_group(uuid,text,text,jsonb),
  public.create_group_invite(uuid), public.preview_group_invite(text), public.accept_group_invite(text),
  public.list_group_invites(uuid), public.revoke_group_invite(uuid), public.remove_group_member(uuid,uuid) from public;
grant execute on function public.ensure_profile(text), public.create_group(uuid,text,text,jsonb),
  public.create_group_invite(uuid), public.preview_group_invite(text), public.accept_group_invite(text),
  public.list_group_invites(uuid), public.revoke_group_invite(uuid), public.remove_group_member(uuid,uuid) to authenticated;
create function public.backend_status() returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('schema_version',1,'phase','accounts_groups',
    'contributions_enabled',false,'private_deeds_synced',false);
$$;
revoke all on function public.backend_status() from public;
grant execute on function public.backend_status() to anon, authenticated;
commit;
