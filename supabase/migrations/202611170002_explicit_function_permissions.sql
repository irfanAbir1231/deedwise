-- Supabase may grant EXECUTE directly to anon through its default privileges.
-- Revoke those direct grants, not just PostgreSQL's inherited PUBLIC grants.
-- Existing authentication checks already reject anonymous access to group data.
begin;
revoke all on function public.ensure_profile(text),
  public.create_group(uuid,text,text,jsonb), public.create_group_invite(uuid),
  public.preview_group_invite(text), public.accept_group_invite(text),
  public.list_group_invites(uuid), public.revoke_group_invite(uuid),
  public.remove_group_member(uuid,uuid) from public, anon, authenticated;
grant execute on function public.ensure_profile(text),
  public.create_group(uuid,text,text,jsonb), public.create_group_invite(uuid),
  public.preview_group_invite(text), public.accept_group_invite(text),
  public.list_group_invites(uuid), public.revoke_group_invite(uuid),
  public.remove_group_member(uuid,uuid) to authenticated;
revoke all on function private.validate_goal(jsonb), private.consume_invite_attempt()
  from public, anon, authenticated;
revoke all on function private.is_member(uuid), private.can_view_profile(uuid) from public, anon;
grant execute on function private.is_member(uuid), private.can_view_profile(uuid) to authenticated;
create or replace function public.backend_status() returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('schema_version',1,'security_revision',2,'phase','accounts_groups',
    'contributions_enabled',false,'private_deeds_synced',false);
$$;
revoke all on function public.backend_status() from public, anon, authenticated;
grant execute on function public.backend_status() to anon, authenticated;
commit;
