// Supabase Edge Function: 日利データを取得して外部サイトに提供
// エンドポイント: https://[project-ref].supabase.co/functions/v1/get-daily-yields

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Supabase クライアントを作成
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // URLパラメータを取得（オプション）
    const url = new URL(req.url)
    const limit = url.searchParams.get('limit') || '30' // デフォルト30件
    const startDate = url.searchParams.get('start_date') // 開始日（オプション）
    const endDate = url.searchParams.get('end_date') // 終了日（オプション）

    // daily_yield_logテーブルからデータを取得
    let query = supabaseClient
      .from('daily_yield_log')
      .select('date, yield_rate, user_rate, margin_rate, created_at')
      .order('date', { ascending: false })
      .limit(parseInt(limit))

    // 日付フィルター（オプション）
    if (startDate) {
      query = query.gte('date', startDate)
    }
    if (endDate) {
      query = query.lte('date', endDate)
    }

    const { data, error } = await query

    if (error) {
      throw error
    }

    // データを整形
    const formattedData = data.map(item => ({
      date: item.date,
      yield_rate: parseFloat(item.yield_rate),
      user_rate: parseFloat(item.user_rate),
      margin_rate: parseFloat(item.margin_rate),
      profit_percentage: (parseFloat(item.user_rate) * 100).toFixed(3), // ユーザー受取率を%表示
      created_at: item.created_at
    }))

    return new Response(
      JSON.stringify({
        success: true,
        data: formattedData,
        count: formattedData.length
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    )

  } catch (error) {
    console.error('Error fetching daily yields:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    )
  }
})
