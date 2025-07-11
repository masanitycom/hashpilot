import { supabase } from "@/lib/supabase"

export async function sendApprovalEmail(
  userEmail: string,
  userId: string,
  nftQuantity: number,
  transactionId?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    // Edge Function を呼び出してメール送信
    const { data, error } = await supabase.functions.invoke('send-approval-email', {
      body: {
        to: userEmail,
        userId: userId,
        nftQuantity: nftQuantity,
        transactionId: transactionId || '',
        subject: 'NFT購入承認完了のお知らせ - HASHPILOT',
        message: `
          <h2>NFT購入が承認されました</h2>
          <p>お客様のNFT購入が確認・承認されました。</p>
          
          <h3>購入詳細:</h3>
          <ul>
            <li>ユーザーID: ${userId}</li>
            <li>NFT数量: ${nftQuantity}枚</li>
            ${transactionId ? `<li>トランザクションID: ${transactionId}</li>` : ''}
          </ul>
          
          <p>これより、HASHPILOTの全機能をご利用いただけます。</p>
          <p>ダッシュボードはこちら: <a href="https://hashpilot.net/dashboard">https://hashpilot.net/dashboard</a></p>
          
          <p>ご不明な点がございましたら、サポートまでお問い合わせください。</p>
        `
      }
    })

    if (error) {
      console.error('Email sending error:', error)
      return { success: false, error: error.message }
    }

    return { success: true }
  } catch (error: any) {
    console.error('Email sending exception:', error)
    return { success: false, error: error.message }
  }
}

// Supabase Auth の確認メールAPIを使用する代替案
export async function sendApprovalEmailViaAuth(
  userEmail: string,
  userId: string,
  nftQuantity: number
): Promise<{ success: boolean; error?: string }> {
  try {
    // システムログに記録（メール送信の代わり）
    const { error } = await supabase
      .from('system_logs')
      .insert({
        log_type: 'INFO',
        operation: 'nft_approval_notification',
        user_id: userId,
        message: `NFT購入承認通知（メール送信予定）: ${userEmail}`,
        details: {
          email: userEmail,
          nft_quantity: nftQuantity,
          notification_type: 'approval_email',
          timestamp: new Date().toISOString()
        }
      })

    if (error) {
      console.error('Log insert error:', error)
      return { success: false, error: error.message }
    }

    return { success: true }
  } catch (error: any) {
    console.error('Notification logging exception:', error)
    return { success: false, error: error.message }
  }
}