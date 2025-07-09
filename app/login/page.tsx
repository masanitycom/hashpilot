"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { supabase, hasSupabaseCredentials } from "@/lib/supabase"
import { Loader2 } from "lucide-react"

export default function LoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const [debugInfo, setDebugInfo] = useState("")

  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    // 既にログインしているかチェック
    checkExistingSession()

    // URLパラメータからエラーメッセージを取得
    const errorParam = searchParams.get("error")
    if (errorParam) {
      setError(decodeURIComponent(errorParam))
    }
  }, [searchParams])

  const checkExistingSession = async () => {
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession()
      if (session?.user) {
        // 既にログインしている場合はダッシュボードにリダイレクト
        router.push("/dashboard")
      }
    } catch (error) {
      console.error("Session check error:", error)
    }
  }

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError("")
    setDebugInfo("")

    if (!email || !email.trim()) {
      setError("メールアドレスを入力してください")
      setLoading(false)
      return
    }

    if (!password || !password.trim()) {
      setError("パスワードを入力してください")
      setLoading(false)
      return
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(email.trim())) {
      setError("正しいメールアドレスの形式で入力してください")
      setLoading(false)
      return
    }

    try {
      if (!hasSupabaseCredentials) {
        setError("Supabaseの設定が必要です。環境変数を確認してください。")
        setLoading(false)
        return
      }

      setDebugInfo("ログイン処理を開始...")

      const { data, error: loginError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: password,
      })

      if (loginError) {
        console.error("Login error:", loginError)
        setDebugInfo(`ログインエラー: ${loginError.message}`)

        if (loginError.message.includes("Email not confirmed")) {
          setError("メールアドレスが確認されていません。確認メールをチェックしてください。")
        } else if (loginError.message.includes("Invalid login credentials")) {
          setError("メールアドレスまたはパスワードが正しくありません。")
        } else if (loginError.message.includes("missing email or phone")) {
          setError("メールアドレスが正しく入力されていません。再度確認してください。")
        } else {
          setError(`ログインエラー: ${loginError.message}`)
        }
        setLoading(false)
        return
      }

      if (data.user && data.session) {
        setDebugInfo("ログイン成功、ダッシュボードにリダイレクト中...")

        // セッションが確実に設定されるまで少し待つ
        await new Promise((resolve) => setTimeout(resolve, 1000))

        // ダッシュボードにリダイレクト
        window.location.href = "/dashboard"
      } else {
        setError("ログインに失敗しました。再度お試しください。")
        setLoading(false)
      }
    } catch (error: any) {
      console.error("Login exception:", error)
      setDebugInfo(`例外エラー: ${error.message}`)
      setError(`ログインに失敗しました: ${error.message}`)
      setLoading(false)
    }
  }

  const resendConfirmation = async () => {
    if (!email || !email.trim()) {
      setError("メールアドレスを入力してください")
      return
    }

    setLoading(true)
    setDebugInfo("確認メール再送信中...")

    try {
      const { error } = await supabase.auth.resend({
        type: "signup",
        email: email.trim(),
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
        },
      })

      if (error) {
        console.error("Resend error:", error)
        throw error
      }

      setError("")
      setDebugInfo("確認メールを再送信しました。")
      alert("確認メールを再送信しました。")
    } catch (error: any) {
      console.error("Resend exception:", error)
      setError("メールの再送信に失敗しました: " + error.message)
      setDebugInfo(`再送信エラー: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center p-4">
      <Card className="w-full max-w-md bg-gray-800 border-gray-700">
        <CardHeader className="text-center">
          <div className="flex justify-center mb-6">
            <img src="/images/hash-pilot-logo.png" alt="HashPilot" className="h-16 rounded-xl shadow-lg" />
          </div>
          <CardTitle className="text-2xl text-white">ログイン</CardTitle>
          <CardDescription className="text-gray-300">アカウントにログインしてください</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleLogin} className="space-y-4">
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
                autoComplete="email"
                disabled={loading}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password" className="text-white">
                パスワード
              </Label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                className="bg-gray-600 border-gray-500 text-white placeholder-gray-400"
                autoComplete="current-password"
                disabled={loading}
              />
              <div className="text-right">
                <Link href="/reset-password" className="text-blue-400 hover:underline text-sm">
                  パスワードを忘れた方
                </Link>
              </div>
            </div>

            {error && (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}

            {debugInfo && (
              <Alert>
                <AlertDescription className="text-blue-700">{debugInfo}</AlertDescription>
              </Alert>
            )}

            <Button 
              type="submit" 
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3" 
              disabled={loading}
            >
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ログイン中...
                </>
              ) : (
                "ログイン"
              )}
            </Button>
          </form>

          {error.includes("メールアドレスが確認されていません") && (
            <div className="mt-4">
              <Button
                onClick={resendConfirmation}
                variant="outline"
                className="w-full text-white border-white hover:bg-gray-700 hover:text-white bg-transparent font-medium"
                disabled={loading}
              >
                確認メールを再送信
              </Button>
            </div>
          )}

          <div className="mt-6 text-center text-sm text-white">
            アカウントをお持ちでない方は{" "}
            <Link href="/pre-register" className="text-blue-400 hover:text-blue-300 hover:underline font-medium">
              新規登録
            </Link>
          </div>

          <div className="mt-4 text-center text-sm">
            <Link href="/admin-login" className="text-red-400 hover:text-red-300 hover:underline font-medium">
              管理者ログイン
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
