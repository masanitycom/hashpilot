"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Mail, CheckCircle, AlertTriangle, RefreshCw } from "lucide-react"
import { supabase, hasSupabaseCredentials } from "@/lib/supabase"

export default function RegisterPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState("")
  const [error, setError] = useState("")
  const [emailSent, setEmailSent] = useState(false)
  const [debugInfo, setDebugInfo] = useState("")
  const [retryCount, setRetryCount] = useState(0)
  const [referrerCode, setReferrerCode] = useState<string | null>(null)
  const [coinwUid, setCoinwUid] = useState<string | null>(null)

  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    const checkPreRegister = async () => {
      try {
        setDebugInfo("ページ初期化中...")

        // URLパラメータを取得
        const refFromUrl = searchParams.get("ref")
        const coinwFromUrl = searchParams.get("coinw")

        // セッションストレージから取得
        const refFromSession = sessionStorage.getItem("referrer_id")
        const coinwFromSession = sessionStorage.getItem("coinw_uid")

        // ローカルストレージからも取得
        const refFromLocal = localStorage.getItem("referrer_id")
        const coinwFromLocal = localStorage.getItem("coinw_uid")

        // 優先順位: URL > セッション > ローカル
        const finalReferrer = refFromUrl || refFromSession || refFromLocal
        const finalCoinw = coinwFromUrl || coinwFromSession || coinwFromLocal

        setReferrerCode(finalReferrer)
        setCoinwUid(finalCoinw)

        setDebugInfo(`初期化完了。紹介コード: ${finalReferrer || "なし"}, CoinW UID: ${finalCoinw || "なし"}`)

        // 詳細デバッグ情報
        console.log("Registration Debug Info:", {
          url: window.location.href,
          urlParams: {
            ref: refFromUrl,
            coinw: coinwFromUrl,
          },
          sessionData: {
            referrer: refFromSession,
            coinw: coinwFromSession,
          },
          localData: {
            referrer: refFromLocal,
            coinw: coinwFromLocal,
          },
          final: {
            referrer: finalReferrer,
            coinw: finalCoinw,
          },
          allParams: Object.fromEntries(searchParams.entries()),
        })

        // データが見つかった場合はストレージに保存
        if (finalReferrer) {
          sessionStorage.setItem("referrer_id", finalReferrer)
          localStorage.setItem("referrer_id", finalReferrer)
        }
        if (finalCoinw) {
          sessionStorage.setItem("coinw_uid", finalCoinw)
          localStorage.setItem("coinw_uid", finalCoinw)
        }
      } catch (error: any) {
        console.error("Initialization error:", error)
        setDebugInfo(`初期化エラー: ${error.message}`)
      }
    }

    checkPreRegister()
  }, [router, searchParams])

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError("")
    setMessage("")
    setDebugInfo("登録処理を開始...")

    try {
      // 基本的なバリデーション
      if (!email || !password || !confirmPassword) {
        throw new Error("すべての項目を入力してください")
      }

      if (password.length < 6) {
        throw new Error("パスワードは6文字以上で入力してください")
      }

      if (password !== confirmPassword) {
        throw new Error("パスワードが一致しません")
      }

      setDebugInfo("バリデーション完了。Supabase設定を確認中...")

      // Supabase設定チェック
      if (!hasSupabaseCredentials) {
        throw new Error("Supabaseの設定が必要です。環境変数を確認してください。")
      }

      // 最新の紹介情報を再取得
      const latestReferrer =
        referrerCode || sessionStorage.getItem("referrer_id") || localStorage.getItem("referrer_id")
      const latestCoinw = coinwUid || sessionStorage.getItem("coinw_uid") || localStorage.getItem("coinw_uid")

      // 紹介情報の詳細ログ
      const registrationData = {
        email,
        referrer_user_id: latestReferrer,
        coinw_uid: latestCoinw,
      }

      console.log("Registration attempt with data:", registrationData)

      setDebugInfo(
        `Supabase設定OK。認証処理を開始... (紹介コード: ${latestReferrer || "なし"}, CoinW UID: ${latestCoinw || "なし"})`,
      )

      // メタデータを確実に構築（すべてのキーパターンを含める）
      const userMetadata = {
        // 紹介者情報（複数のキーで送信）
        referrer_user_id: latestReferrer || null,
        referrer: latestReferrer || null,
        ref: latestReferrer || null,
        referrer_code: latestReferrer || null,
        referrer_id: latestReferrer || null,

        // CoinW UID情報（複数のキーで送信）
        coinw_uid: latestCoinw || null,
        coinw: latestCoinw || null,
        uid: latestCoinw || null,
        coinw_id: latestCoinw || null,

        // その他の情報
        registration_source: "web_form",
        registration_timestamp: new Date().toISOString(),
        full_name: null,
      }

      console.log("User metadata being sent:", userMetadata)

      // Supabase Auth でユーザー作成（メタデータを確実に設定）
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: userMetadata,
        },
      })

      if (authError) {
        console.error("Auth error:", authError)
        setDebugInfo(`認証エラー: ${authError.message}`)
        throw new Error(authError.message || "認証エラーが発生しました")
      }

      setDebugInfo("認証処理成功。レスポンスを確認中...")

      if (authData.user) {
        setDebugInfo(`ユーザー作成成功: ${authData.user.id}`)

        // 成功時の詳細ログ
        console.log("Registration successful:", {
          userId: authData.user.id,
          email: authData.user.email,
          emailConfirmed: authData.user.email_confirmed_at,
          userMetadata: authData.user.user_metadata,
          rawUserMetadata: authData.user.raw_user_meta_data,
          sentMetadata: userMetadata,
          referrerCode: latestReferrer,
          coinwUid: latestCoinw,
        })

        // ストレージをクリア
        sessionStorage.removeItem("referrer_id")
        sessionStorage.removeItem("coinw_uid")
        localStorage.removeItem("referrer_id")
        localStorage.removeItem("coinw_uid")

        // メール確認が必要かチェック
        if (authData.user.email_confirmed_at) {
          // メール確認済み - ダッシュボードにリダイレクト
          setMessage("登録が完了しました！ダッシュボードに移動します...")
          setTimeout(() => {
            router.push("/dashboard")
          }, 2000)
        } else {
          // メール確認が必要
          setEmailSent(true)
          setMessage(`${email} に確認メールを送信しました。メール内のリンクをクリックして登録を完了してください。`)
        }
      } else {
        setDebugInfo("ユーザーデータが返されませんでした")
        throw new Error("ユーザーの作成に失敗しました")
      }
    } catch (error: any) {
      console.error("Registration error:", error)
      setDebugInfo(`登録エラー: ${error.message}`)

      // エラーメッセージの設定
      if (error.message?.includes("User already registered")) {
        setError("このメールアドレスは既に登録されています。ログインページをお試しください。")
      } else if (error.message?.includes("Invalid email")) {
        setError("有効なメールアドレスを入力してください。")
      } else if (error.message?.includes("Password")) {
        setError("パスワードの形式が正しくありません。6文字以上で入力してください。")
      } else {
        setError(error.message || "登録に失敗しました。しばらく時間をおいて再試行してください。")
      }
    } finally {
      setLoading(false)
    }
  }

  const resendEmail = async () => {
    if (!email) {
      setError("メールアドレスを入力してください")
      return
    }

    setLoading(true)
    setError("")
    setDebugInfo("確認メール再送信中...")

    try {
      const { error } = await supabase.auth.resend({
        type: "signup",
        email: email,
      })

      if (error) throw error

      setDebugInfo("確認メール再送信成功")
      setMessage("確認メールを再送信しました。")
    } catch (error: any) {
      setDebugInfo(`再送信失敗: ${error.message}`)
      setError("メールの再送信に失敗しました: " + error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleRetry = () => {
    setRetryCount(retryCount + 1)
    setError("")
    setDebugInfo("")
    setEmailSent(false)
  }

  if (emailSent) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center p-4">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader className="text-center">
            <div className="flex justify-center mb-4">
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
                <Mail className="w-8 h-8 text-blue-600" />
              </div>
            </div>
            <CardTitle className="text-2xl text-white">メール確認が必要です</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="text-center">
              <p className="text-gray-300 mb-4">
                <strong className="text-white">{email}</strong> に確認メールを送信しました。
              </p>
              <p className="text-gray-400 text-sm mb-6">
                メール内のリンクをクリックして登録を完了してください。
                メールが届かない場合は、迷惑メールフォルダもご確認ください。
              </p>
            </div>

            {/* 紹介情報の表示 */}
            {(referrerCode || coinwUid) && (
              <div className="bg-blue-900 border border-blue-700 rounded-lg p-3">
                <p className="text-blue-200 text-sm font-semibold mb-2">登録情報:</p>
                {referrerCode && (
                  <p className="text-blue-200 text-sm">
                    紹介コード: <span className="font-mono text-blue-100">{referrerCode}</span>
                  </p>
                )}
                {coinwUid && (
                  <p className="text-blue-200 text-sm">
                    CoinW UID: <span className="font-mono text-blue-100">{coinwUid}</span>
                  </p>
                )}
              </div>
            )}

            {message && (
              <Alert className="bg-green-900 border-green-700">
                <CheckCircle className="h-4 w-4 text-green-400" />
                <AlertDescription className="text-green-200">{message}</AlertDescription>
              </Alert>
            )}

            {error && (
              <Alert variant="destructive" className="bg-red-900 border-red-700">
                <AlertTriangle className="h-4 w-4 text-red-400" />
                <AlertDescription className="text-red-200">{error}</AlertDescription>
              </Alert>
            )}

            <div className="space-y-3">
              <Button
                onClick={resendEmail}
                disabled={loading}
                variant="outline"
                className="w-full bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
              >
                {loading ? "送信中..." : "確認メールを再送信"}
              </Button>

              <Button
                onClick={() => setEmailSent(false)}
                variant="ghost"
                className="w-full text-gray-300 hover:text-white hover:bg-gray-700"
              >
                メールアドレスを変更
              </Button>
            </div>

            <div className="text-center text-sm">
              <Link href="/login" className="text-blue-400 hover:underline">
                すでに確認済みの場合はログイン
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center p-4">
      <Card className="w-full max-w-md bg-gray-800 border-gray-700">
        <CardHeader className="text-center">
          <div className="flex justify-center mb-6">
            <img src="/images/hash-pilot-logo.png" alt="HashPilot" className="h-16 rounded-xl shadow-lg" />
          </div>
          <CardTitle className="text-2xl text-white">新規登録</CardTitle>
          {referrerCode && (
            <div className="bg-green-900 border border-green-700 rounded-lg p-3 mt-4">
              <p className="text-sm text-green-200">
                紹介コード: <span className="font-mono font-bold text-green-100">{referrerCode}</span>
              </p>
            </div>
          )}
          {coinwUid && (
            <div className="bg-blue-900 border border-blue-700 rounded-lg p-3 mt-2">
              <p className="text-sm text-blue-200">
                CoinW UID: <span className="font-mono font-bold text-blue-100">{coinwUid}</span>
              </p>
            </div>
          )}
        </CardHeader>
        <CardContent>
          {/* デバッグ情報表示 */}
          {debugInfo && (
            <Alert className="mb-4 bg-blue-900 border-blue-700">
              <AlertDescription className="text-blue-200 text-sm">
                デバッグ: {debugInfo}
                {retryCount > 0 && <span className="ml-2">(試行回数: {retryCount + 1})</span>}
              </AlertDescription>
            </Alert>
          )}

          <form onSubmit={handleRegister} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email" className="text-white">
                メールアドレス
              </Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="bg-gray-600 border-gray-500 text-white placeholder-gray-400"
                placeholder="your@email.com"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password" className="text-white">
                パスワード（6文字以上）
              </Label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={6}
                className="bg-gray-600 border-gray-500 text-white placeholder-gray-400"
                placeholder="6文字以上で入力してください"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="confirmPassword" className="text-white">
                パスワード確認
              </Label>
              <Input
                id="confirmPassword"
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                minLength={6}
                className="bg-gray-600 border-gray-500 text-white placeholder-gray-400"
                placeholder="パスワードを再入力してください"
              />
            </div>

            {error && (
              <Alert variant="destructive" className="bg-red-900 border-red-700">
                <AlertTriangle className="h-4 w-4 text-red-400" />
                <AlertDescription className="text-red-200">{error}</AlertDescription>
              </Alert>
            )}

            <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700 text-white" disabled={loading}>
              {loading ? "登録中..." : "新規登録"}
            </Button>

            {error && (
              <Button
                type="button"
                onClick={handleRetry}
                variant="outline"
                className="w-full text-white border-white hover:bg-gray-700 hover:text-white bg-transparent"
              >
                <RefreshCw className="w-4 h-4 mr-2" />
                再試行 ({retryCount + 1})
              </Button>
            )}
          </form>

          <div className="mt-6 text-center text-sm text-white">
            すでにアカウントをお持ちですか？{" "}
            <Link href="/login" className="text-blue-400 hover:underline">
              ログイン
            </Link>
          </div>

          <div className="mt-4 p-3 bg-yellow-900 border border-yellow-700 rounded-lg">
            <p className="text-yellow-200 text-xs">
              <strong>注意:</strong> 登録後、メールアドレスの確認が必要です。
              確認メールが届かない場合は、迷惑メールフォルダをご確認ください。
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
