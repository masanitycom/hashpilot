"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { CheckCircle, AlertTriangle, RefreshCw, TestTube, Users, Database, Play } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface TestResult {
  success: boolean
  message: string
  data?: any
}

export default function TestRegistrationPage() {
  const [testEmail, setTestEmail] = useState("")
  const [testPassword, setTestPassword] = useState("test123456")
  const [referrerCode, setReferrerCode] = useState("OOCJ16")
  const [coinwUid, setCoinwUid] = useState("12345678")
  const [loading, setLoading] = useState(false)
  const [results, setResults] = useState<TestResult[]>([])
  const [recentUsers, setRecentUsers] = useState<any[]>([])
  const [systemStats, setSystemStats] = useState<any>(null)

  useEffect(() => {
    // ランダムなテストメールを生成
    const randomId = Math.random().toString(36).substring(2, 8)
    setTestEmail(`test-${randomId}@example.com`)

    // 初期データを読み込み
    fetchRecentUsers()
    fetchSystemStats()
  }, [])

  const fetchRecentUsers = async () => {
    try {
      const { data, error } = await supabase
        .from("users")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(10)

      if (error) throw error
      setRecentUsers(data || [])
    } catch (error: any) {
      console.error("Error fetching recent users:", error)
    }
  }

  const fetchSystemStats = async () => {
    try {
      const { data, error } = await supabase.rpc("get_system_stats")
      if (error) throw error
      setSystemStats(data?.[0] || null)
    } catch (error: any) {
      console.error("Error fetching system stats:", error)
    }
  }

  const runQuickTest = async () => {
    setLoading(true)
    setResults([])

    try {
      // Step 1: テスト用メタデータを準備
      const testMetadata = {
        referrer_user_id: referrerCode,
        referrer: referrerCode,
        ref: referrerCode,
        referrer_code: referrerCode,
        referrer_id: referrerCode,
        coinw_uid: coinwUid,
        coinw: coinwUid,
        uid: coinwUid,
        coinw_id: coinwUid,
        registration_source: "quick_test",
        registration_timestamp: new Date().toISOString(),
        test_mode: true,
      }

      setResults([
        {
          success: true,
          message: `🚀 クイックテスト開始: ${testEmail}`,
          data: testMetadata,
        },
      ])

      // Step 2: 既存のテストユーザーを削除
      try {
        await supabase.from("users").delete().eq("email", testEmail)
        setResults((prev) => [
          ...prev,
          {
            success: true,
            message: `🧹 既存データクリーンアップ完了`,
          },
        ])
      } catch (cleanupError) {
        // クリーンアップエラーは無視
      }

      // Step 3: Supabase Auth でユーザー作成
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: testEmail,
        password: testPassword,
        options: {
          data: testMetadata,
        },
      })

      if (authError) {
        setResults((prev) => [
          ...prev,
          {
            success: false,
            message: `❌ 認証エラー: ${authError.message}`,
          },
        ])
        return
      }

      setResults((prev) => [
        ...prev,
        {
          success: true,
          message: `✅ ユーザー作成成功: ${authData.user?.id}`,
          data: {
            userId: authData.user?.id,
            email: authData.user?.email,
            metadata: authData.user?.raw_user_meta_data,
          },
        },
      ])

      // Step 4: データベース同期を待機
      setResults((prev) => [
        ...prev,
        {
          success: true,
          message: `⏳ データベース同期待機中...`,
        },
      ])

      await new Promise((resolve) => setTimeout(resolve, 3000))

      // Step 5: 作成されたユーザーデータを確認
      const { data: userData, error: userError } = await supabase.from("users").select("*").eq("email", testEmail)

      if (userError) {
        setResults((prev) => [
          ...prev,
          {
            success: false,
            message: `❌ ユーザーデータ取得エラー: ${userError.message}`,
          },
        ])
      } else if (!userData || userData.length === 0) {
        setResults((prev) => [
          ...prev,
          {
            success: false,
            message: `❌ ユーザーデータが見つかりません。トリガーが動作していない可能性があります。`,
          },
        ])
      } else {
        // 最新のユーザーデータを取得
        const latestUser = userData.sort(
          (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
        )[0]

        const hasReferrer = !!latestUser.referrer_user_id
        const hasCoinwUid = !!latestUser.coinw_uid

        if (hasReferrer && hasCoinwUid) {
          setResults((prev) => [
            ...prev,
            {
              success: true,
              message: `🎉 テスト成功！紹介者とCoinW UIDが正しく保存されました！
              
✅ 紹介者: ${latestUser.referrer_user_id}
✅ CoinW UID: ${latestUser.coinw_uid}
✅ ユーザーID: ${latestUser.user_id}`,
            },
          ])
        } else {
          setResults((prev) => [
            ...prev,
            {
              success: false,
              message: `❌ テスト失敗：データが不完全です

${hasReferrer ? "✅" : "❌"} 紹介者: ${latestUser.referrer_user_id || "なし"}
${hasCoinwUid ? "✅" : "❌"} CoinW UID: ${latestUser.coinw_uid || "なし"}
📅 作成日時: ${latestUser.created_at}
🆔 ユーザーID: ${latestUser.user_id}`,
            },
          ])
        }
      }

      // Step 6: 最新データを再取得
      await fetchRecentUsers()
      await fetchSystemStats()
    } catch (error: any) {
      setResults((prev) => [
        ...prev,
        {
          success: false,
          message: `💥 予期しないエラー: ${error.message}`,
        },
      ])
    } finally {
      setLoading(false)
    }
  }

  const cleanupTestUser = async () => {
    try {
      const { error } = await supabase.from("users").delete().eq("email", testEmail)

      if (error) throw error

      setResults((prev) => [
        ...prev,
        {
          success: true,
          message: `🗑️ テストユーザー削除完了: ${testEmail}`,
        },
      ])

      // 新しいテストメールを生成
      const randomId = Math.random().toString(36).substring(2, 8)
      setTestEmail(`test-${randomId}@example.com`)

      await fetchRecentUsers()
    } catch (error: any) {
      setResults((prev) => [
        ...prev,
        {
          success: false,
          message: `❌ 削除エラー: ${error.message}`,
        },
      ])
    }
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-6xl mx-auto">
        {/* ヘッダー */}
        <Card className="bg-gray-800 border-gray-700 mb-6">
          <CardHeader>
            <CardTitle className="text-white flex items-center">
              <TestTube className="w-5 h-5 mr-2" />
              登録システム緊急テスト
              <Badge className="ml-4 bg-red-600">緊急対応中</Badge>
            </CardTitle>
          </CardHeader>
        </Card>

        {/* クイックテスト */}
        <Card className="bg-gray-800 border-gray-700 mb-6">
          <CardHeader>
            <CardTitle className="text-white flex items-center">
              <Play className="w-5 h-5 mr-2" />
              クイックテスト
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid md:grid-cols-2 gap-6">
              {/* テスト設定 */}
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label className="text-white">テストメールアドレス</Label>
                  <Input
                    value={testEmail}
                    onChange={(e) => setTestEmail(e.target.value)}
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>

                <div className="space-y-2">
                  <Label className="text-white">紹介コード</Label>
                  <Input
                    value={referrerCode}
                    onChange={(e) => setReferrerCode(e.target.value)}
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>

                <div className="space-y-2">
                  <Label className="text-white">CoinW UID</Label>
                  <Input
                    value={coinwUid}
                    onChange={(e) => setCoinwUid(e.target.value)}
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>

                <div className="flex flex-col space-y-2">
                  <Button
                    onClick={runQuickTest}
                    disabled={loading}
                    size="lg"
                    className="bg-green-600 hover:bg-green-700 text-white"
                  >
                    {loading ? (
                      <>
                        <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                        テスト実行中...
                      </>
                    ) : (
                      <>
                        <Play className="w-4 h-4 mr-2" />
                        クイックテスト実行
                      </>
                    )}
                  </Button>

                  <Button
                    onClick={cleanupTestUser}
                    variant="outline"
                    className="bg-red-600 hover:bg-red-700 text-white border-red-600"
                  >
                    テストユーザー削除
                  </Button>
                </div>
              </div>

              {/* システム統計 */}
              <div className="space-y-4">
                <h3 className="text-lg font-semibold text-white">システム統計</h3>

                {systemStats ? (
                  <div className="grid grid-cols-2 gap-4">
                    <div className="bg-gray-700 p-3 rounded">
                      <div className="text-2xl font-bold text-white">{systemStats.total_users || 0}</div>
                      <div className="text-sm text-gray-400">総ユーザー数</div>
                    </div>
                    <div className="bg-green-900 p-3 rounded">
                      <div className="text-2xl font-bold text-green-400">{systemStats.users_with_referrer || 0}</div>
                      <div className="text-sm text-green-200">紹介者あり</div>
                    </div>
                    <div className="bg-blue-900 p-3 rounded">
                      <div className="text-2xl font-bold text-blue-400">{systemStats.users_with_coinw || 0}</div>
                      <div className="text-sm text-blue-200">CoinW UID あり</div>
                    </div>
                    <div className="bg-purple-900 p-3 rounded">
                      <div className="text-2xl font-bold text-purple-400">{systemStats.success_rate || 0}%</div>
                      <div className="text-sm text-purple-200">成功率</div>
                    </div>
                  </div>
                ) : (
                  <div className="bg-gray-700 p-4 rounded text-center text-gray-400">統計データを読み込み中...</div>
                )}

                <Button
                  onClick={() => {
                    fetchRecentUsers()
                    fetchSystemStats()
                  }}
                  variant="outline"
                  className="w-full bg-gray-600 hover:bg-gray-700 text-white border-gray-600"
                >
                  <RefreshCw className="w-4 h-4 mr-2" />
                  データ更新
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* テスト結果 */}
        {results.length > 0 && (
          <Card className="bg-gray-800 border-gray-700 mb-6">
            <CardHeader>
              <CardTitle className="text-white">テスト結果</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3 max-h-96 overflow-y-auto">
                {results.map((result, index) => (
                  <Alert
                    key={index}
                    className={result.success ? "bg-green-900 border-green-700" : "bg-red-900 border-red-700"}
                  >
                    {result.success ? (
                      <CheckCircle className="h-4 w-4 text-green-400" />
                    ) : (
                      <AlertTriangle className="h-4 w-4 text-red-400" />
                    )}
                    <AlertDescription className={result.success ? "text-green-200" : "text-red-200"}>
                      <pre className="whitespace-pre-wrap text-sm font-mono">{result.message}</pre>
                      {result.data && (
                        <details className="mt-2">
                          <summary className="cursor-pointer text-xs opacity-75">詳細データ</summary>
                          <pre className="mt-1 text-xs opacity-75 bg-black bg-opacity-25 p-2 rounded overflow-x-auto">
                            {JSON.stringify(result.data, null, 2)}
                          </pre>
                        </details>
                      )}
                    </AlertDescription>
                  </Alert>
                ))}
              </div>
            </CardContent>
          </Card>
        )}

        {/* 最近のユーザー */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center">
              <Users className="w-5 h-5 mr-2" />
              最近の登録ユーザー
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-white">
                <thead>
                  <tr className="border-b border-gray-600">
                    <th className="text-left p-2">ユーザーID</th>
                    <th className="text-left p-2">メール</th>
                    <th className="text-left p-2">紹介者</th>
                    <th className="text-left p-2">CoinW UID</th>
                    <th className="text-left p-2">登録日時</th>
                    <th className="text-left p-2">状態</th>
                  </tr>
                </thead>
                <tbody>
                  {recentUsers.map((user, index) => (
                    <tr key={index} className="border-b border-gray-700">
                      <td className="p-2 font-mono text-sm">{user.user_id}</td>
                      <td className="p-2 text-sm">{user.email}</td>
                      <td className="p-2 font-mono text-sm">{user.referrer_user_id || "-"}</td>
                      <td className="p-2 font-mono text-sm">{user.coinw_uid || "-"}</td>
                      <td className="p-2 text-sm">{new Date(user.created_at).toLocaleString("ja-JP")}</td>
                      <td className="p-2">
                        {user.referrer_user_id && user.coinw_uid ? (
                          <Badge className="bg-green-600">完全</Badge>
                        ) : user.referrer_user_id ? (
                          <Badge className="bg-yellow-600">紹介者のみ</Badge>
                        ) : user.coinw_uid ? (
                          <Badge className="bg-blue-600">CoinWのみ</Badge>
                        ) : (
                          <Badge variant="destructive">データなし</Badge>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {recentUsers.length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  <Database className="w-12 h-12 mx-auto mb-4 opacity-50" />
                  <p>登録ユーザーがありません</p>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
