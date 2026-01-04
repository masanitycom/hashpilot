"use client"

import type React from "react"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Shield, Eye, EyeOff, RefreshCw } from "lucide-react"
import { supabase, hasSupabaseCredentials } from "@/lib/supabase"

export default function AdminLoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const [debugInfo, setDebugInfo] = useState("")
  const [requestDetails, setRequestDetails] = useState("")
  const router = useRouter()

  const handleAdminLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError("")
    setDebugInfo("")
    setRequestDetails("")

    try {
      // Supabase設定確認
      if (!hasSupabaseCredentials) {
        setError("Supabase設定が不完全です")
        setLoading(false)
        return
      }

      // 入力値の詳細検証
      const trimmedEmail = email?.trim() || ""
      const trimmedPassword = password?.trim() || ""

      setDebugInfo(`入力値検証: email="${trimmedEmail}", password length=${trimmedPassword.length}`)

      if (!trimmedEmail) {
        setError("メールアドレスを入力してください")
        setLoading(false)
        return
      }

      if (!trimmedPassword) {
        setError("パスワードを入力してください")
        setLoading(false)
        return
      }

      // メールアドレスの形式チェック
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      if (!emailRegex.test(trimmedEmail)) {
        setError("正しいメールアドレスの形式で入力してください")
        setLoading(false)
        return
      }

      setDebugInfo("認証リクエストを準備中...")

      // リクエストパラメータを明示的に構築
      const authParams = {
        email: trimmedEmail,
        password: trimmedPassword,
      }

      setRequestDetails(`認証パラメータ: ${JSON.stringify(authParams, null, 2)}`)
      setDebugInfo("Supabase認証を実行中...")

      // Supabase認証を実行
      const { data, error: loginError } = await supabase.auth.signInWithPassword(authParams)

      if (loginError) {
        console.error("Admin login error:", loginError)
        setDebugInfo(`認証エラー詳細: ${JSON.stringify(loginError, null, 2)}`)

        // エラーの詳細分析
        if (loginError.message?.includes("missing email or phone")) {
          setError("認証リクエストでメールアドレスが正しく送信されていません。Supabase設定を確認してください。")
          setRequestDetails(`エラー詳細: ${JSON.stringify(loginError, null, 2)}`)
        } else if (loginError.message?.includes("Invalid login credentials")) {
          setError("メールアドレスまたはパスワードが正しくありません。")
        } else if (loginError.message?.includes("Email not confirmed")) {
          setError("メールアドレスが確認されていません。")
        } else {
          setError(`認証エラー: ${loginError.message}`)
        }
        setLoading(false)
        return
      }

      if (!data?.user) {
        setError("認証に成功しましたが、ユーザーデータが取得できませんでした")
        setLoading(false)
        return
      }

      const userUUID = data.user.id // uuid needed to disambiguate RPC overload

      setDebugInfo(`認証成功: ${data.user.email} (ID: ${data.user.id.substring(0, 8)}...)`)

      // 管理者権限をチェック
      setDebugInfo("管理者権限を確認中...")

      try {
        // まず直接adminsテーブルをチェック
        const { data: directAdminCheck, error: directError } = await supabase
          .from("admins")
          .select("email, is_active")
          .eq("email", trimmedEmail)
          .eq("is_active", true)
          .single()

        if (directError && directError.code !== 'PGRST116') {
          console.error("Direct admin check error:", directError)
          setDebugInfo(`直接管理者確認エラー: ${JSON.stringify(directError, null, 2)}`)
        }

        const isDirectAdmin = !!directAdminCheck
        setDebugInfo(`直接管理者チェック結果: ${isDirectAdmin} (${directAdminCheck?.email || 'not found'})`)

        // 関数呼び出しもテスト
        let isFunctionAdmin = false
        try {
          const { data: isAdminResult, error: adminError } = await supabase.rpc("is_admin", {
            user_email: trimmedEmail,
            user_uuid: userUUID,
          })

          if (adminError) {
            console.error("Admin function error:", adminError)
            setDebugInfo(`管理者権限確認エラー: ${JSON.stringify(adminError, null, 2)}`)
          } else {
            isFunctionAdmin = !!isAdminResult
            setDebugInfo(`関数管理者チェック結果: ${isFunctionAdmin}`)
          }
        } catch (funcError) {
          console.error("Admin function exception:", funcError)
          setDebugInfo(`関数エラー: ${JSON.stringify(funcError, null, 2)}`)
        }

        if (!isDirectAdmin && !isFunctionAdmin) {
          setError("管理者権限がありません。一般ユーザーとしてログインしてください。")
          setDebugInfo("管理者権限なし、ログアウト中...")
          // 管理者でない場合はログアウト
          await supabase.auth.signOut()
          setLoading(false)
          return
        }

        setDebugInfo("管理者権限確認成功、管理者ダッシュボードにリダイレクト中...")
        router.push("/admin")
      } catch (adminCheckError: any) {
        console.error("Admin check exception:", adminCheckError)
        setError(`管理者権限確認中にエラーが発生しました: ${adminCheckError.message}`)
        setLoading(false)
      }
    } catch (error: any) {
      console.error("Admin login exception:", error)
      setDebugInfo(`例外エラー: ${JSON.stringify(error, null, 2)}`)
      setError(`ログインに失敗しました: ${error.message}`)
      setLoading(false)
    }
  }

  const testSupabaseConnection = async () => {
    setLoading(true)
    setError("")
    setDebugInfo("Supabase接続テスト中...")

    try {
      // 簡単なクエリでSupabase接続をテスト
      const { data, error } = await supabase.from("admins").select("email").limit(1)

      if (error) {
        setError(`Supabase接続エラー: ${error.message}`)
        setDebugInfo(`接続テストエラー: ${JSON.stringify(error, null, 2)}`)
      } else {
        setDebugInfo("Supabase接続成功")
        setRequestDetails(`取得データ: ${JSON.stringify(data, null, 2)}`)
      }
    } catch (error: any) {
      setError(`接続テスト例外: ${error.message}`)
      setDebugInfo(`接続テスト例外: ${JSON.stringify(error, null, 2)}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center p-4">
      <Card className="w-full max-w-2xl bg-gray-800 border-gray-700">
        <CardHeader className="text-center">
          <div className="flex justify-center mb-4">
            <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center">
              <Shield className="w-8 h-8 text-red-600" />
            </div>
          </div>
          <CardTitle className="text-2xl text-white">管理者ログイン</CardTitle>
          <CardDescription className="text-gray-300">HASH PILOT管理者専用ログイン</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <form onSubmit={handleAdminLogin} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email" className="text-white">
                管理者メールアドレス
              </Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="bg-gray-600 border-gray-500 text-white placeholder-gray-400"
                placeholder="admin@hashpilot.com"
                autoComplete="email"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password" className="text-white">
                パスワード
              </Label>
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="bg-gray-600 border-gray-500 text-white placeholder-gray-400 pr-10"
                  autoComplete="current-password"
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="absolute right-0 top-0 h-full px-3 text-gray-400 hover:text-white"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </Button>
              </div>
            </div>

            <div className="flex space-x-2">
              <Button type="submit" className="flex-1 bg-red-600 hover:bg-red-700" disabled={loading}>
                {loading ? "ログイン中..." : "管理者としてログイン"}
              </Button>
              <Button
                type="button"
                onClick={testSupabaseConnection}
                variant="outline"
                className="text-gray-800 border-gray-300 bg-gray-100 hover:bg-gray-200"
                disabled={loading}
              >
                <RefreshCw className="w-4 h-4 mr-2" />
                接続テスト
              </Button>
            </div>
          </form>

          {error && (
            <Alert variant="destructive">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}

          {debugInfo && (
            <Alert>
              <AlertDescription className="text-blue-700 font-mono text-sm">{debugInfo}</AlertDescription>
            </Alert>
          )}

          {requestDetails && (
            <Alert>
              <AlertDescription className="text-green-700">
                <pre className="text-xs overflow-x-auto">{requestDetails}</pre>
              </AlertDescription>
            </Alert>
          )}

          <div className="space-y-3">
            <div className="border-t border-gray-600 pt-4">
              <div className="text-center text-sm text-gray-400">
                一般ユーザーの方は{" "}
                <button onClick={() => router.push("/login")} className="text-blue-400 hover:underline">
                  通常ログイン
                </button>
              </div>
            </div>

            <div className="bg-blue-900 border border-blue-700 rounded-lg p-3">
              <h3 className="text-blue-200 font-semibold mb-2">Supabase設定確認:</h3>
              <p className="text-blue-200 text-xs">
                hasSupabaseCredentials: {hasSupabaseCredentials ? "✅ 設定済み" : "❌ 未設定"}
              </p>
              <p className="text-blue-200 text-xs">
                URL: {process.env.NEXT_PUBLIC_SUPABASE_URL ? "✅ 設定済み" : "❌ 未設定"}
              </p>
              <p className="text-blue-200 text-xs">
                Key: {process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ? "✅ 設定済み" : "❌ 未設定"}
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
