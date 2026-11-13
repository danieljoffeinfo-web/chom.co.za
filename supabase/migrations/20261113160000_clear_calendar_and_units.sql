-- Clear every school's calendar and the curriculum units ("This year's units").
--
-- The units loaded in 20261108090000 (455 CAPS units across Grades 10-12) and the way
-- they were laid over term dates are being redesigned, so both go:
--   * each school's terms, half-terms and holidays, exam windows and content-end dates
--   * every school's unit schedule
--   * all curriculum units (reference data)
--
-- The tables, their access rules and the scheduling functions stay, empty, for the
-- new design. Public holidays stay: they're national dates, not a school's calendar.
-- With no units, learners' subject pages simply leave out "This year's units".

delete from public.unit_schedules;
delete from public.grade_content_end_dates;
delete from public.exam_windows;
delete from public.school_calendar_breaks;
delete from public.school_terms;
delete from public.curriculum_units;
