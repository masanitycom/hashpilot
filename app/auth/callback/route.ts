import { createRouteHandlerClient } from "@supabase/auth-helpers-nextjs"
import { cookies } from "next/headers"
import { type NextRequest, NextResponse } from "next/server"

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get("code")
  const error = requestUrl.searchParams.get("error")
  const error_description = requestUrl.searchParams.get("error_description")
  const type = requestUrl.searchParams.get("type")

  if (error) {
    console.error("Auth callback error:", error, error_description)
    return NextResponse.redirect(`${requestUrl.origin}/login?error=${encodeURIComponent(error_description || error)}`)
  }

  if (code) {
    const cookieStore = cookies()
    const supabase = createRouteHandlerClient({ cookies: () => cookieStore })

    try {
      const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code)

      if (exchangeError) {
        console.error("Session exchange error:", exchangeError)
        return NextResponse.redirect(`${requestUrl.origin}/login?error=${encodeURIComponent(exchangeError.message)}`)
      }

      if (data.user) {
        // パスワードリセットの場合は専用ページにリダイレクト
        if (type === "recovery") {
          return NextResponse.redirect(`${requestUrl.origin}/update-password`)
        }
        
        // メール確認完了後、ダッシュボードにリダイレクト
        return NextResponse.redirect(`${requestUrl.origin}/dashboard`)
      }
    } catch (error) {
      console.error("Callback processing error:", error)
      return NextResponse.redirect(`${requestUrl.origin}/login?error=認証処理でエラーが発生しました`)
    }
  }

  // フォールバック
  return NextResponse.redirect(`${requestUrl.origin}/login`)
}
