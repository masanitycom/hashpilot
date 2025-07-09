"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { supabase } from "@/lib/supabase"

export default function TestEmailPage() {
  const [email, setEmail] = useState("")
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState("")
  const [error, setError] = useState("")

  const testEmailDelivery = async () => {
    if (!email) {
      setError("メールアドレスを入力してください")
      return
    }

    setLoading(true)
    setError("")
    setMessage("")

    try {
      // パスワードリセットメールを送信してメール配信をテスト
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      })

      if (error) throw error

      setMessage(`${email} にテストメール（パスワードリセット）を送信しました。メールボックスを確認してください。`)
    } catch (error: any) {
      setError(`メール送信エラー: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const resendConfirmation = async () => {
    if (!email) {
      setError("メールアドレスを入力してください")
      return
    }

    setLoading(true)
    setError("")
    setMessage("")

    try {
      const { error } = await supabase.auth.resend({
        type: "signup",
        email: email,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
        },
      })

      if (error) throw error

      setMessage(`${email} に確認メールを再送信しました。`)
    } catch (error: any) {
      setError(`確認メール送信エラー: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-2xl mx-auto">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">メール配信テスト</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email" className="text-white">
                テスト用メールアドレス
              </Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                className="bg-gray-600 border-gray-500 text-white"
              />
            </div>

            <div className="flex space-x-2">
              <Button onClick={testEmailDelivery} disabled={loading} className="flex-1">
                {loading ? "送信中..." : "テストメール送信"}
              </Button>
              <Button
                onClick={resendConfirmation}
                disabled={loading}
                variant="outline"
                className="flex-1 text-white border-white"
              >
                {loading ? "送信中..." : "確認メール再送信"}
              </Button>
            </div>

            {message && (
              <Alert>
                <AlertDescription className="text-green-700">{message}</AlertDescription>
              </Alert>
            )}

            {error && (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}

            <div className="bg-yellow-900 border border-yellow-700 rounded-lg p-4">
              <h3 className="text-yellow-200 font-semibold mb-2">メールが届かない場合の確認事項：</h3>
              <ul className="text-yellow-200 text-sm space-y-1">
                <li>• 迷惑メールフォルダを確認</li>
                <li>• プロモーションフォルダを確認（Gmail）</li>
                <li>• メールアドレスのスペルミスがないか確認</li>
                <li>• Supabaseの送信制限に達していないか確認</li>
                <li>• 開発環境では送信が制限される場合があります</li>
              </ul>
            </div>

            <div className="bg-blue-900 border border-blue-700 rounded-lg p-4">
              <h3 className="text-blue-200 font-semibold mb-2">Supabaseダッシュボードで確認すべき設定：</h3>
              <ul className="text-blue-200 text-sm space-y-1">
                <li>• Authentication → Settings → Enable email confirmations: ON</li>
                <li>• Authentication → Settings → SMTP settings（本番環境）</li>
                <li>• Authentication → Email Templates → カスタムテンプレート</li>
                <li>• Project Settings → API → Rate limits</li>
              </ul>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
