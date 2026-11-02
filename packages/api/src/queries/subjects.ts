import type { ChomClient } from '../client';
import type { TableRow } from '../database.types';

export type ClassSubject = TableRow<'class_subjects'>;
export type Subject = TableRow<'subjects'>;
export type Assignment = TableRow<'assignments'>;
export type Task = TableRow<'tasks'>;
export type LearningMaterial = TableRow<'learning_materials'>;

/** Class offerings the signed-in person may access (student, teacher, parent, admin). */
export async function listAccessibleClassSubjects(client: ChomClient) {
  return client
    .from('class_subjects')
    .select(
      `
      *,
      subject:subjects (*),
      class:classes (*)
    `,
    )
    .order('created_at');
}

export async function listTasksForClassSubject(
  client: ChomClient,
  classSubjectId: string,
) {
  return client
    .from('tasks')
    .select('*')
    .eq('class_subject_id', classSubjectId)
    .order('due_on', { ascending: true, nullsFirst: false });
}

export async function listAssignmentsForClassSubject(
  client: ChomClient,
  classSubjectId: string,
) {
  return client
    .from('assignments')
    .select('*')
    .eq('class_subject_id', classSubjectId)
    .order('due_on', { ascending: true, nullsFirst: false });
}

export async function listLearningMaterialsForClassSubject(
  client: ChomClient,
  classSubjectId: string,
) {
  return client
    .from('learning_materials')
    .select('*')
    .eq('class_subject_id', classSubjectId)
    .order('created_at', { ascending: false });
}
