import { createClient as createSupabaseClient } from "@supabase/supabase-js"

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || ""
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ""

// Is the environment configured?
export const hasSupabaseCredentials = Boolean(
  process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
)

export const supabase = hasSupabaseCredentials ? createSupabaseClient(supabaseUrl, supabaseAnonKey) : (null as any)

// Also export createClient for compatibility
export const createClient = () => supabase

// Default export
export default supabase

export type Database = {
  public: {
    Tables: {
      users: {
        Row: {
          id: string
          user_id: string
          email: string
          full_name: string | null
          referrer_user_id: string | null
          created_at: string
          updated_at: string
          is_active: boolean
          total_purchases: number
          total_referral_earnings: number
        }
        Insert: {
          id: string
          user_id: string
          email: string
          full_name?: string | null
          referrer_user_id?: string | null
        }
        Update: {
          full_name?: string | null
          is_active?: boolean
          total_purchases?: number
          total_referral_earnings?: number
        }
      }
      purchases: {
        Row: {
          id: string
          user_id: string
          nft_quantity: number
          amount_usd: number
          usdt_address_bep20: string | null
          usdt_address_trc20: string | null
          payment_status: string
          nft_sent: boolean
          created_at: string
          confirmed_at: string | null
          completed_at: string | null
        }
        Insert: {
          user_id: string
          nft_quantity: number
          amount_usd: number
        }
        Update: {
          payment_status?: string
          nft_sent?: boolean
          confirmed_at?: string | null
          completed_at?: string | null
        }
      }
    }
  }
}
