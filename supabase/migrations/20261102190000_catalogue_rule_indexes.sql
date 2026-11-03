-- Indexes for the two catalogue foreign keys the performance advisor flagged.

create index if not exists curriculum_subject_rules_curriculum_id_idx
  on public.curriculum_subject_rules (curriculum_id);
create index if not exists curriculum_subject_rule_members_rule_curriculum_idx
  on public.curriculum_subject_rule_members (rule_id, curriculum_id);
