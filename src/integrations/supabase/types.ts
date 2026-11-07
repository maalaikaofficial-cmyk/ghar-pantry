export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      audit_log: {
        Row: {
          action: string
          actor: string | null
          created_at: string
          data: Json | null
          household_id: string | null
          id: number
          row_id: string | null
          table_name: string
        }
        Insert: {
          action: string
          actor?: string | null
          created_at?: string
          data?: Json | null
          household_id?: string | null
          id?: never
          row_id?: string | null
          table_name: string
        }
        Update: {
          action?: string
          actor?: string | null
          created_at?: string
          data?: Json | null
          household_id?: string | null
          id?: never
          row_id?: string | null
          table_name?: string
        }
        Relationships: []
      }
      availability_checks: {
        Row: {
          actor: string | null
          check_date: string
          created_at: string
          household_id: string
          id: string
          item_id: string
          op_id: string | null
          status: string
          undone_at: string | null
        }
        Insert: {
          actor?: string | null
          check_date: string
          created_at?: string
          household_id: string
          id?: string
          item_id: string
          op_id?: string | null
          status: string
          undone_at?: string | null
        }
        Update: {
          actor?: string | null
          check_date?: string
          created_at?: string
          household_id?: string
          id?: string
          item_id?: string
          op_id?: string | null
          status?: string
          undone_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "availability_checks_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_checks_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "availability_checks_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_template: {
        Row: {
          base_unit: string
          cat_key: string
          emoji: string
          gf_status: string
          id: number
          location_key: string
          name_en: string
          name_ur: string
          shelf_days: number | null
        }
        Insert: {
          base_unit: string
          cat_key: string
          emoji: string
          gf_status: string
          id?: number
          location_key: string
          name_en: string
          name_ur: string
          shelf_days?: number | null
        }
        Update: {
          base_unit?: string
          cat_key?: string
          emoji?: string
          gf_status?: string
          id?: number
          location_key?: string
          name_en?: string
          name_ur?: string
          shelf_days?: number | null
        }
        Relationships: []
      }
      categories: {
        Row: {
          emoji: string
          food: boolean
          household_id: string
          id: string
          key: string
          name_en: string
          name_ur: string
          sort: number
        }
        Insert: {
          emoji?: string
          food?: boolean
          household_id: string
          id?: string
          key: string
          name_en: string
          name_ur: string
          sort?: number
        }
        Update: {
          emoji?: string
          food?: boolean
          household_id?: string
          id?: string
          key?: string
          name_en?: string
          name_ur?: string
          sort?: number
        }
        Relationships: [
          {
            foreignKeyName: "categories_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      conflict_cases: {
        Row: {
          created_at: string
          details: Json | null
          household_id: string
          id: string
          item_id: string | null
          kind: string
          resolved_at: string | null
          resolved_by: string | null
          status: string
        }
        Insert: {
          created_at?: string
          details?: Json | null
          household_id: string
          id?: string
          item_id?: string | null
          kind: string
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string
        }
        Update: {
          created_at?: string
          details?: Json | null
          household_id?: string
          id?: string
          item_id?: string | null
          kind?: string
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "conflict_cases_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conflict_cases_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "conflict_cases_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      consumption_lines: {
        Row: {
          deducted: number
          household_id: string
          id: string
          item_id: string
          note: string | null
          qty: number | null
          qty_base: number | null
          report_id: string
          shortfall: number
          unit: string | null
        }
        Insert: {
          deducted?: number
          household_id: string
          id?: string
          item_id: string
          note?: string | null
          qty?: number | null
          qty_base?: number | null
          report_id: string
          shortfall?: number
          unit?: string | null
        }
        Update: {
          deducted?: number
          household_id?: string
          id?: string
          item_id?: string
          note?: string | null
          qty?: number | null
          qty_base?: number | null
          report_id?: string
          shortfall?: number
          unit?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "consumption_lines_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "consumption_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "consumption_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "consumption_lines_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "consumption_reports"
            referencedColumns: ["id"]
          },
        ]
      }
      consumption_reports: {
        Row: {
          actor: string | null
          audio_path: string | null
          created_at: string
          household_id: string
          id: string
          op_id: string | null
          status: string
          transcript: string | null
          undone_at: string | null
        }
        Insert: {
          actor?: string | null
          audio_path?: string | null
          created_at?: string
          household_id: string
          id?: string
          op_id?: string | null
          status: string
          transcript?: string | null
          undone_at?: string | null
        }
        Update: {
          actor?: string | null
          audio_path?: string | null
          created_at?: string
          household_id?: string
          id?: string
          op_id?: string | null
          status?: string
          transcript?: string | null
          undone_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "consumption_reports_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      correction_requests: {
        Row: {
          created_at: string
          decided_at: string | null
          decided_by: string | null
          household_id: string
          id: string
          reason: string | null
          requested_by: string | null
          status: string
          sync_operation_id: string | null
        }
        Insert: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          household_id: string
          id?: string
          reason?: string | null
          requested_by?: string | null
          status?: string
          sync_operation_id?: string | null
        }
        Update: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          household_id?: string
          id?: string
          reason?: string | null
          requested_by?: string | null
          status?: string
          sync_operation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "correction_requests_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "correction_requests_sync_operation_id_fkey"
            columns: ["sync_operation_id"]
            isOneToOne: false
            referencedRelation: "sync_operations"
            referencedColumns: ["id"]
          },
        ]
      }
      devices: {
        Row: {
          created_at: string
          household_id: string
          id: string
          label: string
          last_seen_at: string | null
          paired_at: string | null
          revoked_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string
          household_id: string
          id?: string
          label: string
          last_seen_at?: string | null
          paired_at?: string | null
          revoked_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string
          household_id?: string
          id?: string
          label?: string
          last_seen_at?: string | null
          paired_at?: string | null
          revoked_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "devices_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_ledger: {
        Row: {
          affects_cash: boolean
          amount: number
          created_at: string
          created_by: string | null
          entry_type: string
          household_id: string
          id: string
          note: string | null
          op_id: string | null
          purchase_id: string | null
          reverses_id: string | null
        }
        Insert: {
          affects_cash?: boolean
          amount: number
          created_at?: string
          created_by?: string | null
          entry_type: string
          household_id: string
          id?: string
          note?: string | null
          op_id?: string | null
          purchase_id?: string | null
          reverses_id?: string | null
        }
        Update: {
          affects_cash?: boolean
          amount?: number
          created_at?: string
          created_by?: string | null
          entry_type?: string
          household_id?: string
          id?: string
          note?: string | null
          op_id?: string | null
          purchase_id?: string | null
          reverses_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_ledger_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_ledger_purchase_id_fkey"
            columns: ["purchase_id"]
            isOneToOne: false
            referencedRelation: "purchases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_ledger_reverses_id_fkey"
            columns: ["reverses_id"]
            isOneToOne: false
            referencedRelation: "finance_ledger"
            referencedColumns: ["id"]
          },
        ]
      }
      household_settings: {
        Row: {
          briefing_time: string
          household_id: string
          monthly_budget: number
          quiet_end: string
          quiet_start: string
          updated_at: string
        }
        Insert: {
          briefing_time?: string
          household_id: string
          monthly_budget?: number
          quiet_end?: string
          quiet_start?: string
          updated_at?: string
        }
        Update: {
          briefing_time?: string
          household_id?: string
          monthly_budget?: number
          quiet_end?: string
          quiet_start?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "household_settings_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: true
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      households: {
        Row: {
          created_at: string
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
      inventory_events: {
        Row: {
          actor: string | null
          batch_id: string | null
          created_at: string
          event_type: string
          household_id: string
          id: string
          item_id: string
          note: string | null
          op_id: string | null
          qty: number
          ref_id: string | null
          ref_type: string | null
          reverses_event_id: string | null
        }
        Insert: {
          actor?: string | null
          batch_id?: string | null
          created_at?: string
          event_type: string
          household_id: string
          id?: string
          item_id: string
          note?: string | null
          op_id?: string | null
          qty: number
          ref_id?: string | null
          ref_type?: string | null
          reverses_event_id?: string | null
        }
        Update: {
          actor?: string | null
          batch_id?: string | null
          created_at?: string
          event_type?: string
          household_id?: string
          id?: string
          item_id?: string
          note?: string | null
          op_id?: string | null
          qty?: number
          ref_id?: string | null
          ref_type?: string | null
          reverses_event_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inventory_events_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "stock_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_events_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_events_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "inventory_events_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_events_reverses_event_id_fkey"
            columns: ["reverses_event_id"]
            isOneToOne: false
            referencedRelation: "inventory_events"
            referencedColumns: ["id"]
          },
        ]
      }
      items: {
        Row: {
          active: boolean
          base_unit: string
          category_id: string
          created_at: string
          default_purchase_qty: number | null
          emoji: string
          gf_status: string
          household_id: string
          id: string
          image_path: string | null
          location_id: string | null
          low_threshold: number | null
          name_en: string
          name_ur: string
          shelf_days: number | null
          sort: number
        }
        Insert: {
          active?: boolean
          base_unit?: string
          category_id: string
          created_at?: string
          default_purchase_qty?: number | null
          emoji?: string
          gf_status?: string
          household_id: string
          id?: string
          image_path?: string | null
          location_id?: string | null
          low_threshold?: number | null
          name_en: string
          name_ur: string
          shelf_days?: number | null
          sort?: number
        }
        Update: {
          active?: boolean
          base_unit?: string
          category_id?: string
          created_at?: string
          default_purchase_qty?: number | null
          emoji?: string
          gf_status?: string
          household_id?: string
          id?: string
          image_path?: string | null
          location_id?: string | null
          low_threshold?: number | null
          name_en?: string
          name_ur?: string
          shelf_days?: number | null
          sort?: number
        }
        Relationships: [
          {
            foreignKeyName: "items_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "items_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "items_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
        ]
      }
      leftover_records: {
        Row: {
          actor: string | null
          audio_path: string | null
          contains_gluten: string
          cooled_properly: boolean | null
          created_at: string
          dish_name: string
          household_id: string
          id: string
          op_id: string | null
          photo_path: string | null
          portions: number | null
          prepared_at: string
          status: string
          storage: string
          stored_at: string | null
        }
        Insert: {
          actor?: string | null
          audio_path?: string | null
          contains_gluten?: string
          cooled_properly?: boolean | null
          created_at?: string
          dish_name: string
          household_id: string
          id?: string
          op_id?: string | null
          photo_path?: string | null
          portions?: number | null
          prepared_at: string
          status?: string
          storage: string
          stored_at?: string | null
        }
        Update: {
          actor?: string | null
          audio_path?: string | null
          contains_gluten?: string
          cooled_properly?: boolean | null
          created_at?: string
          dish_name?: string
          household_id?: string
          id?: string
          op_id?: string | null
          photo_path?: string | null
          portions?: number | null
          prepared_at?: string
          status?: string
          storage?: string
          stored_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "leftover_records_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      locations: {
        Row: {
          household_id: string
          id: string
          key: string
          name_en: string
          name_ur: string
        }
        Insert: {
          household_id: string
          id?: string
          key: string
          name_en: string
          name_ur: string
        }
        Update: {
          household_id?: string
          id?: string
          key?: string
          name_en?: string
          name_ur?: string
        }
        Relationships: [
          {
            foreignKeyName: "locations_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      meal_plans: {
        Row: {
          created_at: string
          created_by: string | null
          household_id: string
          id: string
          leftover_id: string | null
          notes: string | null
          plan_date: string
          portions: string | null
          recipe_key: string | null
          slot: string
          title: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          household_id: string
          id?: string
          leftover_id?: string | null
          notes?: string | null
          plan_date: string
          portions?: string | null
          recipe_key?: string | null
          slot: string
          title: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          household_id?: string
          id?: string
          leftover_id?: string | null
          notes?: string | null
          plan_date?: string
          portions?: string | null
          recipe_key?: string | null
          slot?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "meal_plans_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_plans_leftover_id_fkey"
            columns: ["leftover_id"]
            isOneToOne: false
            referencedRelation: "leftover_records"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string | null
          created_at: string
          dedup_key: string | null
          deliver_after: string
          household_id: string
          id: string
          kind: string
          occurrences: number
          read_at: string | null
          severity: string
          title: string
          updated_at: string
        }
        Insert: {
          body?: string | null
          created_at?: string
          dedup_key?: string | null
          deliver_after?: string
          household_id: string
          id?: string
          kind: string
          occurrences?: number
          read_at?: string | null
          severity?: string
          title: string
          updated_at?: string
        }
        Update: {
          body?: string | null
          created_at?: string
          dedup_key?: string | null
          deliver_after?: string
          household_id?: string
          id?: string
          kind?: string
          occurrences?: number
          read_at?: string | null
          severity?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      pairing_tokens: {
        Row: {
          created_at: string
          device_id: string
          expires_at: string
          household_id: string
          id: string
          token_hash: string
          used_at: string | null
        }
        Insert: {
          created_at?: string
          device_id: string
          expires_at: string
          household_id: string
          id?: string
          token_hash: string
          used_at?: string | null
        }
        Update: {
          created_at?: string
          device_id?: string
          expires_at?: string
          household_id?: string
          id?: string
          token_hash?: string
          used_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "pairing_tokens_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pairing_tokens_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      purchase_lines: {
        Row: {
          household_id: string
          id: string
          item_id: string
          line_total: number
          price_per_base: number | null
          purchase_id: string
          qty: number
          qty_base: number
          qty_received_base: number
          request_id: string | null
          unit: string
        }
        Insert: {
          household_id: string
          id?: string
          item_id: string
          line_total: number
          price_per_base?: number | null
          purchase_id: string
          qty: number
          qty_base: number
          qty_received_base?: number
          request_id?: string | null
          unit: string
        }
        Update: {
          household_id?: string
          id?: string
          item_id?: string
          line_total?: number
          price_per_base?: number | null
          purchase_id?: string
          qty?: number
          qty_base?: number
          qty_received_base?: number
          request_id?: string | null
          unit?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_lines_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "purchase_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_lines_purchase_id_fkey"
            columns: ["purchase_id"]
            isOneToOne: false
            referencedRelation: "purchases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_lines_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: false
            referencedRelation: "shopping_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      purchases: {
        Row: {
          created_at: string
          created_by: string | null
          household_id: string
          id: string
          ocr_suggestion: Json | null
          paid_from: string
          purchased_at: string
          receipt_path: string | null
          status: string
          total: number
          vendor: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          household_id: string
          id?: string
          ocr_suggestion?: Json | null
          paid_from?: string
          purchased_at?: string
          receipt_path?: string | null
          status?: string
          total?: number
          vendor?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          household_id?: string
          id?: string
          ocr_suggestion?: Json | null
          paid_from?: string
          purchased_at?: string
          receipt_path?: string | null
          status?: string
          total?: number
          vendor?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "purchases_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      receiving_lines: {
        Row: {
          created_at: string
          expiry_date: string | null
          expiry_source: string | null
          household_id: string
          id: string
          op_id: string | null
          photo_path: string | null
          purchase_line_id: string
          reported_by: string | null
          reported_qty_base: number | null
          status: string
          verified_by: string | null
          verified_qty_base: number | null
        }
        Insert: {
          created_at?: string
          expiry_date?: string | null
          expiry_source?: string | null
          household_id: string
          id?: string
          op_id?: string | null
          photo_path?: string | null
          purchase_line_id: string
          reported_by?: string | null
          reported_qty_base?: number | null
          status?: string
          verified_by?: string | null
          verified_qty_base?: number | null
        }
        Update: {
          created_at?: string
          expiry_date?: string | null
          expiry_source?: string | null
          household_id?: string
          id?: string
          op_id?: string | null
          photo_path?: string | null
          purchase_line_id?: string
          reported_by?: string | null
          reported_qty_base?: number | null
          status?: string
          verified_by?: string | null
          verified_qty_base?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "receiving_lines_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "receiving_lines_purchase_line_id_fkey"
            columns: ["purchase_line_id"]
            isOneToOne: false
            referencedRelation: "purchase_lines"
            referencedColumns: ["id"]
          },
        ]
      }
      shopping_requests: {
        Row: {
          approved_qty: number | null
          created_at: string
          decided_at: string | null
          decided_by: string | null
          household_id: string
          id: string
          item_id: string
          note: string | null
          requested_by: string | null
          source: string
          status: string
          substitute_item_id: string | null
          suggested_qty: number | null
          updated_at: string
        }
        Insert: {
          approved_qty?: number | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          household_id: string
          id?: string
          item_id: string
          note?: string | null
          requested_by?: string | null
          source: string
          status?: string
          substitute_item_id?: string | null
          suggested_qty?: number | null
          updated_at?: string
        }
        Update: {
          approved_qty?: number | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          household_id?: string
          id?: string
          item_id?: string
          note?: string | null
          requested_by?: string | null
          source?: string
          status?: string
          substitute_item_id?: string | null
          suggested_qty?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shopping_requests_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shopping_requests_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "shopping_requests_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shopping_requests_substitute_item_id_fkey"
            columns: ["substitute_item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "shopping_requests_substitute_item_id_fkey"
            columns: ["substitute_item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_batches: {
        Row: {
          expiry_date: string | null
          expiry_source: string
          household_id: string
          id: string
          item_id: string
          origin: string
          qty_initial: number
          qty_remaining: number
          received_at: string
        }
        Insert: {
          expiry_date?: string | null
          expiry_source?: string
          household_id: string
          id?: string
          item_id: string
          origin: string
          qty_initial: number
          qty_remaining: number
          received_at?: string
        }
        Update: {
          expiry_date?: string | null
          expiry_source?: string
          household_id?: string
          id?: string
          item_id?: string
          origin?: string
          qty_initial?: number
          qty_remaining?: number
          received_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_batches_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_batches_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "stock_batches_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      sync_operations: {
        Row: {
          actor: string | null
          created_at: string
          household_id: string
          id: string
          op_id: string
          op_type: string
          result: Json | null
          undoable: boolean
          undone_at: string | null
        }
        Insert: {
          actor?: string | null
          created_at?: string
          household_id: string
          id?: string
          op_id: string
          op_type: string
          result?: Json | null
          undoable?: boolean
          undone_at?: string | null
        }
        Update: {
          actor?: string | null
          created_at?: string
          household_id?: string
          id?: string
          op_id?: string
          op_type?: string
          result?: Json | null
          undoable?: boolean
          undone_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sync_operations_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          active: boolean
          created_at: string
          display_name: string | null
          household_id: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          display_name?: string | null
          household_id: string
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          display_name?: string | null
          household_id?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      waste_events: {
        Row: {
          actor: string | null
          audio_path: string | null
          created_at: string
          deducted: number
          estimated_value: number | null
          household_id: string
          id: string
          item_id: string | null
          leftover_id: string | null
          op_id: string | null
          photo_path: string | null
          qty: number | null
          qty_base: number | null
          reason: string
          undone_at: string | null
          unit: string | null
        }
        Insert: {
          actor?: string | null
          audio_path?: string | null
          created_at?: string
          deducted?: number
          estimated_value?: number | null
          household_id: string
          id?: string
          item_id?: string | null
          leftover_id?: string | null
          op_id?: string | null
          photo_path?: string | null
          qty?: number | null
          qty_base?: number | null
          reason: string
          undone_at?: string | null
          unit?: string | null
        }
        Update: {
          actor?: string | null
          audio_path?: string | null
          created_at?: string
          deducted?: number
          estimated_value?: number | null
          household_id?: string
          id?: string
          item_id?: string | null
          leftover_id?: string | null
          op_id?: string | null
          photo_path?: string | null
          qty?: number | null
          qty_base?: number | null
          reason?: string
          undone_at?: string | null
          unit?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "waste_events_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_events_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "item_stock"
            referencedColumns: ["item_id"]
          },
          {
            foreignKeyName: "waste_events_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      item_stock: {
        Row: {
          household_id: string | null
          item_id: string | null
          known: boolean | null
          next_expiry: string | null
          qty: number | null
          used_30d: number | null
        }
        Insert: {
          household_id?: string | null
          item_id?: string | null
          known?: never
          next_expiry?: never
          qty?: never
          used_30d?: never
        }
        Update: {
          household_id?: string | null
          item_id?: string | null
          known?: never
          next_expiry?: never
          qty?: never
          used_30d?: never
        }
        Relationships: [
          {
            foreignKeyName: "items_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      _begin_op: {
        Args: { hh: string; p_op: string; p_type: string }
        Returns: Json
      }
      _check_low: { Args: { hh: string; p_item: string }; Returns: undefined }
      _ctx: { Args: { require_admin?: boolean }; Returns: string }
      _deduct: {
        Args: {
          hh: string
          p_item: string
          p_note: string
          p_op: string
          p_qty: number
          p_ref: string
          p_ref_type: string
          p_type: string
        }
        Returns: number
      }
      _ensure_request: {
        Args: {
          hh: string
          p_item: string
          p_note: string
          p_qty: number
          p_source: string
        }
        Returns: Json
      }
      _finish_op: {
        Args: { hh: string; p_op: string; p_result: Json; p_undoable: boolean }
        Returns: Json
      }
      _generate_briefing: { Args: { hh: string }; Returns: Json }
      _notify: {
        Args: {
          hh: string
          p_body: string
          p_dedup: string
          p_kind: string
          p_sev: string
          p_title: string
        }
        Returns: undefined
      }
      _reverse_events: {
        Args: { hh: string; p_note: string; p_op: string }
        Returns: undefined
      }
      _reverse_op: {
        Args: {
          hh: string
          p_note: string
          so: Database["public"]["Tables"]["sync_operations"]["Row"]
        }
        Returns: undefined
      }
      _stock: { Args: { p_item: string }; Returns: Record<string, unknown> }
      _suggest_qty: { Args: { p_item: string }; Returns: number }
      admin_briefing: { Args: never; Returns: Json }
      admin_close_audio: { Args: { p_report: string }; Returns: undefined }
      admin_create_request: {
        Args: { p_item: string; p_note: string; p_qty: number }
        Returns: Json
      }
      admin_decide_correction: {
        Args: { p_approve: boolean; p_id: string }
        Returns: undefined
      }
      admin_decide_request: {
        Args: {
          p_approve: boolean
          p_id: string
          p_qty: number
          p_substitute: string
        }
        Returns: undefined
      }
      admin_finance_entry: {
        Args: { p_amount: number; p_note: string; p_op: string; p_type: string }
        Returns: Json
      }
      admin_mark_notifications_read: {
        Args: { p_ids: string[] }
        Returns: undefined
      }
      admin_plan_meal: {
        Args: {
          p_date: string
          p_leftover: string
          p_missing: string[]
          p_portions: string
          p_recipe: string
          p_slot: string
          p_title: string
        }
        Returns: Json
      }
      admin_reconcile: {
        Args: {
          p_counted: number
          p_item: string
          p_note: string
          p_op: string
          p_unit: string
        }
        Returns: Json
      }
      admin_record_opening: {
        Args: {
          p_expiry: string
          p_expiry_source: string
          p_item: string
          p_op: string
          p_qty: number
          p_unit: string
        }
        Returns: Json
      }
      admin_record_purchase: {
        Args: {
          p_date: string
          p_lines: Json
          p_ocr: Json
          p_op: string
          p_paid_from: string
          p_receipt: string
          p_vendor: string
          p_verify: boolean
        }
        Returns: Json
      }
      admin_remove_meal: { Args: { p_id: string }; Returns: undefined }
      admin_resolve_conflict: { Args: { p_id: string }; Returns: undefined }
      admin_return: {
        Args: {
          p_line: string
          p_note: string
          p_op: string
          p_qty_base: number
          p_refund: number
        }
        Returns: Json
      }
      admin_revoke_device: { Args: { p_device: string }; Returns: string }
      admin_set_batch_expiry: {
        Args: { p_batch: string; p_expiry: string; p_source: string }
        Returns: undefined
      }
      admin_update_settings: {
        Args: { p_budget: number; p_quiet_end: string; p_quiet_start: string }
        Returns: undefined
      }
      admin_upsert_item: { Args: { p: Json; p_id: string }; Returns: string }
      admin_verify_purchase: { Args: { p_id: string }; Returns: undefined }
      admin_verify_receiving: {
        Args: {
          p_expiry: string
          p_expiry_source: string
          p_line: string
          p_op: string
          p_qty_base: number
          p_receiving: string
        }
        Returns: Json
      }
      convert_qty: {
        Args: { p_base: string; p_qty: number; p_unit: string }
        Returns: number
      }
      create_household: {
        Args: { p_display_name: string; p_name: string }
        Returns: string
      }
      device_heartbeat: { Args: never; Returns: undefined }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_admin: { Args: never; Returns: boolean }
      my_household: { Args: never; Returns: string }
      pending_receipts: {
        Args: never
        Returns: {
          base_unit: string
          emoji: string
          item_id: string
          name_en: string
          name_ur: string
          purchase_line_id: string
          qty_expected: number
          qty_received: number
          reported: boolean
        }[]
      }
      record_leftover: {
        Args: {
          p_audio: string
          p_cooled: boolean
          p_dish: string
          p_gluten: string
          p_op: string
          p_photo: string
          p_portions: number
          p_prepared: string
          p_storage: string
          p_stored: string
        }
        Returns: Json
      }
      report_received: {
        Args: {
          p_line: string
          p_op: string
          p_photo: string
          p_qty_base: number
        }
        Returns: Json
      }
      report_waste: {
        Args: {
          p_audio: string
          p_item: string
          p_leftover: string
          p_op: string
          p_photo: string
          p_qty: number
          p_reason: string
          p_unit: string
        }
        Returns: Json
      }
      request_correction: {
        Args: { p_reason: string; p_sync_op: string }
        Returns: string
      }
      run_daily_briefings: { Args: never; Returns: undefined }
      save_pending_audio: {
        Args: { p_audio: string; p_kind: string; p_op: string }
        Returns: Json
      }
      set_leftover_status: {
        Args: { p_id: string; p_status: string }
        Returns: undefined
      }
      submit_availability: {
        Args: { p_date: string; p_item: string; p_op: string; p_status: string }
        Returns: Json
      }
      submit_usage: {
        Args: {
          p_audio: string
          p_lines: Json
          p_op: string
          p_transcript: string
        }
        Returns: Json
      }
      undo_last_action: { Args: never; Returns: Json }
    }
    Enums: {
      app_role: "admin" | "housekeeper"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "housekeeper"],
    },
  },
} as const