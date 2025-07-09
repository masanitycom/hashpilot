"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import LoginForm from "./login-form"
import { createClientComponentClient } from "@supabase/auth-helpers-nextjs"

export default function LoginPageClient() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const [debugInfo, setDebugInfo] = useState("")

  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    // URLパラメータからエラーメッセージを取得
    const errorParam = searchParams.get("error")
    if (errorParam) {
      setError(decodeURIComponent(errorParam))
    }
  }, [searchParams])

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError("")
    setDebugInfo("")

    // 入力値の検証
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

    // メールアドレスの形式チェック
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(email.trim())) {
      setError("正しいメールアドレスの形式で入力してください")
      setLoading(false)
      return
    }

    try {
      setDebugInfo("ログイン処理を開始...")

      const supabaseClient = createClientComponentClient()
      const { data, error: loginError } = await supabaseClient.auth.signInWithPassword({
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

      if (data.user) {
        setDebugInfo("ログイン成功、ダッシュボードにリダイレクト中...")
        router.push("/dashboard")
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
      const supabaseClient = createClientComponentClient()
      const { error } = await supabaseClient.auth.resend({
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
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-md mx-auto bg-gray-800 rounded-lg p-8 shadow-lg">
        <h1 className="text-2xl font-bold mb-6 text-white text-center">ログイン</h1>
        <LoginForm />
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

          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? "ログイン中..." : "ログイン"}
          </Button>
        </form>

        {error.includes("メールアドレスが確認されていません") && (
          <div className="mt-4">
            <Button
              onClick={resendConfirmation}
              variant="outline"
              className="w-full text-white border-white hover:bg-gray-700 bg-transparent"
              disabled={loading}
            >
              確認メールを再送信
            </Button>
          </div>
        )}

        <div className="mt-6 text-center text-sm text-white">
          アカウントをお持ちでない方は{" "}
          <Link href="/pre-register" className="text-blue-400 hover:underline">
            新規登録
          </Link>
        </div>

        <div className="mt-4 text-center text-sm">
          <Link href="/admin-login" className="text-red-400 hover:underline">
            管理者ログイン
          </Link>
        </div>
      </div>
    </div>
  )
}
