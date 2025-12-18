import { createRouteHandlerClient } from "@supabase/auth-helpers-nextjs"
import { cookies } from "next/headers"
import { type NextRequest, NextResponse } from "next/server"

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get("code")
  const error = requestUrl.searchParams.get("error")
  const error_description = requestUrl.searchParams.get("error_description")
  const type = requestUrl.searchParams.get("type")

  console.log("Auth callback (route.ts) called with params:", {
    code: code ? `${code.substring(0, 10)}...` : null,
    error,
    error_description,
    type,
    fullUrl: requestUrl.toString()
  })

  if (error) {
    console.error("Auth callback error:", error, error_description)
    return NextResponse.redirect(`${requestUrl.origin}/login?error=${encodeURIComponent(error_description || error)}`)
  }

  // パスワードリセットの場合（type=recoveryがある場合）
  // サーバーサイドでは#以降のトークンを取得できないので、
  // クライアントサイドページにリダイレクトして処理させる
  if (type === "recovery" && !code) {
    console.log("Password reset detected without code - redirecting to client-side handler")
    // クライアントサイドで#フラグメントを処理するためにHTMLページを返す
    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>認証処理中...</title>
  <style>
    body {
      font-family: system-ui, sans-serif;
      background: linear-gradient(to bottom right, #111827, #000000);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0;
    }
    .container {
      text-align: center;
      color: white;
    }
    .spinner {
      width: 40px;
      height: 40px;
      border: 3px solid rgba(59, 130, 246, 0.3);
      border-top-color: #3b82f6;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 16px;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="spinner"></div>
    <p>パスワードリセット処理中...</p>
  </div>
  <script>
    (async function() {
      try {
        // ハッシュフラグメントからトークンを取得
        const hash = window.location.hash.substring(1);
        const params = new URLSearchParams(hash);
        const accessToken = params.get('access_token');
        const refreshToken = params.get('refresh_token');
        const type = params.get('type');

        console.log('Processing hash params:', { hasAccessToken: !!accessToken, hasRefreshToken: !!refreshToken, type });

        if (accessToken && refreshToken) {
          // Supabaseクライアントを使用してセッションを設定
          const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
          const supabaseUrl = '${process.env.NEXT_PUBLIC_SUPABASE_URL}';
          const supabaseKey = '${process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY}';
          const supabase = createClient(supabaseUrl, supabaseKey);

          const { data, error } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken
          });

          if (error) {
            console.error('Session error:', error);
            window.location.href = '/login?error=' + encodeURIComponent(error.message);
            return;
          }

          console.log('Session set successfully');
          window.location.href = '/update-password?from=reset';
        } else {
          console.error('Missing tokens');
          window.location.href = '/login?error=' + encodeURIComponent('認証トークンが見つかりませんでした');
        }
      } catch (err) {
        console.error('Error:', err);
        window.location.href = '/login?error=' + encodeURIComponent('認証処理でエラーが発生しました');
      }
    })();
  </script>
</body>
</html>
    `
    return new NextResponse(html, {
      headers: { 'Content-Type': 'text/html; charset=utf-8' }
    })
  }

  if (code) {
    const cookieStore = cookies()
    const supabase = createRouteHandlerClient({ cookies: () => cookieStore })

    try {
      console.log("Exchanging code for session...")
      const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code)

      if (exchangeError) {
        console.error("Session exchange error:", exchangeError)
        return NextResponse.redirect(`${requestUrl.origin}/login?error=${encodeURIComponent(exchangeError.message)}`)
      }

      if (data.user) {
        console.log("Auth callback - user found:", data.user.id, "type:", type)

        // パスワードリセットの場合は専用ページにリダイレクト
        if (type === "recovery") {
          console.log("Password reset detected - redirecting to update-password")
          return NextResponse.redirect(`${requestUrl.origin}/update-password?from=reset&token=${code}`)
        }

        // セッションがパスワードリセット用かどうかをチェック
        if (data.session?.user) {
          const user = data.session.user
          console.log("Checking recovery session:", {
            recovery_sent_at: user.recovery_sent_at,
            email_change_sent_at: user.email_change_sent_at,
            aud: user.aud,
            created_at: user.created_at
          })

          // パスワードリセットセッションの特徴をチェック
          const isRecoverySession = (
            user.recovery_sent_at !== null ||
            user.email_change_sent_at !== null
          )

          if (isRecoverySession) {
            console.log("Recovery session detected - redirecting to update-password")
            return NextResponse.redirect(`${requestUrl.origin}/update-password?from=reset&token=${code}`)
          }
        }

        // メール確認完了後、ダッシュボードにリダイレクト
        console.log("Normal login - redirecting to dashboard")
        return NextResponse.redirect(`${requestUrl.origin}/dashboard`)
      }
    } catch (error) {
      console.error("Callback processing error:", error)
      return NextResponse.redirect(`${requestUrl.origin}/login?error=認証処理でエラーが発生しました`)
    }
  }

  // コードがない場合のフォールバック
  console.log("No code found in callback, redirecting to login")
  return NextResponse.redirect(`${requestUrl.origin}/login`)
}
