/**
 * Hand-written Database types matching supabase/migrations.
 * Replace with `supabase gen types typescript` once a linked project exists.
 */

export type AppRole = 'student' | 'teacher' | 'parent' | 'school_admin';
export type AssignmentStatus = 'draft' | 'published' | 'closed';

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  public: {
    Tables: {
      schools: {
        Row: {
          id: string;
          name: string;
          ednana_id: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          ednana_id?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          ednana_id?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      profiles: {
        Row: {
          id: string;
          full_name: string;
          preferred_name: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          full_name: string;
          preferred_name?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          full_name?: string;
          preferred_name?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      school_memberships: {
        Row: {
          id: string;
          school_id: string;
          person_id: string;
          role: AppRole;
          ednana_id: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          person_id: string;
          role: AppRole;
          ednana_id?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          person_id?: string;
          role?: AppRole;
          ednana_id?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      classes: {
        Row: {
          id: string;
          school_id: string;
          name: string;
          grade: string | null;
          ednana_id: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          name: string;
          grade?: string | null;
          ednana_id?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          name?: string;
          grade?: string | null;
          ednana_id?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      subjects: {
        Row: {
          id: string;
          school_id: string;
          name: string;
          short_code: string | null;
          color: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          name: string;
          short_code?: string | null;
          color?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          name?: string;
          short_code?: string | null;
          color?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      class_subjects: {
        Row: {
          id: string;
          school_id: string;
          class_id: string;
          subject_id: string;
          teacher_id: string | null;
          topic: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          class_id: string;
          subject_id: string;
          teacher_id?: string | null;
          topic?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          class_id?: string;
          subject_id?: string;
          teacher_id?: string | null;
          topic?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      enrolments: {
        Row: {
          id: string;
          school_id: string;
          class_id: string;
          student_id: string;
          ednana_id: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          class_id: string;
          student_id: string;
          ednana_id?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          class_id?: string;
          student_id?: string;
          ednana_id?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      guardianships: {
        Row: {
          id: string;
          school_id: string;
          parent_id: string;
          learner_id: string;
          relationship: string | null;
          ednana_id: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          parent_id: string;
          learner_id: string;
          relationship?: string | null;
          ednana_id?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          parent_id?: string;
          learner_id?: string;
          relationship?: string | null;
          ednana_id?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      tasks: {
        Row: {
          id: string;
          school_id: string;
          class_subject_id: string;
          title: string;
          body: string | null;
          due_on: string | null;
          created_by: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          class_subject_id: string;
          title: string;
          body?: string | null;
          due_on?: string | null;
          created_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          class_subject_id?: string;
          title?: string;
          body?: string | null;
          due_on?: string | null;
          created_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      task_completions: {
        Row: {
          task_id: string;
          student_id: string;
          school_id: string;
          done_at: string;
        };
        Insert: {
          task_id: string;
          student_id: string;
          school_id: string;
          done_at?: string;
        };
        Update: {
          task_id?: string;
          student_id?: string;
          school_id?: string;
          done_at?: string;
        };
        Relationships: [];
      };
      assignments: {
        Row: {
          id: string;
          school_id: string;
          class_subject_id: string;
          title: string;
          body: string | null;
          due_on: string | null;
          marks: number | null;
          status: AssignmentStatus;
          created_by: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          class_subject_id: string;
          title: string;
          body?: string | null;
          due_on?: string | null;
          marks?: number | null;
          status?: AssignmentStatus;
          created_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          class_subject_id?: string;
          title?: string;
          body?: string | null;
          due_on?: string | null;
          marks?: number | null;
          status?: AssignmentStatus;
          created_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      submissions: {
        Row: {
          id: string;
          school_id: string;
          assignment_id: string;
          student_id: string;
          submitted_at: string | null;
          mark: number | null;
          feedback: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          assignment_id: string;
          student_id: string;
          submitted_at?: string | null;
          mark?: number | null;
          feedback?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          assignment_id?: string;
          student_id?: string;
          submitted_at?: string | null;
          mark?: number | null;
          feedback?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      learning_materials: {
        Row: {
          id: string;
          school_id: string;
          class_subject_id: string;
          title: string;
          filename: string | null;
          storage_path: string | null;
          created_by: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          class_subject_id: string;
          title: string;
          filename?: string | null;
          storage_path?: string | null;
          created_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          class_subject_id?: string;
          title?: string;
          filename?: string | null;
          storage_path?: string | null;
          created_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      message_threads: {
        Row: {
          id: string;
          school_id: string;
          subject: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          subject?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          subject?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      message_participants: {
        Row: {
          thread_id: string;
          person_id: string;
          school_id: string;
        };
        Insert: {
          thread_id: string;
          person_id: string;
          school_id: string;
        };
        Update: {
          thread_id?: string;
          person_id?: string;
          school_id?: string;
        };
        Relationships: [];
      };
      messages: {
        Row: {
          id: string;
          school_id: string;
          thread_id: string;
          sender_id: string;
          body: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          school_id: string;
          thread_id: string;
          sender_id: string;
          body: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          school_id?: string;
          thread_id?: string;
          sender_id?: string;
          body?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      audit_log: {
        Row: {
          id: number;
          school_id: string | null;
          actor_id: string | null;
          action: string;
          entity_type: string;
          entity_id: string | null;
          metadata: Json;
          created_at: string;
        };
        Insert: {
          id?: number;
          school_id?: string | null;
          actor_id?: string | null;
          action: string;
          entity_type: string;
          entity_id?: string | null;
          metadata?: Json;
          created_at?: string;
        };
        Update: {
          id?: number;
          school_id?: string | null;
          actor_id?: string | null;
          action?: string;
          entity_type?: string;
          entity_id?: string | null;
          metadata?: Json;
          created_at?: string;
        };
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      current_person_id: { Args: Record<string, never>; Returns: string };
      is_school_member: { Args: { p_school_id: string }; Returns: boolean };
      has_school_role: {
        Args: { p_school_id: string; p_roles: AppRole[] };
        Returns: boolean;
      };
      can_access_class_subject: {
        Args: { p_class_subject_id: string };
        Returns: boolean;
      };
    };
    Enums: {
      app_role: AppRole;
    };
    CompositeTypes: Record<string, never>;
  };
};

export type TableName = keyof Database['public']['Tables'];
export type TableRow<T extends TableName> = Database['public']['Tables'][T]['Row'];
