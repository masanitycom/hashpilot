"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { createClient } from "@supabase/supabase-js"

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!)

interface SystemStats {
  total_users: number
  total_nfts: number
  total_investment: number
  users_with_referrals: number
}

export default function AdminSimple() {
  const [systemStats, setSystemStats] = useState<SystemStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [user, setUser] = useState<any>(null)

  useEffect(() => {
    checkAdminUser()
  }, [])

  const checkAdminUser = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (user) {
        setUser(user)
        await fetchSystemStats()
      } else {
        setError("ログインが必要です")
      }
    } catch (error) {
      console.error("Error checking user:", error)
      setError("ユーザー確認エラー")
    } finally {
      setLoading(false)
    }
  }

  const fetchSystemStats = async () => {
    try {
      const { data, error } = await supabase.rpc("admin_get_system_stats")

      if (error) {
        if (error.message.includes("Access denied")) {
          setError("管理者権限が必要です")
        } else {
          throw error
        }
      } else {
        setSystemStats(data)
      }
    } catch (error) {
      console.error("Error fetching system stats:", error)
      setError("システム統計の取得に失敗しました")
    }
  }

  const handleLogin = async () => {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
    })
    if (error) console.error("Login error:", error)
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">読み込み中...</p>
        </div>
      </div>
    )
  }

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="w-full max-w-md">
          <CardHeader className="text-center">
            <CardTitle className="text-2xl">管理者ログイン</CardTitle>
            <p className="text-gray-600">Hash Pilot 管理パネル</p>
          </CardHeader>
          <CardContent>
            <Button onClick={handleLogin} className="w-full">
              管理者としてログイン
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-red-600">エラー</CardTitle>
          </CardHeader>
          <CardContent>
            <Alert>
              <AlertDescription>{error}</AlertDescription>
            </Alert>
            <Button onClick={() => window.location.reload()} className="w-full mt-4">
              再試行
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* ヘッダー */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <img src="/images/hash-pilot-logo.png" alt="Hash Pilot" className="h-8 w-auto" />
              <h1 className="ml-3 text-xl font-semibold text-gray-900">Hash Pilot 管理パネル</h1>
            </div>
            <div className="flex items-center space-x-4">
              <Badge variant="secondary">管理者</Badge>
              <span className="text-sm text-gray-600">{user.email}</span>
            </div>
          </div>
        </div>
      </header>

      {/* メインコンテンツ */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">システム概要</h2>

          {systemStats ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              {/* 総ユーザー数 */}
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">総ユーザー数</CardTitle>
                  <Badge variant="secondary">{systemStats.total_users}</Badge>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{systemStats.total_users.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">登録済みユーザー</p>
                </CardContent>
              </Card>

              {/* 総NFT数 */}
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">総NFT数</CardTitle>
                  <Badge variant="secondary">{systemStats.total_nfts}</Badge>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{systemStats.total_nfts.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">アクティブなNFT</p>
                </CardContent>
              </Card>

              {/* 総投資額 */}
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">総投資額</CardTitle>
                  <Badge variant="secondary">${systemStats.total_investment}</Badge>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">${systemStats.total_investment.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">累計投資金額</p>
                </CardContent>
              </Card>

              {/* 紹介活動ユーザー */}
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">紹介活動ユーザー</CardTitle>
                  <Badge variant="secondary">{systemStats.users_with_referrals}</Badge>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{systemStats.users_with_referrals.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">紹介実績のあるユーザー</p>
                </CardContent>
              </Card>
            </div>
          ) : (
            <Card>
              <CardContent className="flex items-center justify-center h-64">
                <div className="text-center">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
                  <p className="mt-2 text-gray-600">データを読み込み中...</p>
                </div>
              </CardContent>
            </Card>
          )}

          {/* 管理機能 */}
          <div className="mt-8">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">管理機能</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <Card>
                <CardContent className="p-6 text-center">
                  <h4 className="text-lg font-semibold mb-2">ユーザー管理</h4>
                  <p className="text-gray-600 mb-4">ユーザー一覧・詳細確認</p>
                  <Button className="w-full" disabled>
                    準備中
                  </Button>
                </CardContent>
              </Card>

              <Card>
                <CardContent className="p-6 text-center">
                  <h4 className="text-lg font-semibold mb-2">NFT管理</h4>
                  <p className="text-gray-600 mb-4">NFT購入履歴・管理</p>
                  <Button variant="outline" className="w-full bg-transparent" disabled>
                    準備中
                  </Button>
                </CardContent>
              </Card>

              <Card>
                <CardContent className="p-6 text-center">
                  <h4 className="text-lg font-semibold mb-2">システム設定</h4>
                  <p className="text-gray-600 mb-4">各種設定・パラメータ</p>
                  <Button variant="outline" className="w-full bg-transparent" disabled>
                    準備中
                  </Button>
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
