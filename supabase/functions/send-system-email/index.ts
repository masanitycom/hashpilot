import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SendEmailRequest {
  email_id: string
  batch_size?: number  // バッチサイズ（デフォルト50）
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email_id, batch_size = 50 }: SendEmailRequest = await req.json()

    if (!email_id) {
      throw new Error('email_id is required')
    }

    // バッチサイズの上限を設定（最大100）
    const effectiveBatchSize = Math.min(batch_size, 100)

    // Supabase Admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Resend API Key
    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY environment variable is required')
    }

    // メール情報を取得
    const { data: email, error: emailError } = await supabaseAdmin
      .from('system_emails')
      .select('*')
      .eq('id', email_id)
      .single()

    if (emailError || !email) {
      throw new Error(`Email not found: ${emailError?.message}`)
    }

    // 送信先リストを取得（status = 'pending'のもののみ、バッチサイズで制限）
    const { data: recipients, error: recipientsError } = await supabaseAdmin
      .from('email_recipients')
      .select('id, user_id, to_email')
      .eq('email_id', email_id)
      .eq('status', 'pending')
      .limit(effectiveBatchSize)

    if (recipientsError) {
      throw new Error(`Failed to fetch recipients: ${recipientsError.message}`)
    }

    if (!recipients || recipients.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: '送信待ちのメールはありません',
          sent_count: 0
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    let sentCount = 0
    let failedCount = 0

    // 各受信者にメール送信（バッチ処理）
    for (const recipient of recipients) {
      try {
        // レート制限対策: 500ms待機（1秒間に2リクエストまで）
        if (sentCount > 0) {
          await new Promise(resolve => setTimeout(resolve, 500))
        }
        // ユーザー情報を取得してテンプレート変数を準備
        const { data: userData, error: userError } = await supabaseAdmin
          .from('users')
          .select('user_id, email')
          .eq('user_id', recipient.user_id)
          .single()

        if (userError) {
          console.error('Failed to fetch user data:', userError)
        }

        // テンプレート変数を置換
        let emailBody = email.body
        let emailSubject = email.subject

        if (userData) {
          const variables: Record<string, string> = {
            '{{user_id}}': userData.user_id || '',
            '{{email}}': userData.email || '',
          }

          // 本文と件名の変数を置換
          Object.entries(variables).forEach(([key, value]) => {
            const regex = new RegExp(key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')
            emailBody = emailBody.replace(regex, value)
            emailSubject = emailSubject.replace(regex, value)
          })
        }

        // Resend APIでメール送信
        const emailResponse = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${RESEND_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: `${email.from_name} <${email.from_email}>`,
            to: [recipient.to_email],
            subject: emailSubject,
            html: emailBody,
          }),
        })

        if (emailResponse.ok) {
          const emailResult = await emailResponse.json()

          // 送信成功：statusを'sent'に更新
          await supabaseAdmin
            .from('email_recipients')
            .update({
              status: 'sent',
              sent_at: new Date().toISOString(),
              resend_email_id: emailResult.id
            })
            .eq('id', recipient.id)

          sentCount++
        } else {
          const errorText = await emailResponse.text()

          // 送信失敗：statusを'failed'に更新
          await supabaseAdmin
            .from('email_recipients')
            .update({
              status: 'failed',
              error_message: errorText
            })
            .eq('id', recipient.id)

          failedCount++
        }
      } catch (error: any) {
        // 個別の送信エラー
        await supabaseAdmin
          .from('email_recipients')
          .update({
            status: 'failed',
            error_message: error.message
          })
          .eq('id', recipient.id)

        failedCount++
      }
    }

    // システムログに記録
    await supabaseAdmin.from('system_logs').insert({
      log_type: 'SUCCESS',
      operation: 'send_system_email',
      message: `システムメール送信完了: ${email.subject}`,
      details: {
        email_id,
        subject: email.subject,
        total_recipients: recipients.length,
        sent_count: sentCount,
        failed_count: failedCount
      }
    })

    return new Response(
      JSON.stringify({
        success: true,
        message: `メール送信完了: ${sentCount}件成功、${failedCount}件失敗`,
        sent_count: sentCount,
        failed_count: failedCount
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error: any) {
    console.error('Error in send-system-email function:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})
