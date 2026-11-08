-- No more demo schools. Chom runs on real schools only.
--
-- Production's demo school (Styfe) and everyone in it was removed by hand on
-- 8 November 2026. This removes what made demo schools possible: the Styfe generator
-- and its calendar, the remover, the learner traits table, and the demo columns on
-- schools (is_demo and the fixed demo date).

drop function if exists private.demo_load_styfe(jsonb);
drop function if exists private.demo_load_styfe_roster(jsonb);
drop function if exists private.demo_load_styfe_calendar(uuid);
drop function if exists private.demo_remove_school(text);
drop table if exists private.demo_learner_traits;

-- A school's today is today in South Africa.
create or replace function public.school_today(p_school_id uuid)
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Africa/Johannesburg')::date
$$;

alter table public.schools drop column demo_today;
alter table public.schools drop column is_demo;
