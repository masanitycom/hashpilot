"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { createClient } from "@supabase/supabase-js"

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!)

interface UserStats {
  user_id: string
  email: string
  coinw_uid: string
  nft_count: number
  total_investment: number
  referral_count: number
}

export default function SimpleDashboard() {
  const [userStats, setUserStats] = useState<UserStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [user, setUser] = useState<any>(null)

  useEffect(() => {
    checkUser()
  }, [])

  const checkUser = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (user) {
        setUser(user)
        await fetchUserStats(user.id)
      }
    } catch (error) {
      console.error("Error checking user:", error)
    } finally {
      setLoading(false)
    }
  }

  const fetchUserStats = async (userId: string) => {
    try {
      const { data, error } = await supabase.rpc("get_user_stats", {
        target_user_id: userId,
      })

      if (error) throw error
      setUserStats(data)
    } catch (error) {
      console.error("Error fetching user stats:", error)
    }
  }

  const handleLogin = async () => {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
    })
    if (error) console.error("Login error:", error)
  }

  const handleLogout = async () => {
    const { error } = await supabase.auth.signOut()
    if (error) console.error("Logout error:", error)
    setUser(null)
    setUserStats(null)
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
            <img src="/images/hash-pilot-logo.png" alt="Hash Pilot" className="h-16 mx-auto mb-4" />
            <CardTitle className="text-2xl">Hash Pilot</CardTitle>
            <p className="text-gray-600">NFT投資プラットフォーム</p>
          </CardHeader>
          <CardContent>
            <Button onClick={handleLogin} className="w-full">
              ログイン
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
              <h1 className="ml-3 text-xl font-semibold text-gray-900">Hash Pilot Dashboard</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">{user.email}</span>
              <Button variant="outline" size="sm" onClick={handleLogout}>
                ログアウト
              </Button>
            </div>
          </div>
        </div>
      </header>

      {/* メインコンテンツ */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          {userStats ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              {/* NFT保有数 */}
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">NFT保有数</CardTitle>
                  <Badge variant="secondary">{userStats.nft_count}</Badge>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{userStats.nft_count}枚</div>
                  <p className="text-xs text-muted-foreground">アクティブなNFT</p>
                </CardContent>
              </Card>

              {/* 投資総額 */}
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">投資総額</CardTitle>
                  <Badge variant="secondary">${userStats.total_investment}</Badge>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">${userStats.total_investment.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">累計投資金額</p>
                </CardContent>
              </Card>

              {/* 紹介人数 */}
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">紹介人数</CardTitle>
                  <Badge variant="secondary">{userStats.referral_count}</Badge>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{userStats.referral_count}人</div>
                  <p className="text-xs text-muted-foreground">直接紹介したユーザー</p>
                </CardContent>
              </Card>

              {/* CoinW UID */}
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">CoinW UID</CardTitle>
                  <Badge variant="outline">{userStats.coinw_uid ? "設定済み" : "未設定"}</Badge>
                </CardHeader>
                <CardContent>
                  <div className="text-lg font-mono">{userStats.coinw_uid || "未設定"}</div>
                  <p className="text-xs text-muted-foreground">CoinW取引所UID</p>
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

          {/* アクションボタン */}
          <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4">
            <Card>
              <CardContent className="p-6 text-center">
                <h3 className="text-lg font-semibold mb-2">NFT購入</h3>
                <p className="text-gray-600 mb-4">新しいNFTを購入して投資を開始</p>
                <Button className="w-full">NFT購入ページへ</Button>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-6 text-center">
                <h3 className="text-lg font-semibold mb-2">紹介リンク</h3>
                <p className="text-gray-600 mb-4">友達を紹介して報酬を獲得</p>
                <Button variant="outline" className="w-full bg-transparent">
                  リンクをコピー
                </Button>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-6 text-center">
                <h3 className="text-lg font-semibold mb-2">プロフィール</h3>
                <p className="text-gray-600 mb-4">アカウント情報を管理</p>
                <Button variant="outline" className="w-full bg-transparent">
                  設定を開く
                </Button>
              </CardContent>
            </Card>
          </div>
        </div>
      </main>
    </div>
  )
}
