import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';

test('phase-one migration, account isolation, membership authority and invitation lifecycle', async () => {
  const db = new PGlite();
  try {
    await db.exec(`create role anon; create role authenticated;
      create schema auth;
      create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}');
      create function auth.uid() returns uuid language sql stable as
        $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      grant usage on schema public,auth to anon,authenticated;
      grant execute on function auth.uid() to anon,authenticated;
      alter default privileges in schema public grant execute on functions to anon,authenticated;`);
    await db.exec(await readFile(new URL('../../supabase/migrations/202611170001_accounts_groups.sql', import.meta.url), 'utf8'));
    await db.exec(await readFile(new URL('../../supabase/migrations/202611170002_explicit_function_permissions.sql', import.meta.url), 'utf8'));
    const ids = Array.from({length: 23}, (_,i) => `00000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`);
    for (const id of ids) await db.query('insert into auth.users(id) values($1)',[id]);
    const asUser = async (index) => {
      await db.exec('reset role');
      await db.query("select set_config('request.jwt.claim.sub',$1,false)",[ids[index]]);
      await db.exec('set role authenticated');
    };
    const rpc = async (sql,args=[]) => (await db.query(sql,args)).rows[0].result;
    const goal = {title:'Share meals',deed_ids:['quran-14'],targets:{meals:20},per_member:false,start:'2026-11-17',end:'2026-11-30'};
    await asUser(0);
    const profile = await rpc("select to_jsonb(public.ensure_profile('Owner')) as result");
    assert.equal(profile.id,ids[0]);
    const request = '10000000-0000-4000-8000-000000000001';
    const create = () => rpc('select public.create_group($1,$2,$3,$4) as result',[request,'Test circle','Private circle',goal]);
    const group = await create();
    assert.equal(await create(),group,'retry does not create a second group');
    await assert.rejects(db.query('update public.groups set owner_id=$1 where id=$2',[ids[1],group]));
    await assert.rejects(db.query('insert into public.group_members values($1,$2,$3,now())',[group,ids[1],'owner']));
    await assert.rejects(rpc('select public.create_group($1,$2,$3,$4) as result',[
      '10000000-0000-4000-8000-000000000002','Invalid goal','',{...goal,deed_ids:['invented']} ]));
    await assert.rejects(rpc('select public.create_group($1,$2,$3,$4) as result',[
      '10000000-0000-4000-8000-000000000003','Invalid goal','',{...goal,per_member:null} ]));
    const invitation = await rpc('select public.create_group_invite($1) as result',[group]);
    assert.match(invitation.token,/^[a-f0-9]{32}$/);
    await assert.rejects(db.query('select * from private.group_invites'));
    await asUser(1);
    assert.equal((await db.query('select * from public.groups')).rows.length,0);
    assert.equal((await db.query('select * from public.profiles')).rows.length,0);
    await assert.rejects(rpc('select public.create_group_invite($1) as result',[group]));
    const preview = await rpc('select public.preview_group_invite($1) as result',[invitation.token]);
    assert.equal(preview.name,'Test circle');
    assert.equal(preview.members,undefined,'preview does not disclose member list');
    assert.equal((await db.query('select * from public.groups')).rows.length,0,'preview never joins');
    const joined = await rpc('select public.accept_group_invite($1) as result',[invitation.token]);
    assert.equal(joined.group_id,group);
    assert.equal((await rpc('select public.accept_group_invite($1) as result',[invitation.token])).already_member,true);
    assert.equal((await db.query('select * from public.group_members')).rows.length,2);
    assert.equal((await db.query('select * from public.profiles')).rows.length,2);
    const memberInvite = await rpc('select public.create_group_invite($1) as result',[group]);
    await assert.rejects(rpc('select public.revoke_group_invite($1) as result',[invitation.id]));
    await assert.rejects(rpc('select public.remove_group_member($1,$2) as result',[group,ids[0]]));
    await asUser(0);
    await rpc('select public.revoke_group_invite($1) as result',[memberInvite.id]);
    await asUser(2);
    assert.ok((await rpc('select public.accept_group_invite($1) as result',[memberInvite.token])).error);
    // Fill to the cap. This validates cap logic; real concurrent locks also need hosted tests.
    for (let i=2;i<20;i++) {
      await asUser(i);
      assert.equal((await rpc('select public.accept_group_invite($1) as result',[invitation.token])).group_id,group);
    }
    await asUser(20);
    assert.match((await rpc('select public.accept_group_invite($1) as result',[invitation.token])).error,/full/);
    await asUser(1);
    const departedInvite = await rpc('select public.create_group_invite($1) as result',[group]);
    await rpc('select public.remove_group_member($1,$2) as result',[group,ids[1]]);
    assert.equal((await db.query('select * from public.groups')).rows.length,0,'leaving removes access');
    await asUser(21);
    assert.ok((await rpc('select public.preview_group_invite($1) as result',[departedInvite.token])).error);
    for (let i=0;i<12;i++) await rpc('select public.preview_group_invite($1) as result',['not-a-token']);
    assert.match((await rpc('select public.preview_group_invite($1) as result',[invitation.token])).error,/Too many/);
    await db.exec('reset role; set role anon');
    await assert.rejects(rpc('select public.preview_group_invite($1) as result',[invitation.token]));
    await assert.rejects(db.query('select * from public.groups'));
  } finally { await db.close(); }
});
