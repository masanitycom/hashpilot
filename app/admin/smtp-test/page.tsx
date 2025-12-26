"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { supabase } from "@/lib/supabase"

export default function SMTPTestPage() {
  const [email, setEmail] = useState("masataka.tak@gmail.com")
  const [loading, setLoading] = useState(false)
  const [results, setResults] = useState<string[]>([])

  const addResult = (message: string) => {
    setResults((prev) => [...prev, `${new Date().toLocaleTimeString()}: ${message}`])
  }

  const testPasswordReset = async () => {
    if (!email) {
      addResult("❌ メールアドレスを入力してください")
      return
    }

    setLoading(true)
    addResult(`パスワードリセットメールテストを開始... (${email})`)

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      })

      if (error) {
        addResult(`❌ エラー: ${error.message}`)
      } else {
        addResult(`✅ パスワードリセットメール送信成功: ${email}`)
        addResult("📧 リセットメールが送信されました（メールボックスを確認してください）")
        addResult("⚠️ パスワードリセットメールなので、実際にリセットしないでください")
      }
    } catch (error: any) {
      addResult(`❌ 予期しないエラー: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const resendConfirmation = async () => {
    if (!email) {
      addResult("❌ メールアドレスを入力してください")
      return
    }

    setLoading(true)
    addResult(`確認メール再送信テストを開始... (${email})`)

    try {
      const { error } = await supabase.auth.resend({
        type: "signup",
        email: email,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
        },
      })

      if (error) {
        addResult(`❌ エラー: ${error.message}`)
        if (error.message.includes("already confirmed")) {
          addResult("ℹ️ このメールアドレスは既に確認済みです")
        }
      } else {
        addResult(`✅ 確認メール再送信成功: ${email}`)
        addResult("📧 確認メールが再送信されました（メールボックスを確認してください）")
      }
    } catch (error: any) {
      addResult(`❌ 予期しないエラー: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const testNewUserRegistration = async () => {
    if (!email) {
      addResult("❌ メールアドレスを入力してください")
      return
    }

    // 新しいテスト用メールアドレスを生成（実際のメールアドレスベース）
    const [localPart, domain] = email.split("@")
    const testEmail = `${localPart}+test${Date.now()}@${domain}`

    setLoading(true)
    addResult(`新規登録メールテストを開始... (${testEmail})`)
    addResult("⚠️ 注意: Gmail+エイリアス機能を使用しているため、元のメールアドレスに届きます")

    try {
      const { data, error } = await supabase.auth.signUp({
        email: testEmail,
        password: "test123456",
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
        },
      })

      if (error) {
        addResult(`❌ エラー: ${error.message}`)
      } else {
        addResult(`✅ テストユーザー作成成功: ${testEmail}`)
        addResult(`📧 確認メールが ${email} に送信されました（+エイリアス機能）`)
        addResult("📱 メールボックスを確認してください")
      }
    } catch (error: any) {
      addResult(`❌ 予期しないエラー: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const checkUserStatus = async () => {
    if (!email) {
      addResult("❌ メールアドレスを入力してください")
      return
    }

    setLoading(true)
    addResult(`ユーザー状態確認中... (${email})`)

    try {
      // 現在のユーザー情報を取得
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (user && user.email === email) {
        addResult(`✅ 現在ログイン中: ${user.email}`)
        addResult(`📧 メール確認状態: ${user.email_confirmed_at ? "確認済み" : "未確認"}`)
        addResult(`🕐 登録日時: ${new Date(user.created_at).toLocaleString("ja-JP")}`)
      } else {
        addResult(`ℹ️ ${email} でログインしていません`)
      }
    } catch (error: any) {
      addResult(`❌ ユーザー状態確認エラー: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const clearResults = () => {
    setResults([])
  }

  return (
    <div className="min-h-screen bg-black p-4">
      <div className="max-w-4xl mx-auto space-y-6">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">SMTP & メール配信テスト（修正版）</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email" className="text-white">
                あなたのメールアドレス
              </Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="bg-gray-600 border-gray-500 text-white"
                placeholder="your@gmail.com"
              />
            </div>

            <Alert className="bg-yellow-900 border-yellow-700">
              <AlertDescription className="text-yellow-200">
                <strong>重要:</strong> 入力したメールアドレスに実際にメールが送信されます。 テスト用の新規登録では Gmail
                の +エイリアス機能を使用します。
              </AlertDescription>
            </Alert>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Button
                onClick={checkUserStatus}
                disabled={loading}
                variant="outline"
                className="w-full text-white border-white"
              >
                {loading ? "確認中..." : "ユーザー状態確認"}
              </Button>

              <Button onClick={testPasswordReset} disabled={loading} className="w-full bg-blue-600 hover:bg-blue-700">
                {loading ? "送信中..." : "パスワードリセットメール"}
              </Button>

              <Button
                onClick={resendConfirmation}
                disabled={loading}
                className="w-full bg-green-600 hover:bg-green-700"
              >
                {loading ? "送信中..." : "確認メール再送信"}
              </Button>

              <Button
                onClick={testNewUserRegistration}
                disabled={loading}
                className="w-full bg-purple-600 hover:bg-purple-700"
              >
                {loading ? "送信中..." : "新規登録テスト（+エイリアス）"}
              </Button>
            </div>

            <Button onClick={clearResults} variant="ghost" className="w-full text-gray-400">
              結果をクリア
            </Button>
          </CardContent>
        </Card>

        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">テスト結果</CardTitle>
          </CardHeader>
          <CardContent>
            <Textarea
              value={results.join("\n")}
              readOnly
              className="bg-gray-700 border-gray-600 text-white min-h-[300px] font-mono text-sm"
              placeholder="テスト結果がここに表示されます..."
            />
          </CardContent>
        </Card>

        <Card className="bg-green-900 border-green-700">
          <CardHeader>
            <CardTitle className="text-green-200">テスト方法の説明</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="text-green-200 text-sm space-y-2">
              <p>
                <strong>1. ユーザー状態確認</strong>: 現在のログイン状態とメール確認状態を確認
              </p>
              <p>
                <strong>2. パスワードリセットメール</strong>: 実際のメールアドレスにリセットメールを送信（最も確実）
              </p>
              <p>
                <strong>3. 確認メール再送信</strong>: 既存ユーザーの確認メールを再送信
              </p>
              <p>
                <strong>4. 新規登録テスト</strong>: Gmail+エイリアス機能を使用（例: your+test123@gmail.com →
                your@gmail.com に届く）
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
