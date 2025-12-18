"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { supabase } from "@/lib/supabase"
import { Loader2 } from "lucide-react"

export default function AuthCallbackPage() {
  const router = useRouter()
  const [status, setStatus] = useState("認証処理中...")
  const [error, setError] = useState("")

  useEffect(() => {
    handleAuthCallback()
  }, [])

  const handleAuthCallback = async () => {
    try {
      // URLのハッシュフラグメントを取得（#以降）
      const hashParams = new URLSearchParams(window.location.hash.substring(1))
      const accessToken = hashParams.get("access_token")
      const refreshToken = hashParams.get("refresh_token")
      const type = hashParams.get("type")

      // クエリパラメータも確認
      const queryParams = new URLSearchParams(window.location.search)
      const queryType = queryParams.get("type")
      const code = queryParams.get("code")
      const queryError = queryParams.get("error")
      const errorDescription = queryParams.get("error_description")

      console.log("Auth callback (client-side):", {
        hasAccessToken: !!accessToken,
        hasRefreshToken: !!refreshToken,
        type: type || queryType,
        hasCode: !!code,
        error: queryError
      })

      // エラーがある場合
      if (queryError) {
        console.error("Auth callback error:", queryError, errorDescription)
        router.push(`/login?error=${encodeURIComponent(errorDescription || queryError)}`)
        return
      }

      // パスワードリセット（type=recovery + アクセストークン）
      if ((type === "recovery" || queryType === "recovery") && accessToken && refreshToken) {
        setStatus("パスワードリセット処理中...")
        console.log("Processing password recovery with tokens")

        // トークンでセッションを設定
        const { data, error: sessionError } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken
        })

        if (sessionError) {
          console.error("Session setup error:", sessionError)
          setError(`セッション設定エラー: ${sessionError.message}`)
          setTimeout(() => {
            router.push(`/login?error=${encodeURIComponent(sessionError.message)}`)
          }, 2000)
          return
        }

        console.log("Session set successfully, redirecting to update-password")
        // パスワード更新ページにリダイレクト
        router.push("/update-password?from=reset")
        return
      }

      // 認可コードがある場合（通常のログイン/メール確認）
      if (code) {
        setStatus("セッションを確立中...")
        const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code)

        if (exchangeError) {
          console.error("Code exchange error:", exchangeError)
          router.push(`/login?error=${encodeURIComponent(exchangeError.message)}`)
          return
        }

        if (data.user) {
          console.log("User authenticated:", data.user.id)

          // パスワードリセットセッションかチェック
          if (queryType === "recovery" || data.session?.user?.recovery_sent_at) {
            router.push("/update-password?from=reset")
            return
          }

          router.push("/dashboard")
          return
        }
      }

      // トークンのみでコードがない場合（リカバリーフロー）
      if (accessToken && refreshToken && !code) {
        setStatus("認証セッションを確立中...")

        const { data, error: sessionError } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken
        })

        if (sessionError) {
          console.error("Token session error:", sessionError)
          setError(`認証エラー: ${sessionError.message}`)
          setTimeout(() => {
            router.push(`/login?error=${encodeURIComponent(sessionError.message)}`)
          }, 2000)
          return
        }

        if (data.session) {
          console.log("Session established with tokens")
          router.push("/dashboard")
          return
        }
      }

      // 何も見つからない場合はログインページへ
      console.log("No valid auth parameters found, redirecting to login")
      setError("認証情報が見つかりませんでした")
      setTimeout(() => {
        router.push("/login")
      }, 2000)

    } catch (err: any) {
      console.error("Auth callback error:", err)
      setError(`認証処理エラー: ${err.message}`)
      setTimeout(() => {
        router.push("/login?error=認証処理でエラーが発生しました")
      }, 2000)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
      <div className="text-center">
        <Loader2 className="h-8 w-8 animate-spin text-blue-500 mx-auto mb-4" />
        <p className="text-white text-lg">{status}</p>
        {error && (
          <p className="text-red-400 mt-2">{error}</p>
        )}
      </div>
    </div>
  )
}
