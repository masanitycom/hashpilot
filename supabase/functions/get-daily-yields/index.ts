// Supabase Edge Function: 日利データを取得して外部サイトに提供
// エンドポイント: https://[project-ref].supabase.co/functions/v1/get-daily-yields
// V1（11月、利率%）とV2（12月、金額$）の両方のデータを統合して返す

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
    // Supabase クライアントを作成（認証不要の公開エンドポイント）
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    // URLパラメータを取得（オプション）
    const url = new URL(req.url)
    const limit = url.searchParams.get('limit') || '30' // デフォルト30件
    const startDate = url.searchParams.get('start_date') // 開始日（オプション）
    const endDate = url.searchParams.get('end_date') // 終了日（オプション）

    // V1: daily_yield_logテーブルからデータを取得（11月、利率%）
    let v1Query = supabaseClient
      .from('daily_yield_log')
      .select('date, yield_rate, user_rate, margin_rate, created_at')
      .order('date', { ascending: false })

    // 日付フィルター（オプション）
    if (startDate) {
      v1Query = v1Query.gte('date', startDate)
    }
    if (endDate) {
      v1Query = v1Query.lte('date', endDate)
    }

    const { data: v1Data, error: v1Error } = await v1Query

    if (v1Error) {
      console.error('V1 data error:', v1Error)
    }

    // V2: daily_yield_log_v2テーブルからデータを取得（12月、金額$）
    let v2Query = supabaseClient
      .from('daily_yield_log_v2')
      .select('date, daily_pnl, profit_per_nft, fee_rate, created_at')
      .order('date', { ascending: false })

    // 日付フィルター（オプション）
    if (startDate) {
      v2Query = v2Query.gte('date', startDate)
    }
    if (endDate) {
      v2Query = v2Query.lte('date', endDate)
    }

    const { data: v2Data, error: v2Error } = await v2Query

    if (v2Error) {
      console.error('V2 data error:', v2Error)
    }

    // V1データを整形
    // V1のuser_rateは既に%表示（例：0.099 = 0.099%）なのでそのまま使用
    const v1Formatted = (v1Data || []).map(item => ({
      date: item.date,
      yield_rate: parseFloat(item.yield_rate || '0'),
      user_rate: parseFloat(item.user_rate || '0'),
      margin_rate: parseFloat(item.margin_rate || '0'),
      profit_percentage: parseFloat(item.user_rate || '0').toFixed(3), // そのまま%表示
      created_at: item.created_at,
      source: 'v1'
    }))

    // V2データを整形
    // profit_per_nftはグロス利益（マージン控除前）なので、
    // ユーザー受取率に変換: gross × (1 - fee_rate) × 0.6
    // 例: profit_per_nft = 18.24$, fee_rate = 0.3
    //     → 18.24 × 0.7 × 0.6 = 7.66$ → 7.66 / 1000 * 100 = 0.766%
    const v2Formatted = (v2Data || []).map(item => {
      const profitPerNft = parseFloat(item.profit_per_nft || '0')
      const feeRate = parseFloat(item.fee_rate || '0.3')
      const userProfitPerNft = profitPerNft * (1 - feeRate) * 0.6
      const userRatePercent = (userProfitPerNft / 1000) * 100
      return {
        date: item.date,
        yield_rate: parseFloat(item.daily_pnl || '0'), // 金額（net pnl）
        user_rate: userRatePercent / 100, // 小数形式
        margin_rate: feeRate,
        profit_percentage: userRatePercent.toFixed(3), // %表示（ユーザー受取率）
        created_at: item.created_at,
        source: 'v2'
      }
    })

    // 両方のデータを統合して日付でソート
    const allData = [...v1Formatted, ...v2Formatted]
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
      .slice(0, parseInt(limit))

    return new Response(
      JSON.stringify({
        success: true,
        data: allData,
        count: allData.length
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
