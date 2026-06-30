-- Grant PostgREST API roles access to public tables (required for local + RLS tests).
-- RLS policies still enforce row-level rules; these are table-level privileges.

grant usage on schema public to postgres, anon, authenticated, service_role;

grant all on all tables in schema public to postgres, service_role;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;

grant all on all routines in schema public to postgres, service_role;
grant execute on all routines in schema public to anon, authenticated;

grant all on all sequences in schema public to postgres, service_role;
grant usage, select on all sequences in schema public to anon, authenticated;

alter default privileges for role postgres in schema public
  grant all on tables to postgres, service_role;
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
alter default privileges for role postgres in schema public
  grant all on routines to postgres, service_role;
alter default privileges for role postgres in schema public
  grant execute on routines to anon, authenticated;
alter default privileges for role postgres in schema public
  grant all on sequences to postgres, service_role;
alter default privileges for role postgres in schema public
  grant usage, select on sequences to anon, authenticated;
