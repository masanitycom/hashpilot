import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS対応
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Supabaseクライアントの初期化
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 認証チェック（オプション：管理者のみ実行可能にする場合）
    const authHeader = req.headers.get('Authorization')
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '')
      const { data: { user }, error } = await supabase.auth.getUser(token)
      
      if (error || !user) {
        return new Response(
          JSON.stringify({ error: '認証エラー' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // 管理者チェック
      const { data: adminCheck } = await supabase
        .rpc('is_admin', { user_email: user.email })
      
      if (!adminCheck) {
        return new Response(
          JSON.stringify({ error: '管理者権限が必要です' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // 月末自動出金処理を実行
    const { data, error } = await supabase
      .rpc('process_monthly_auto_withdrawal')

    if (error) {
      console.error('Monthly withdrawal error:', error)
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 処理結果を返す
    const result = data?.[0] || { processed_count: 0, total_amount: 0, message: '処理完了' }
    
    console.log('Monthly withdrawal completed:', result)
    
    return new Response(
      JSON.stringify({
        success: true,
        processed_count: result.processed_count,
        total_amount: result.total_amount,
        message: result.message,
        timestamp: new Date().toISOString()
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: '予期せぬエラーが発生しました' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// この関数は以下の方法で実行できます：
// 1. Supabase Dashboardのスケジューラーで毎日23:59に実行
// 2. 管理画面から手動実行
// 3. 外部のcronサービス（Vercel Cron、GitHub Actions等）から呼び出し