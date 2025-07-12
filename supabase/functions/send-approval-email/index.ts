import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface EmailRequest {
  to_email: string
  user_name: string
  nft_quantity: number
  amount_usd: number
  user_id: string
  purchase_id: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { to_email, user_name, nft_quantity, amount_usd, user_id, purchase_id }: EmailRequest = await req.json()

    // Supabase Admin client for email sending
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // メール送信用のResendまたはSendGridのAPIキー
    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
    
    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY environment variable is required')
    }

    // メール本文の作成
    const emailSubject = `【HASHPILOT】NFT購入が承認されました`
    const emailBody = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>NFT購入承認のお知らせ</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px 10px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
        .info-box { background: #e8f5e8; border-left: 4px solid #4caf50; padding: 15px; margin: 20px 0; }
        .next-steps { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
        .btn { display: inline-block; background: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎉 NFT購入承認のお知らせ</h1>
            <p>おめでとうございます！あなたのNFT購入が正式に承認されました。</p>
        </div>
        
        <div class="content">
            <p>こんにちは、${user_name || 'ユーザー'}様</p>
            
            <div class="info-box">
                <h3>📋 承認されたNFT購入詳細</h3>
                <ul>
                    <li><strong>ユーザーID:</strong> ${user_id}</li>
                    <li><strong>購入ID:</strong> ${purchase_id}</li>
                    <li><strong>NFT数量:</strong> ${nft_quantity}個</li>
                    <li><strong>購入金額:</strong> $${amount_usd}</li>
                    <li><strong>承認日時:</strong> ${new Date().toLocaleString('ja-JP')}</li>
                </ul>
            </div>
            
            <div class="next-steps">
                <h3>🚀 次のステップ</h3>
                <ol>
                    <li><strong>日利受取開始:</strong> 明日（0:00以降）から日利の受取が開始されます</li>
                    <li><strong>ダッシュボード確認:</strong> 投資状況や利益をリアルタイムで確認できます</li>
                    <li><strong>アフィリエイト報酬:</strong> 紹介者がいる場合、報酬が自動計算されます</li>
                    <li><strong>自動再投資:</strong> 利益が一定額に達すると自動でNFTが追加購入されます</li>
                </ol>
            </div>
            
            <div style="text-align: center;">
                <a href="https://hashpilot.net/dashboard" class="btn">ダッシュボードを確認</a>
            </div>
            
            <p><strong>重要な注意事項:</strong></p>
            <ul>
                <li>日利は翌日0:00以降から開始されます（購入当日は対象外）</li>
                <li>利益は自動的にアカウントに反映されます</li>
                <li>出金申請は最小$100から可能です</li>
                <li>質問がある場合は、サポートまでお気軽にお問い合わせください</li>
            </ul>
        </div>
        
        <div class="footer">
            <p>このメールは HASHPILOT システムから自動送信されています。</p>
            <p>© 2025 HASHPILOT. All rights reserved.</p>
            <p>お問い合わせ: support@hashpilot.net</p>
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
        from: 'HASHPILOT <noreply@hashpilot.net>',
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
      operation: 'send_approval_email',
      user_id: user_id,
      message: `NFT購入承認メールを送信しました: ${to_email}`,
      details: {
        purchase_id,
        nft_quantity,
        amount_usd,
        email_id: emailResult.id
      }
    })

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Approval email sent successfully',
        email_id: emailResult.id
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('Error in send-approval-email function:', error)
    
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