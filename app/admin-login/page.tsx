"use client"

import type React from "react"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Eye, EyeOff } from "lucide-react"
import { supabase, hasSupabaseCredentials } from "@/lib/supabase"

export default function AdminLoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const router = useRouter()

  const handleAdminLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError("")

    try {
      if (!hasSupabaseCredentials) {
        setError("システム設定エラーが発生しました")
        setLoading(false)
        return
      }

      const trimmedEmail = email?.trim() || ""
      const trimmedPassword = password?.trim() || ""

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

      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      if (!emailRegex.test(trimmedEmail)) {
        setError("正しいメールアドレスの形式で入力してください")
        setLoading(false)
        return
      }

      const { data, error: loginError } = await supabase.auth.signInWithPassword({
        email: trimmedEmail,
        password: trimmedPassword,
      })

      if (loginError) {
        if (loginError.message?.includes("Invalid login credentials")) {
          setError("メールアドレスまたはパスワードが正しくありません")
        } else if (loginError.message?.includes("Email not confirmed")) {
          setError("メールアドレスが確認されていません")
        } else {
          setError(`認証エラー: ${loginError.message}`)
        }
        setLoading(false)
        return
      }

      if (!data?.user) {
        setError("認証に失敗しました")
        setLoading(false)
        return
      }

      const userUUID = data.user.id

      // 管理者権限をチェック
      const { data: directAdminCheck } = await supabase
        .from("admins")
        .select("email, is_active")
        .eq("email", trimmedEmail)
        .eq("is_active", true)
        .single()

      const isDirectAdmin = !!directAdminCheck

      let isFunctionAdmin = false
      try {
        const { data: isAdminResult } = await supabase.rpc("is_admin", {
          user_email: trimmedEmail,
          user_uuid: userUUID,
        })
        isFunctionAdmin = !!isAdminResult
      } catch {
        // 関数エラーは無視
      }

      if (!isDirectAdmin && !isFunctionAdmin) {
        setError("管理者権限がありません")
        await supabase.auth.signOut()
        setLoading(false)
        return
      }

      router.push("/admin")
    } catch (error: any) {
      setError(`ログインに失敗しました: ${error.message}`)
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center p-4">
      <Card className="w-full max-w-md bg-gray-800 border-gray-700">
        <CardHeader className="text-center">
          <div className="flex justify-center mb-6">
            <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-16 rounded-xl shadow-lg" />
          </div>
          <CardTitle className="text-2xl text-white">管理者ログイン</CardTitle>
          <CardDescription className="text-gray-300">HASH PILOT管理者専用</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <form onSubmit={handleAdminLogin} className="space-y-4">
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
                placeholder="admin@example.com"
                autoComplete="email"
                disabled={loading}
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
                  disabled={loading}
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

            <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700" disabled={loading}>
              {loading ? "ログイン中..." : "ログイン"}
            </Button>
          </form>

          {error && (
            <Alert variant="destructive">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}

          <div className="border-t border-gray-600 pt-4">
            <div className="text-center text-sm text-gray-400">
              一般ユーザーの方は{" "}
              <button onClick={() => router.push("/login")} className="text-blue-400 hover:underline">
                こちら
              </button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
