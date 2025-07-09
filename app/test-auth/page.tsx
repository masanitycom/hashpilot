"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { supabase } from "@/lib/supabase"

export default function TestAuthPage() {
  const [email, setEmail] = useState("masataka.tak@gmail.com")
  const [password, setPassword] = useState("")
  const [loading, setLoading] = useState(false)
  const [results, setResults] = useState<string[]>([])

  const addResult = (message: string) => {
    setResults((prev) => [...prev, `${new Date().toLocaleTimeString()}: ${message}`])
  }

  const testRawAuth = async () => {
    setLoading(true)
    addResult("=== RAW認証テスト開始 ===")

    try {
      // 1. Supabaseクライアントの状態確認
      addResult(`Supabase URL: ${supabase.supabaseUrl}`)
      addResult(`Supabase Key: ${supabase.supabaseKey.substring(0, 20)}...`)

      // 2. 認証パラメータの準備
      const authParams = {
        email: email.trim(),
        password: password.trim(),
      }
      addResult(`認証パラメータ: ${JSON.stringify(authParams)}`)

      // 3. 直接的な認証リクエスト
      addResult("認証リクエスト送信中...")

      const response = await fetch(`${supabase.supabaseUrl}/auth/v1/token?grant_type=password`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: supabase.supabaseKey,
          Authorization: `Bearer ${supabase.supabaseKey}`,
        },
        body: JSON.stringify(authParams),
      })

      addResult(`HTTP Status: ${response.status}`)

      const responseText = await response.text()
      addResult(`Response: ${responseText}`)

      if (!response.ok) {
        addResult(`❌ HTTP Error: ${response.status} ${response.statusText}`)
        return
      }

      const responseData = JSON.parse(responseText)
      addResult(`✅ 認証成功: ${responseData.user?.email}`)
    } catch (error: any) {
      addResult(`❌ 例外エラー: ${error.message}`)
      console.error("Raw auth error:", error)
    } finally {
      setLoading(false)
    }
  }

  const testSupabaseAuth = async () => {
    setLoading(true)
    addResult("=== Supabase SDK認証テスト開始 ===")

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: password.trim(),
      })

      if (error) {
        addResult(`❌ SDK Error: ${error.message}`)
        addResult(`Error Details: ${JSON.stringify(error, null, 2)}`)
      } else {
        addResult(`✅ SDK認証成功: ${data.user?.email}`)
        addResult(`User ID: ${data.user?.id}`)
      }
    } catch (error: any) {
      addResult(`❌ SDK例外: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const testDatabaseConnection = async () => {
    setLoading(true)
    addResult("=== データベース接続テスト開始 ===")

    try {
      const { data, error } = await supabase.from("admins").select("email, role").limit(5)

      if (error) {
        addResult(`❌ DB Error: ${error.message}`)
      } else {
        addResult(`✅ DB接続成功`)
        addResult(`Admins: ${JSON.stringify(data, null, 2)}`)
      }
    } catch (error: any) {
      addResult(`❌ DB例外: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const clearResults = () => {
    setResults([])
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-4xl mx-auto space-y-6">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">認証デバッグテスト</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label className="text-white">メールアドレス</Label>
                <Input
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="bg-gray-700 border-gray-600 text-white"
                />
              </div>
              <div>
                <Label className="text-white">パスワード</Label>
                <Input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="bg-gray-700 border-gray-600 text-white"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <Button onClick={testRawAuth} disabled={loading} className="bg-red-600 hover:bg-red-700">
                RAW認証テスト
              </Button>
              <Button onClick={testSupabaseAuth} disabled={loading} className="bg-blue-600 hover:bg-blue-700">
                SDK認証テスト
              </Button>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <Button onClick={testDatabaseConnection} disabled={loading} className="bg-green-600 hover:bg-green-700">
                DB接続テスト
              </Button>
              <Button onClick={clearResults} variant="outline" className="text-white border-white">
                結果クリア
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">テスト結果</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="bg-gray-900 p-4 rounded-lg max-h-96 overflow-y-auto">
              {results.length === 0 ? (
                <p className="text-gray-400">テスト結果がここに表示されます...</p>
              ) : (
                <pre className="text-green-400 text-sm whitespace-pre-wrap">{results.join("\n")}</pre>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
