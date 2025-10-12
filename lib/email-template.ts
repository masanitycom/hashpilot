// メールテンプレート生成関数

export interface EmailTemplateData {
  recipientName: string // ユーザーの名前
  recipientUserId: string // ユーザーID
  content: string // メール本文（HTML）
}

/**
 * HASHPILOT標準メールテンプレート
 * ヘッダー、フッター、問い合わせ先を含む完全なHTMLメール
 */
export function generateEmailTemplate(data: EmailTemplateData): string {
  return `
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>HASH PILOT NFT</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Helvetica Neue', Helvetica, Arial, 'Yu Gothic', 'Hiragino Kaku Gothic ProN', Meiryo, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <!-- メインコンテナ -->
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">

          <!-- ヘッダー -->
          <tr>
            <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 8px 8px 0 0; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: bold;">HASH PILOT NFT</h1>
            </td>
          </tr>

          <!-- 宛先情報 -->
          <tr>
            <td style="padding: 30px 40px 20px 40px;">
              <p style="margin: 0 0 10px 0; color: #333333; font-size: 16px;">
                <strong>${data.recipientName}</strong> 様（ID: ${data.recipientUserId}）
              </p>
            </td>
          </tr>

          <!-- メイン本文 -->
          <tr>
            <td style="padding: 0 40px 30px 40px; color: #555555; font-size: 15px; line-height: 1.8;">
              ${data.content}
            </td>
          </tr>

          <!-- 注意書き -->
          <tr>
            <td style="padding: 20px 40px; background-color: #f8f9fa; border-top: 1px solid #e9ecef;">
              <p style="margin: 0; color: #6c757d; font-size: 13px; line-height: 1.6;">
                <strong>⚠️ このメールは送信専用です</strong><br>
                このメールアドレスからの返信はできません。お問い合わせは下記の公式LINEよりお願いいたします。
              </p>
            </td>
          </tr>

          <!-- 問い合わせ先 -->
          <tr>
            <td style="padding: 30px 40px; background-color: #ffffff;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="text-align: center;">
                    <p style="margin: 0 0 15px 0; color: #333333; font-size: 16px; font-weight: bold;">お問い合わせ</p>
                    <a href="https://line.me/ti/p/YOUR_LINE_ID" style="display: inline-block; padding: 12px 30px; background-color: #06C755; color: #ffffff; text-decoration: none; border-radius: 6px; font-size: 15px; font-weight: bold;">
                      📱 公式LINEで問い合わせ
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- フッター -->
          <tr>
            <td style="padding: 25px 40px; background-color: #f8f9fa; border-radius: 0 0 8px 8px; border-top: 1px solid #e9ecef;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="text-align: center;">
                    <p style="margin: 0 0 10px 0; color: #6c757d; font-size: 13px;">
                      © 2025 HASH PILOT NFT. All rights reserved.
                    </p>
                    <p style="margin: 0; color: #adb5bd; font-size: 12px;">
                      <a href="https://hashpilot.biz" style="color: #667eea; text-decoration: none;">hashpilot.biz</a>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim()
}

/**
 * テンプレート変数を置換
 * 例: {{user_id}} → 実際のユーザーID
 */
export function replaceTemplateVariables(
  template: string,
  variables: Record<string, string>
): string {
  let result = template

  Object.entries(variables).forEach(([key, value]) => {
    const regex = new RegExp(`{{${key}}}`, 'g')
    result = result.replace(regex, value)
  })

  return result
}

/**
 * 利用可能なテンプレート変数のリスト
 */
export const AVAILABLE_TEMPLATE_VARIABLES = [
  { key: '{{user_id}}', description: 'ユーザーID' },
  { key: '{{full_name}}', description: 'ユーザー名' },
  { key: '{{email}}', description: 'メールアドレス' },
] as const
