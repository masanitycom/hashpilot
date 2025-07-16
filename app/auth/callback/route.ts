import { createRouteHandlerClient } from "@supabase/auth-helpers-nextjs"
import { cookies } from "next/headers"
import { type NextRequest, NextResponse } from "next/server"

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get("code")
  const error = requestUrl.searchParams.get("error")
  const error_description = requestUrl.searchParams.get("error_description")
  const type = requestUrl.searchParams.get("type")

  console.log("Auth callback called with params:", {
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

  // パスワードリセットの場合（codeがなくてもtype=recoveryがある場合）
  if (type === "recovery") {
    console.log("Password reset detected (no code), redirecting to update-password")
    return NextResponse.redirect(`${requestUrl.origin}/update-password?from=reset`)
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
