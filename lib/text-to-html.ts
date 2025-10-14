/**
 * プレーンテキストをHTMLに自動変換
 * - 改行を<br>に変換
 * - URLを自動リンク化
 * - HTMLタグがすでに含まれている場合はそのまま返す
 */
export function textToHtml(text: string): string {
  // すでにHTMLタグが含まれている場合はそのまま返す
  if (/<[a-z][\s\S]*>/i.test(text)) {
    return text
  }

  // エスケープ処理（XSS対策）
  let html = text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')

  // URLを自動リンク化（http, https, wwwで始まるもの）
  html = html.replace(
    /(https?:\/\/[^\s]+)/g,
    '<a href="$1" style="color: #3b82f6; text-decoration: underline;">$1</a>'
  )
  html = html.replace(
    /(www\.[^\s]+)/g,
    '<a href="http://$1" style="color: #3b82f6; text-decoration: underline;">$1</a>'
  )

  // 改行を<br>に変換
  html = html.replace(/\n/g, '<br>')

  // 基本的なHTMLテンプレートでラップ
  return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ${html}
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>
  `.trim()
}

/**
 * HTMLかどうかを判定
 */
export function isHtml(text: string): boolean {
  return /<[a-z][\s\S]*>/i.test(text)
}
