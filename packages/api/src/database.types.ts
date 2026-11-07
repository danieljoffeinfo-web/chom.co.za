// Generated from the database schema by `pnpm db:types`. Do not edit by hand.

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  public: {
    Tables: {
      academic_years: {
        Row: {
          created_at: string;
          curriculum_id: string;
          ends_on: string;
          id: string;
          is_current: boolean;
          label: string;
          school_id: string;
          starts_on: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          curriculum_id: string;
          ends_on: string;
          id?: string;
          is_current?: boolean;
          label: string;
          school_id: string;
          starts_on: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          curriculum_id?: string;
          ends_on?: string;
          id?: string;
          is_current?: boolean;
          label?: string;
          school_id?: string;
          starts_on?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'academic_years_curriculum_id_fkey';
            columns: ['curriculum_id'];
            isOneToOne: false;
            referencedRelation: 'curricula';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'academic_years_school_id_fkey';
            columns: ['school_id'];
            isOneToOne: false;
            referencedRelation: 'schools';
            referencedColumns: ['id'];
          },
        ];
      };
      class_subjects: {
        Row: {
          class_id: string;
          created_at: string;
          id: string;
          qualification_level: string | null;
          school_id: string;
          subject_id: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          class_id: string;
          created_at?: string;
          id?: string;
          qualification_level?: string | null;
          school_id: string;
          subject_id: string;
          updated_at?: string;
        };
        Update: {
          class_id?: string;
          created_at?: string;
          id?: string;
          qualification_level?: string | null;
          school_id?: string;
          subject_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'class_subjects_class_id_school_id_fkey';
            columns: ['class_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'classes';
            referencedColumns: ['id', 'school_id'];
          },
          {
            foreignKeyName: 'class_subjects_subject_id_school_id_fkey';
            columns: ['subject_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'subjects';
            referencedColumns: ['id', 'school_id'];
          },
        ];
      };
      classes: {
        Row: {
          academic_year_id: string;
          created_at: string;
          ednana_id: string | null;
          grade: number;
          id: string;
          kind: Database['public']['Enums']['class_kind'];
          name: string;
          school_id: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          academic_year_id: string;
          created_at?: string;
          ednana_id?: string | null;
          grade: number;
          id?: string;
          kind?: Database['public']['Enums']['class_kind'];
          name: string;
          school_id: string;
          updated_at?: string;
        };
        Update: {
          academic_year_id?: string;
          created_at?: string;
          ednana_id?: string | null;
          grade?: number;
          id?: string;
          kind?: Database['public']['Enums']['class_kind'];
          name?: string;
          school_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'classes_academic_year_id_school_id_fkey';
            columns: ['academic_year_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'academic_years';
            referencedColumns: ['id', 'school_id'];
          },
        ];
      };
      curricula: {
        Row: {
          code: string;
          created_at: string;
          id: string;
          name: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          code: string;
          created_at?: string;
          id?: string;
          name: string;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          id?: string;
          name?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      curriculum_subject_aliases: {
        Row: {
          alias: string;
          created_at: string;
          curriculum_id: string;
          curriculum_subject_id: string;
          id: string;
          max_grade: number;
          min_grade: number;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          alias: string;
          created_at?: string;
          curriculum_id: string;
          curriculum_subject_id: string;
          id?: string;
          max_grade: number;
          min_grade: number;
          updated_at?: string;
        };
        Update: {
          alias?: string;
          created_at?: string;
          curriculum_id?: string;
          curriculum_subject_id?: string;
          id?: string;
          max_grade?: number;
          min_grade?: number;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'curriculum_subject_aliases_curriculum_subject_id_curriculu_fkey';
            columns: ['curriculum_subject_id', 'curriculum_id'];
            isOneToOne: false;
            referencedRelation: 'curriculum_subjects';
            referencedColumns: ['id', 'curriculum_id'];
          },
        ];
      };
      curriculum_subject_rule_members: {
        Row: {
          curriculum_id: string;
          curriculum_subject_id: string;
          member_role: string;
          rule_id: string;
        };
        ComputedFields: never;
        Insert: {
          curriculum_id: string;
          curriculum_subject_id: string;
          member_role?: string;
          rule_id: string;
        };
        Update: {
          curriculum_id?: string;
          curriculum_subject_id?: string;
          member_role?: string;
          rule_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'curriculum_subject_rule_membe_curriculum_subject_id_curric_fkey';
            columns: ['curriculum_subject_id', 'curriculum_id'];
            isOneToOne: false;
            referencedRelation: 'curriculum_subjects';
            referencedColumns: ['id', 'curriculum_id'];
          },
          {
            foreignKeyName: 'curriculum_subject_rule_members_rule_id_curriculum_id_fkey';
            columns: ['rule_id', 'curriculum_id'];
            isOneToOne: false;
            referencedRelation: 'curriculum_subject_rules';
            referencedColumns: ['id', 'curriculum_id'];
          },
        ];
      };
      curriculum_subject_rules: {
        Row: {
          created_at: string;
          curriculum_id: string;
          description: string;
          id: string;
          max_count: number | null;
          max_grade: number;
          min_grade: number;
          rule_type: Database['public']['Enums']['subject_rule_type'];
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          curriculum_id: string;
          description: string;
          id?: string;
          max_count?: number | null;
          max_grade: number;
          min_grade: number;
          rule_type: Database['public']['Enums']['subject_rule_type'];
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          curriculum_id?: string;
          description?: string;
          id?: string;
          max_count?: number | null;
          max_grade?: number;
          min_grade?: number;
          rule_type?: Database['public']['Enums']['subject_rule_type'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'curriculum_subject_rules_curriculum_id_fkey';
            columns: ['curriculum_id'];
            isOneToOne: false;
            referencedRelation: 'curricula';
            referencedColumns: ['id'];
          },
        ];
      };
      curriculum_subjects: {
        Row: {
          category: string | null;
          code: string | null;
          counts_toward_certificate: boolean;
          created_at: string;
          curriculum_id: string;
          externally_examined: boolean;
          id: string;
          is_compulsory: boolean;
          language_level: Database['public']['Enums']['language_level'] | null;
          max_grade: number;
          min_grade: number;
          name: string;
          qualification_level: string | null;
          sort_order: number | null;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          category?: string | null;
          code?: string | null;
          counts_toward_certificate?: boolean;
          created_at?: string;
          curriculum_id: string;
          externally_examined?: boolean;
          id?: string;
          is_compulsory?: boolean;
          language_level?: Database['public']['Enums']['language_level'] | null;
          max_grade: number;
          min_grade: number;
          name: string;
          qualification_level?: string | null;
          sort_order?: number | null;
          updated_at?: string;
        };
        Update: {
          category?: string | null;
          code?: string | null;
          counts_toward_certificate?: boolean;
          created_at?: string;
          curriculum_id?: string;
          externally_examined?: boolean;
          id?: string;
          is_compulsory?: boolean;
          language_level?: Database['public']['Enums']['language_level'] | null;
          max_grade?: number;
          min_grade?: number;
          name?: string;
          qualification_level?: string | null;
          sort_order?: number | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'curriculum_subjects_curriculum_id_fkey';
            columns: ['curriculum_id'];
            isOneToOne: false;
            referencedRelation: 'curricula';
            referencedColumns: ['id'];
          },
        ];
      };
      enrolments: {
        Row: {
          class_id: string;
          created_at: string;
          ednana_id: string | null;
          id: string;
          school_id: string;
          student_profile_id: string;
          student_role: Database['public']['Enums']['membership_role'];
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          class_id: string;
          created_at?: string;
          ednana_id?: string | null;
          id?: string;
          school_id: string;
          student_profile_id: string;
          student_role?: Database['public']['Enums']['membership_role'];
          updated_at?: string;
        };
        Update: {
          class_id?: string;
          created_at?: string;
          ednana_id?: string | null;
          id?: string;
          school_id?: string;
          student_profile_id?: string;
          student_role?: Database['public']['Enums']['membership_role'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'enrolments_class_id_school_id_fkey';
            columns: ['class_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'classes';
            referencedColumns: ['id', 'school_id'];
          },
          {
            foreignKeyName: 'enrolments_school_id_student_profile_id_student_role_fkey';
            columns: ['school_id', 'student_profile_id', 'student_role'];
            isOneToOne: false;
            referencedRelation: 'school_memberships';
            referencedColumns: ['school_id', 'profile_id', 'role'];
          },
        ];
      };
      guardianships: {
        Row: {
          activated_at: string | null;
          blocked_at: string | null;
          blocked_reason: string | null;
          created_at: string;
          ednana_id: string | null;
          id: string;
          invited_at: string;
          is_primary: boolean;
          parent_profile_id: string;
          parent_role: Database['public']['Enums']['membership_role'];
          relationship: Database['public']['Enums']['guardian_relationship'];
          school_id: string;
          status: Database['public']['Enums']['guardianship_status'];
          student_profile_id: string;
          student_role: Database['public']['Enums']['membership_role'];
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          activated_at?: string | null;
          blocked_at?: string | null;
          blocked_reason?: string | null;
          created_at?: string;
          ednana_id?: string | null;
          id?: string;
          invited_at?: string;
          is_primary?: boolean;
          parent_profile_id: string;
          parent_role?: Database['public']['Enums']['membership_role'];
          relationship?: Database['public']['Enums']['guardian_relationship'];
          school_id: string;
          status?: Database['public']['Enums']['guardianship_status'];
          student_profile_id: string;
          student_role?: Database['public']['Enums']['membership_role'];
          updated_at?: string;
        };
        Update: {
          activated_at?: string | null;
          blocked_at?: string | null;
          blocked_reason?: string | null;
          created_at?: string;
          ednana_id?: string | null;
          id?: string;
          invited_at?: string;
          is_primary?: boolean;
          parent_profile_id?: string;
          parent_role?: Database['public']['Enums']['membership_role'];
          relationship?: Database['public']['Enums']['guardian_relationship'];
          school_id?: string;
          status?: Database['public']['Enums']['guardianship_status'];
          student_profile_id?: string;
          student_role?: Database['public']['Enums']['membership_role'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'guardianships_school_id_parent_profile_id_parent_role_fkey';
            columns: ['school_id', 'parent_profile_id', 'parent_role'];
            isOneToOne: false;
            referencedRelation: 'school_memberships';
            referencedColumns: ['school_id', 'profile_id', 'role'];
          },
          {
            foreignKeyName: 'guardianships_school_id_student_profile_id_student_role_fkey';
            columns: ['school_id', 'student_profile_id', 'student_role'];
            isOneToOne: false;
            referencedRelation: 'school_memberships';
            referencedColumns: ['school_id', 'profile_id', 'role'];
          },
        ];
      };
      parent_consent_versions: {
        Row: {
          created_at: string;
          published_at: string;
          version: string;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          published_at?: string;
          version: string;
        };
        Update: {
          created_at?: string;
          published_at?: string;
          version?: string;
        };
        Relationships: [];
      };
      parent_consents: {
        Row: {
          consent_version: string;
          created_at: string;
          granted_at: string;
          guardianship_id: string;
          id: string;
          ip: unknown;
          parent_profile_id: string;
          school_id: string;
          student_profile_id: string;
          user_agent: string | null;
          withdrawn_at: string | null;
        };
        ComputedFields: never;
        Insert: {
          consent_version: string;
          created_at?: string;
          granted_at?: string;
          guardianship_id: string;
          id?: string;
          ip?: unknown;
          parent_profile_id: string;
          school_id: string;
          student_profile_id: string;
          user_agent?: string | null;
          withdrawn_at?: string | null;
        };
        Update: {
          consent_version?: string;
          created_at?: string;
          granted_at?: string;
          guardianship_id?: string;
          id?: string;
          ip?: unknown;
          parent_profile_id?: string;
          school_id?: string;
          student_profile_id?: string;
          user_agent?: string | null;
          withdrawn_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: 'parent_consents_consent_version_fkey';
            columns: ['consent_version'];
            isOneToOne: false;
            referencedRelation: 'parent_consent_versions';
            referencedColumns: ['version'];
          },
          {
            foreignKeyName: 'parent_consents_guardianship_id_fkey';
            columns: ['guardianship_id'];
            isOneToOne: false;
            referencedRelation: 'guardianships';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'parent_consents_parent_profile_id_fkey';
            columns: ['parent_profile_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'parent_consents_student_profile_id_fkey';
            columns: ['student_profile_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      parent_notification_channels: {
        Row: {
          created_at: string;
          email: boolean;
          profile_id: string;
          push: boolean;
          updated_at: string;
          whatsapp: boolean;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          email?: boolean;
          profile_id: string;
          push?: boolean;
          updated_at?: string;
          whatsapp?: boolean;
        };
        Update: {
          created_at?: string;
          email?: boolean;
          profile_id?: string;
          push?: boolean;
          updated_at?: string;
          whatsapp?: boolean;
        };
        Relationships: [
          {
            foreignKeyName: 'parent_notification_channels_profile_id_fkey';
            columns: ['profile_id'];
            isOneToOne: true;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      profiles: {
        Row: {
          created_at: string;
          full_name: string;
          id: string;
          preferred_name: string | null;
          updated_at: string;
          user_id: string | null;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          full_name: string;
          id?: string;
          preferred_name?: string | null;
          updated_at?: string;
          user_id?: string | null;
        };
        Update: {
          created_at?: string;
          full_name?: string;
          id?: string;
          preferred_name?: string | null;
          updated_at?: string;
          user_id?: string | null;
        };
        Relationships: [];
      };
      school_group_domains: {
        Row: {
          created_at: string;
          domain: string;
          id: string;
          microsoft_tenant_id: string | null;
          provider: Database['public']['Enums']['sign_in_provider'];
          school_group_id: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          domain: string;
          id?: string;
          microsoft_tenant_id?: string | null;
          provider: Database['public']['Enums']['sign_in_provider'];
          school_group_id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          domain?: string;
          id?: string;
          microsoft_tenant_id?: string | null;
          provider?: Database['public']['Enums']['sign_in_provider'];
          school_group_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'school_group_domains_school_group_id_fkey';
            columns: ['school_group_id'];
            isOneToOne: false;
            referencedRelation: 'school_groups';
            referencedColumns: ['id'];
          },
        ];
      };
      school_groups: {
        Row: {
          created_at: string;
          id: string;
          name: string;
          slug: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          id?: string;
          name: string;
          slug: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          name?: string;
          slug?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      school_memberships: {
        Row: {
          created_at: string;
          date_of_birth: string | null;
          ednana_id: string | null;
          email: string | null;
          id: string;
          job_title: string | null;
          phone: string | null;
          profile_id: string;
          role: Database['public']['Enums']['membership_role'];
          school_id: string;
          status: Database['public']['Enums']['membership_status'];
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          date_of_birth?: string | null;
          ednana_id?: string | null;
          email?: string | null;
          id?: string;
          job_title?: string | null;
          phone?: string | null;
          profile_id: string;
          role: Database['public']['Enums']['membership_role'];
          school_id: string;
          status?: Database['public']['Enums']['membership_status'];
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          date_of_birth?: string | null;
          ednana_id?: string | null;
          email?: string | null;
          id?: string;
          job_title?: string | null;
          phone?: string | null;
          profile_id?: string;
          role?: Database['public']['Enums']['membership_role'];
          school_id?: string;
          status?: Database['public']['Enums']['membership_status'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'school_memberships_profile_id_fkey';
            columns: ['profile_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'school_memberships_school_id_fkey';
            columns: ['school_id'];
            isOneToOne: false;
            referencedRelation: 'schools';
            referencedColumns: ['id'];
          },
        ];
      };
      school_subject_rule_members: {
        Row: {
          member_role: string;
          rule_id: string;
          school_id: string;
          subject_id: string;
        };
        ComputedFields: never;
        Insert: {
          member_role?: string;
          rule_id: string;
          school_id: string;
          subject_id: string;
        };
        Update: {
          member_role?: string;
          rule_id?: string;
          school_id?: string;
          subject_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'school_subject_rule_members_rule_id_school_id_fkey';
            columns: ['rule_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'school_subject_rules';
            referencedColumns: ['id', 'school_id'];
          },
          {
            foreignKeyName: 'school_subject_rule_members_subject_id_school_id_fkey';
            columns: ['subject_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'subjects';
            referencedColumns: ['id', 'school_id'];
          },
        ];
      };
      school_subject_rules: {
        Row: {
          created_at: string;
          description: string;
          id: string;
          max_count: number | null;
          max_grade: number;
          min_grade: number;
          rule_type: Database['public']['Enums']['subject_rule_type'];
          school_id: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          description: string;
          id?: string;
          max_count?: number | null;
          max_grade: number;
          min_grade: number;
          rule_type: Database['public']['Enums']['subject_rule_type'];
          school_id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          description?: string;
          id?: string;
          max_count?: number | null;
          max_grade?: number;
          min_grade?: number;
          rule_type?: Database['public']['Enums']['subject_rule_type'];
          school_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'school_subject_rules_school_id_fkey';
            columns: ['school_id'];
            isOneToOne: false;
            referencedRelation: 'schools';
            referencedColumns: ['id'];
          },
        ];
      };
      schools: {
        Row: {
          created_at: string;
          ednana_id: string | null;
          id: string;
          is_demo: boolean;
          name: string;
          school_group_id: string;
          slug: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          created_at?: string;
          ednana_id?: string | null;
          id?: string;
          is_demo?: boolean;
          name: string;
          school_group_id: string;
          slug: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          ednana_id?: string | null;
          id?: string;
          is_demo?: boolean;
          name?: string;
          school_group_id?: string;
          slug?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'schools_school_group_id_fkey';
            columns: ['school_group_id'];
            isOneToOne: false;
            referencedRelation: 'school_groups';
            referencedColumns: ['id'];
          },
        ];
      };
      student_study_profiles: {
        Row: {
          academic_year_id: string;
          created_at: string;
          id: string;
          onboarding_completed_at: string | null;
          school_id: string;
          session_length: Database['public']['Enums']['study_session_length'] | null;
          student_profile_id: string;
          student_role: Database['public']['Enums']['membership_role'];
          study_methods: Database['public']['Enums']['study_method'][];
          study_times: Database['public']['Enums']['study_time'][];
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          academic_year_id: string;
          created_at?: string;
          id?: string;
          onboarding_completed_at?: string | null;
          school_id: string;
          session_length?: Database['public']['Enums']['study_session_length'] | null;
          student_profile_id: string;
          student_role?: Database['public']['Enums']['membership_role'];
          study_methods?: Database['public']['Enums']['study_method'][];
          study_times?: Database['public']['Enums']['study_time'][];
          updated_at?: string;
        };
        Update: {
          academic_year_id?: string;
          created_at?: string;
          id?: string;
          onboarding_completed_at?: string | null;
          school_id?: string;
          session_length?: Database['public']['Enums']['study_session_length'] | null;
          student_profile_id?: string;
          student_role?: Database['public']['Enums']['membership_role'];
          study_methods?: Database['public']['Enums']['study_method'][];
          study_times?: Database['public']['Enums']['study_time'][];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'student_study_profiles_academic_year_id_school_id_fkey';
            columns: ['academic_year_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'academic_years';
            referencedColumns: ['id', 'school_id'];
          },
          {
            foreignKeyName: 'student_study_profiles_school_id_student_profile_id_studen_fkey';
            columns: ['school_id', 'student_profile_id', 'student_role'];
            isOneToOne: false;
            referencedRelation: 'school_memberships';
            referencedColumns: ['school_id', 'profile_id', 'role'];
          },
        ];
      };
      student_subject_goals: {
        Row: {
          academic_year_id: string;
          created_at: string;
          id: string;
          is_focus: boolean;
          school_id: string;
          student_profile_id: string;
          student_role: Database['public']['Enums']['membership_role'];
          subject_id: string;
          target_percent: number | null;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          academic_year_id: string;
          created_at?: string;
          id?: string;
          is_focus?: boolean;
          school_id: string;
          student_profile_id: string;
          student_role?: Database['public']['Enums']['membership_role'];
          subject_id: string;
          target_percent?: number | null;
          updated_at?: string;
        };
        Update: {
          academic_year_id?: string;
          created_at?: string;
          id?: string;
          is_focus?: boolean;
          school_id?: string;
          student_profile_id?: string;
          student_role?: Database['public']['Enums']['membership_role'];
          subject_id?: string;
          target_percent?: number | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'student_subject_goals_academic_year_id_school_id_fkey';
            columns: ['academic_year_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'academic_years';
            referencedColumns: ['id', 'school_id'];
          },
          {
            foreignKeyName: 'student_subject_goals_school_id_student_profile_id_student_fkey';
            columns: ['school_id', 'student_profile_id', 'student_role'];
            isOneToOne: false;
            referencedRelation: 'school_memberships';
            referencedColumns: ['school_id', 'profile_id', 'role'];
          },
          {
            foreignKeyName: 'student_subject_goals_subject_id_school_id_fkey';
            columns: ['subject_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'subjects';
            referencedColumns: ['id', 'school_id'];
          },
        ];
      };
      subject_offerings: {
        Row: {
          academic_year_id: string;
          block: string | null;
          created_at: string;
          id: string;
          kind: Database['public']['Enums']['offering_kind'];
          max_grade: number;
          min_grade: number;
          school_id: string;
          subject_id: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          academic_year_id: string;
          block?: string | null;
          created_at?: string;
          id?: string;
          kind: Database['public']['Enums']['offering_kind'];
          max_grade: number;
          min_grade: number;
          school_id: string;
          subject_id: string;
          updated_at?: string;
        };
        Update: {
          academic_year_id?: string;
          block?: string | null;
          created_at?: string;
          id?: string;
          kind?: Database['public']['Enums']['offering_kind'];
          max_grade?: number;
          min_grade?: number;
          school_id?: string;
          subject_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'subject_offerings_academic_year_id_school_id_fkey';
            columns: ['academic_year_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'academic_years';
            referencedColumns: ['id', 'school_id'];
          },
          {
            foreignKeyName: 'subject_offerings_subject_id_school_id_fkey';
            columns: ['subject_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'subjects';
            referencedColumns: ['id', 'school_id'];
          },
        ];
      };
      subjects: {
        Row: {
          code: string | null;
          created_at: string;
          curriculum_subject_id: string | null;
          ednana_id: string | null;
          id: string;
          name: string;
          school_id: string;
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          code?: string | null;
          created_at?: string;
          curriculum_subject_id?: string | null;
          ednana_id?: string | null;
          id?: string;
          name: string;
          school_id: string;
          updated_at?: string;
        };
        Update: {
          code?: string | null;
          created_at?: string;
          curriculum_subject_id?: string | null;
          ednana_id?: string | null;
          id?: string;
          name?: string;
          school_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'subjects_curriculum_subject_id_fkey';
            columns: ['curriculum_subject_id'];
            isOneToOne: false;
            referencedRelation: 'curriculum_subjects';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'subjects_school_id_fkey';
            columns: ['school_id'];
            isOneToOne: false;
            referencedRelation: 'schools';
            referencedColumns: ['id'];
          },
        ];
      };
      teaching_allocations: {
        Row: {
          class_subject_id: string;
          created_at: string;
          ednana_id: string | null;
          id: string;
          school_id: string;
          teacher_profile_id: string;
          teacher_role: Database['public']['Enums']['membership_role'];
          updated_at: string;
        };
        ComputedFields: never;
        Insert: {
          class_subject_id: string;
          created_at?: string;
          ednana_id?: string | null;
          id?: string;
          school_id: string;
          teacher_profile_id: string;
          teacher_role?: Database['public']['Enums']['membership_role'];
          updated_at?: string;
        };
        Update: {
          class_subject_id?: string;
          created_at?: string;
          ednana_id?: string | null;
          id?: string;
          school_id?: string;
          teacher_profile_id?: string;
          teacher_role?: Database['public']['Enums']['membership_role'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'teaching_allocations_class_subject_id_school_id_fkey';
            columns: ['class_subject_id', 'school_id'];
            isOneToOne: false;
            referencedRelation: 'class_subjects';
            referencedColumns: ['id', 'school_id'];
          },
          {
            foreignKeyName: 'teaching_allocations_school_id_teacher_profile_id_teacher__fkey';
            columns: ['school_id', 'teacher_profile_id', 'teacher_role'];
            isOneToOne: false;
            referencedRelation: 'school_memberships';
            referencedColumns: ['school_id', 'profile_id', 'role'];
          },
        ];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      link_my_account: { Args: Record<PropertyKey, never>; Returns: string };
      my_guardian_links: {
        Args: Record<PropertyKey, never>;
        Returns: {
          consented: boolean;
          grade: number;
          guardianship_id: string;
          is_primary: boolean;
          relationship: Database['public']['Enums']['guardian_relationship'];
          school_id: string;
          school_name: string;
          status: Database['public']['Enums']['guardianship_status'];
          student_name: string;
          student_profile_id: string;
        }[];
      };
      my_parent_dashboard: { Args: Record<PropertyKey, never>; Returns: Json };
      my_staff_dashboard: { Args: Record<PropertyKey, never>; Returns: Json };
      record_parent_consent: {
        Args: {
          p_email: boolean;
          p_ip?: unknown;
          p_push: boolean;
          p_user_agent?: string;
          p_version: string;
          p_whatsapp: boolean;
        };
        Returns: number;
      };
      resolve_curriculum_subject: {
        Args: { p_curriculum_code: string; p_grade: number; p_name: string };
        Returns: string;
      };
      withdraw_parent_consent: { Args: { p_guardianship_id: string }; Returns: undefined };
    };
    Enums: {
      class_kind: 'register' | 'subject_group';
      guardian_relationship: 'mother' | 'father' | 'guardian' | 'other';
      guardianship_status:
        'invited' | 'active' | 'blocked' | 'consent_withdrawn' | 'learner_revoked';
      language_level: 'home' | 'first_additional' | 'second_additional';
      membership_role: 'student' | 'teacher' | 'parent' | 'school_admin';
      membership_status: 'active' | 'inactive';
      offering_kind: 'fundamental' | 'elective' | 'extra';
      sign_in_provider: 'microsoft' | 'google';
      staff_level: 'support' | 'operations' | 'owner';
      study_method:
        'pen_and_paper' | 'videos' | 'ai_chat' | 'past_papers' | 'flashcards' | 'study_group';
      study_session_length: 'minutes_15' | 'minutes_30' | 'minutes_45' | 'minutes_60_plus';
      study_time: 'afternoon' | 'evening' | 'late_night' | 'weekends';
      subject_rule_type: 'mutually_exclusive' | 'requires' | 'max_from_group';
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>;

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, 'public'>];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
    ? (DefaultSchema['Tables'] & DefaultSchema['Views'])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema['Enums'] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums']
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums'][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums']
    ? DefaultSchema['Enums'][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema['CompositeTypes'] | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes']
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes'][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema['CompositeTypes']
    ? DefaultSchema['CompositeTypes'][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  public: {
    Enums: {
      class_kind: ['register', 'subject_group'],
      guardian_relationship: ['mother', 'father', 'guardian', 'other'],
      guardianship_status: ['invited', 'active', 'blocked', 'consent_withdrawn', 'learner_revoked'],
      language_level: ['home', 'first_additional', 'second_additional'],
      membership_role: ['student', 'teacher', 'parent', 'school_admin'],
      membership_status: ['active', 'inactive'],
      offering_kind: ['fundamental', 'elective', 'extra'],
      sign_in_provider: ['microsoft', 'google'],
      staff_level: ['support', 'operations', 'owner'],
      study_method: [
        'pen_and_paper',
        'videos',
        'ai_chat',
        'past_papers',
        'flashcards',
        'study_group',
      ],
      study_session_length: ['minutes_15', 'minutes_30', 'minutes_45', 'minutes_60_plus'],
      study_time: ['afternoon', 'evening', 'late_night', 'weekends'],
      subject_rule_type: ['mutually_exclusive', 'requires', 'max_from_group'],
    },
  },
} as const;
