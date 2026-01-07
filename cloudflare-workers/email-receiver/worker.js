/**
 * Cloudflare Email Worker - メール受信処理
 *
 * support@hashpilot.biz宛のメールを受信してSupabaseに保存する
 *
 * 設定方法:
 * 1. Cloudflare Dashboard > Workers & Pages > Create Worker
 * 2. このコードをデプロイ
 * 3. Email Routing > Email Workers で support@hashpilot.biz をこのWorkerに紐付け
 * 4. Workers Settings > Variables で SUPABASE_URL と SUPABASE_SERVICE_KEY を設定
 */

export default {
  async email(message, env, ctx) {
    try {
      // メールの基本情報を取得
      const from = message.from;
      const to = message.to;
      const subject = message.headers.get("subject") || "(件名なし)";
      const messageId = message.headers.get("message-id") || "";

      // 送信者名を取得（From: "名前" <email@example.com> 形式の場合）
      let fromName = "";
      let fromEmail = from;
      const fromMatch = from.match(/^"?([^"<]+)"?\s*<?([^>]+)>?$/);
      if (fromMatch) {
        fromName = fromMatch[1].trim();
        fromEmail = fromMatch[2].trim();
      }

      // メール本文を取得
      const rawEmail = await new Response(message.raw).text();

      // 本文をパース（簡易的な処理）
      let bodyText = "";
      let bodyHtml = "";

      // Content-Typeを確認
      const contentType = message.headers.get("content-type") || "";

      if (contentType.includes("multipart")) {
        // マルチパートの場合、boundary で分割
        const boundaryMatch = contentType.match(/boundary="?([^";\s]+)"?/);
        if (boundaryMatch) {
          const boundary = boundaryMatch[1];
          const parts = rawEmail.split(`--${boundary}`);

          for (const part of parts) {
            if (part.includes("Content-Type: text/plain")) {
              const textMatch = part.match(/\r?\n\r?\n([\s\S]*?)(?=\r?\n--|\s*$)/);
              if (textMatch) {
                bodyText = decodeContent(textMatch[1], part);
              }
            } else if (part.includes("Content-Type: text/html")) {
              const htmlMatch = part.match(/\r?\n\r?\n([\s\S]*?)(?=\r?\n--|\s*$)/);
              if (htmlMatch) {
                bodyHtml = decodeContent(htmlMatch[1], part);
              }
            }
          }
        }
      } else {
        // シンプルなテキストメールの場合
        const bodyMatch = rawEmail.match(/\r?\n\r?\n([\s\S]*)/);
        if (bodyMatch) {
          if (contentType.includes("text/html")) {
            bodyHtml = decodeContent(bodyMatch[1], rawEmail);
          } else {
            bodyText = decodeContent(bodyMatch[1], rawEmail);
          }
        }
      }

      // HTMLがなくてテキストがある場合、テキストからHTMLを生成
      if (!bodyHtml && bodyText) {
        bodyHtml = `<pre style="white-space: pre-wrap; font-family: sans-serif;">${escapeHtml(bodyText)}</pre>`;
      }

      // テキストがなくてHTMLがある場合、HTMLからテキストを抽出
      if (!bodyText && bodyHtml) {
        bodyText = bodyHtml.replace(/<[^>]+>/g, "").trim();
      }

      // ヘッダー情報を収集
      const rawHeaders = {};
      for (const [key, value] of message.headers) {
        rawHeaders[key] = value;
      }

      // Supabaseに保存
      const supabaseUrl = env.SUPABASE_URL;
      const supabaseKey = env.SUPABASE_SERVICE_KEY;

      if (!supabaseUrl || !supabaseKey) {
        console.error("Supabase credentials not configured");
        // エラーでもメールは受け入れる（バウンスしない）
        return;
      }

      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/save_received_email`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "apikey": supabaseKey,
          "Authorization": `Bearer ${supabaseKey}`,
        },
        body: JSON.stringify({
          p_message_id: messageId,
          p_from_email: fromEmail,
          p_from_name: fromName,
          p_to_email: to,
          p_subject: subject,
          p_body_text: bodyText.substring(0, 50000), // 最大50KB
          p_body_html: bodyHtml.substring(0, 100000), // 最大100KB
          p_raw_headers: rawHeaders,
        }),
      });

      if (!response.ok) {
        const error = await response.text();
        console.error("Failed to save email:", error);
      } else {
        console.log(`Email saved: ${subject} from ${fromEmail}`);
      }

      // 元の転送先にも転送する場合はコメントを外す
      // await message.forward("masataka.tak@gmail.com");

    } catch (error) {
      console.error("Email processing error:", error);
      // エラーでもメールは受け入れる（バウンスしない）
    }
  },
};

/**
 * Content-Transfer-Encodingに応じてデコード
 */
function decodeContent(content, fullPart) {
  const encoding = fullPart.match(/Content-Transfer-Encoding:\s*(\S+)/i);

  if (encoding) {
    const enc = encoding[1].toLowerCase();

    if (enc === "base64") {
      try {
        return atob(content.replace(/\s/g, ""));
      } catch (e) {
        return content;
      }
    }

    if (enc === "quoted-printable") {
      return decodeQuotedPrintable(content);
    }
  }

  return content.trim();
}

/**
 * Quoted-Printableデコード
 */
function decodeQuotedPrintable(str) {
  return str
    .replace(/=\r?\n/g, "") // ソフト改行を削除
    .replace(/=([0-9A-Fa-f]{2})/g, (_, hex) => {
      return String.fromCharCode(parseInt(hex, 16));
    });
}

/**
 * HTMLエスケープ
 */
function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
