export { createChomClient, type ChomClient, type ChomClientOptions } from './client';
export { readPublicSupabaseEnv, type ChomPublicEnv } from './env';
export type {
  AppRole,
  AssignmentStatus,
  Database,
  Json,
  TableName,
  TableRow,
} from './database.types';
export {
  listMyMemberships,
  listMySchools,
  type School,
  type SchoolMembership,
} from './queries/schools';
export {
  listAccessibleClassSubjects,
  listAssignmentsForClassSubject,
  listLearningMaterialsForClassSubject,
  listTasksForClassSubject,
  type Assignment,
  type ClassSubject,
  type LearningMaterial,
  type Subject,
  type Task,
} from './queries/subjects';
