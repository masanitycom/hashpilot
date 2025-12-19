import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface EmailRequest {
  to_email: string
  user_id: string
  old_coinw_uid: string | null
  new_coinw_uid: string
  rejection_reason: string | null
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { to_email, user_id, old_coinw_uid, new_coinw_uid, rejection_reason }: EmailRequest = await req.json()

    // Supabase Admin client for logging
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY environment variable is required')
    }

    const emailSubject = `【HASHPILOT】CoinW UID変更申請が却下されました`
    const emailBody = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>CoinW UID変更申請却下のお知らせ</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%); color: white; padding: 20px; border-radius: 10px 10px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
        .info-box { background: #fdecea; border-left: 4px solid #e74c3c; padding: 15px; margin: 20px 0; }
        .reason-box { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
        .btn { display: inline-block; background: #3498db; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 10px 5px; }
        .btn-line { background: #06c755; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>CoinW UID変更申請が却下されました</h1>
            <p>申請内容をご確認の上、再度お申し込みください。</p>
        </div>

        <div class="content">
            <div class="info-box">
                <h3>申請内容</h3>
                <ul>
                    <li><strong>ユーザーID:</strong> ${user_id}</li>
                    <li><strong>変更前CoinW UID:</strong> ${old_coinw_uid || '(未設定)'}</li>
                    <li><strong>申請したCoinW UID:</strong> ${new_coinw_uid}</li>
                    <li><strong>却下日時:</strong> ${new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })}</li>
                </ul>
            </div>

            ${rejection_reason ? `
            <div class="reason-box">
                <h3>却下理由</h3>
                <p>${rejection_reason}</p>
            </div>
            ` : ''}

            <div style="background: #e8f4fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <h3>再申請について</h3>
                <p>正しいCoinW UIDをご確認の上、プロフィールページから再度申請してください。</p>
                <p>CoinW UIDは、CoinWアプリまたはWebサイトのアカウント設定画面でご確認いただけます。</p>
            </div>

            <div style="text-align: center; margin: 30px 0;">
                <a href="https://hashpilot.net/profile" class="btn">プロフィールページで再申請</a>
                <a href="https://lin.ee/GHcn4pN" class="btn btn-line">サポートLINE</a>
            </div>
        </div>

        <div class="footer">
            <p>このメールは HASHPILOT システムから自動送信されています。</p>
            <p>ご不明な点がございましたら、サポートLINEまでお問い合わせください。</p>
            <p>&copy; 2025 HASHPILOT. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    `

    // Resend APIでメール送信
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'HASHPILOT <noreply@hashpilot.biz>',
        to: [to_email],
        subject: emailSubject,
        html: emailBody,
      }),
    })

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text()
      throw new Error(`Failed to send email: ${errorText}`)
    }

    const emailResult = await emailResponse.json()

    // ログ記録
    await supabaseAdmin.from('system_logs').insert({
      log_type: 'SUCCESS',
      operation: 'send_coinw_rejection_email',
      user_id: user_id,
      message: `CoinW UID変更却下メールを送信しました: ${to_email}`,
      details: {
        new_coinw_uid,
        rejection_reason,
        email_id: emailResult.id
      }
    })

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Rejection email sent successfully',
        email_id: emailResult.id
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('Error in send-coinw-rejection-email function:', error)

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
